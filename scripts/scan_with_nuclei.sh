#!/bin/bash

set -e  # Exit on any error

ORG=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WEBHOOK_VAR="DISCORD_WEBHOOK_${ORG^^}"
WEBHOOK_URL="${!WEBHOOK_VAR}"
RESULTS_DIR="${REPO_ROOT}/${ORG}/results"
mkdir -p "$RESULTS_DIR"

echo "[*] Scanning with Nuclei for $ORG..."

# Update Nuclei templates with timeout
timeout 600 nuclei --update 2>/dev/null || echo "[!] Error updating Nuclei templates or timed out"
timeout 600 nuclei -ut 2>/dev/null || echo "[!] Error updating Nuclei templates or timed out"

# Check for existing checkpoint
CHECKPOINT_FILE="${RESULTS_DIR}/nuclei_checkpoint.txt"
NEW_SUBDOMAINS="${RESULTS_DIR}/new_subdomains.txt"
NUCLEI_RESULTS="${RESULTS_DIR}/nuclei_results.txt"
NUCLEI_JSON="${RESULTS_DIR}/nuclei_results.json"
RESUME_FILE="${RESULTS_DIR}/nuclei_resume.txt"

if [ -f "$NEW_SUBDOMAINS" ] && [ -s "$NEW_SUBDOMAINS" ]; then
    echo "[*] Running Nuclei on new subdomains..."
    
    # Check if we should resume from a checkpoint
    if [ -f "$CHECKPOINT_FILE" ] && [ -s "$CHECKPOINT_FILE" ]; then
        echo "[*] Found checkpoint, resuming from last position..."
        
        # Copy checkpoint to resume file
        cp "$CHECKPOINT_FILE" "$RESUME_FILE"
        
        # Run Nuclei with resume flag and extended timeout
        timeout 3300 nuclei -t ~/nuclei-templates/http -l "$NEW_SUBDOMAINS" -es info -mhe 5 -stats \
        -H "X-Forwarded-For: 127.0.0.1" \
        -H "X-Forwarded-Host: 127.0.0.1" \
        -H "X-Forwarded: 127.0.0.1" \
        -H "Forwarded-For: 127.0.0.1" \
        -o "$NUCLEI_RESULTS" \
        -j "$NUCLEI_JSON" \
        -resume "$RESUME_FILE" 2>/dev/null || echo "[!] Nuclei encountered issues or timed out"
    else
        echo "[*] Starting new Nuclei scan..."
        
        # Run Nuclei with extended timeout and checkpointing
        timeout 3300 nuclei -t ~/nuclei-templates/http -l "$NEW_SUBDOMAINS" -es info -mhe 5 -stats \
        -H "X-Forwarded-For: 127.0.0.1" \
        -H "X-Forwarded-Host: 127.0.0.1" \
        -H "X-Forwarded: 127.0.0.1" \
        -H "Forwarded-For: 127.0.0.1" \
        -o "$NUCLEI_RESULTS" \
        -j "$NUCLEI_JSON" \
        -checkpoint "$CHECKPOINT_FILE" 2>/dev/null || echo "[!] Nuclei encountered issues or timed out"
    fi
    
    # Send immediate notifications for each finding
    if [ -f "$NUCLEI_JSON" ] && [ -s "$NUCLEI_JSON" ]; then
        echo "[*] Processing Nuclei findings..."
        
        # Use jq to parse JSON and send notifications for each finding
        if command -v jq >/dev/null 2>&1; then
            # Parse JSON and send notification for each finding
            jq -c '.[]' "$NUCLEI_JSON" | while read -r finding; do
                # Extract relevant information
                TEMPLATE_ID=$(echo "$finding" | jq -r '.template-id // "unknown"')
                SEVERITY=$(echo "$finding" | jq -r '.info.severity // "unknown"')
                HOST=$(echo "$finding" | jq -r '.host // "unknown"')
                NAME=$(echo "$finding" | jq -r '.info.name // "unknown"')
                DESCRIPTION=$(echo "$finding" | jq -r '.info.description // "No description"')
                
                # Create Discord message with smaller headline
                DISCORD_MESSAGE="🚨 **Nuclei Finding for $ORG**\n\n**Template:** $TEMPLATE_ID\n**Severity:** $SEVERITY\n**Host:** $HOST\n**Name:** $NAME\n**Description:** $DESCRIPTION"
                
                # Create a temporary file with the JSON payload
                echo "{\"content\":\"$DISCORD_MESSAGE\"}" > /tmp/discord_payload.json
                
                # Send the Discord notification immediately
                curl -H "Content-Type: application/json" -X POST -d @/tmp/discord_payload.json "$WEBHOOK_URL" 2>/dev/null || echo "[!] Error sending Discord notification"
                
                # Clean up
                rm -f /tmp/discord_payload.json
                
                # Small delay to avoid rate limiting
                sleep 2
            done
        else
            # Fallback if jq is not available - send all findings at once
            FINDINGS_TO_SEND=$(head -20 "$NUCLEI_RESULTS")
            DISCORD_MESSAGE="🚨 **Nuclei Scan Results for $ORG**\n\n$(printf '%s\n' "$FINDINGS_TO_SEND" | head -20 | sed 's/^/  /')"
            
            # Create a temporary file with the JSON payload
            echo "{\"content\":\"$DISCORD_MESSAGE\"}" > /tmp/discord_payload.json
            
            # Send the Discord notification
            curl -H "Content-Type: application/json" -X POST -d @/tmp/discord_payload.json "$WEBHOOK_URL" 2>/dev/null || echo "[!] Error sending Discord notification"
            
            # Clean up
            rm -f /tmp/discord_payload.json
        fi
    else
        echo "[*] No new subdomains to scan with Nuclei."
    fi
else
    echo "[*] No new subdomains to scan with Nuclei."
fi

# Check if the scan was completed or interrupted
if [ -f "$CHECKPOINT_FILE" ] && [ -s "$CHECKPOINT_FILE" ]; then
    # If checkpoint exists but scan was interrupted, keep it for next run
    echo "[*] Scan was interrupted, checkpoint saved for next run"
elif [ -f "$NUCLEI_RESULTS" ] && [ -s "$NUCLEI_RESULTS" ]; then
    # If scan completed successfully, remove checkpoint
    rm -f "$CHECKPOINT_FILE"
    echo "[*] Scan completed successfully, checkpoint removed"
else
    echo "[*] Scan failed or was interrupted, no results saved"
fi

echo "[+] Nuclei scanning completed for $ORG"
