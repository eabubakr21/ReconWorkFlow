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

# Scan new subdomains with Nuclei
NEW_SUBDOMAINS="${RESULTS_DIR}/new_subdomains.txt"
NUCLEI_RESULTS="${RESULTS_DIR}/nuclei_results.txt"

if [ -f "$NEW_SUBDOMAINS" ] && [ -s "$NEW_SUBDOMAINS" ]; then
    echo "[*] Running Nuclei on new subdomains..."
    
    # Run Nuclei with immediate notification on findings
    timeout 1800 nuclei -t ~/nuclei-templates/http -l "$NEW_SUBDOMAINS" -es info -mhe 5 -stats \
    -H "X-Forwarded-For: 127.0.0.1" \
    -H "X-Forwarded-Host: 127.0.0.1" \
    -H "X-Forwarded: 127.0.0.1" \
    -H "Forwarded-For: 127.0.0.1" \
    -o "${RESULTS_DIR}/nuclei_results.txt" \
    -j "${RESULTS_DIR}/nuclei_results.json" 2>/dev/null || echo "[!] Nuclei encountered issues or timed out"
    
    # Send immediate notifications for each finding
    if [ -f "${RESULTS_DIR}/nuclei_results.json" ] && [ -s "${RESULTS_DIR}/nuclei_results.json" ]; then
        echo "[*] Processing Nuclei findings..."
        
        # Use jq to parse JSON and send notifications for each finding
        if command -v jq >/dev/null 2>&1; then
            # Parse JSON and send notification for each finding
            jq -c '.[]' "${RESULTS_DIR}/nuclei_results.json" | while read -r finding; do
                # Extract relevant information
                TEMPLATE_ID=$(echo "$finding" | jq -r '.template-id // "unknown"')
                SEVERITY=$(echo "$finding" | jq -r '.info.severity // "unknown"')
                HOST=$(echo "$finding" | jq -r '.host // "unknown"')
                NAME=$(echo "$finding" | jq -r '.info.name // "unknown"')
                DESCRIPTION=$(echo "$finding" | jq -r '.info.description // "No description"')
                
                # Create Discord message
                DISCORD_MESSAGE="## Nuclei Finding for $ORG\n\n**Template:** $TEMPLATE_ID\n**Severity:** $SEVERITY\n**Host:** $HOST\n**Name:** $NAME\n**Description:** $DESCRIPTION"
                
                # Create a temporary file with the JSON payload
                echo "{\"content\":\"$DISCORD_MESSAGE\"}" > /tmp/discord_payload.json
                
                # Send the Discord notification
                curl -H "Content-Type: application/json" -X POST -d @/tmp/discord_payload.json "$WEBHOOK_URL" 2>/dev/null || echo "[!] Error sending Discord notification"
                
                # Clean up
                rm -f /tmp/discord_payload.json
                
                # Small delay to avoid rate limiting
                sleep 2
            done
        else
            # Fallback if jq is not available - send all findings at once
            FINDINGS_TO_SEND=$(head -20 "${RESULTS_DIR}/nuclei_results.txt")
            DISCORD_MESSAGE="## Nuclei Scan Results for $ORG\n\n\`\`\`\n$FINDINGS_TO_SEND\n\`\`\`"
            
            # Create a temporary file with the JSON payload
            echo "{\"content\":\"$DISCORD_MESSAGE\"}" > /tmp/discord_payload.json
            
            # Send the Discord notification
            curl -H "Content-Type: application/json" -X POST -d @/tmp/discord_payload.json "$WEBHOOK_URL" 2>/dev/null || echo "[!] Error sending Discord notification"
            
            # Clean up
            rm -f /tmp/discord_payload.json
        fi
    else
        echo "[*] No vulnerabilities found by Nuclei."
    fi
else
    echo "[*] No new subdomains to scan with Nuclei."
fi

echo "[+] Nuclei scanning completed for $ORG"
