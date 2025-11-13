#!/bin/bash

set -e  # Exit on any error

ORG=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WEBHOOK_VAR="DISCORD_WEBHOOK_${ORG^^}"
WEBHOOK_URL="${!WEBHOOK_VAR}"
RESULTS_DIR="${REPO_ROOT}/${ORG}/results"
mkdir -p "$RESULTS_DIR"

echo "[*] Probing live subdomains for $ORG..."

# Check if all_subdomains.txt exists and is not empty
if [ ! -f "${RESULTS_DIR}/all_subdomains.txt" ] || [ ! -s "${RESULTS_DIR}/all_subdomains.txt" ]; then
    echo "[!] No subdomains found to probe"
    exit 0
fi

# Count total subdomains to probe
TOTAL_SUBDOMAINS=$(wc -l < "${RESULTS_DIR}/all_subdomains.txt")
echo "[*] Total subdomains to probe: $TOTAL_SUBDOMAINS"

# Compare with previous results BEFORE probing to save time
PREVIOUS_RESULTS="${RESULTS_DIR}/previous_live_subdomains.txt"
NEW_SUBDOMAINS="${RESULTS_DIR}/new_subdomains.txt"

if [ -f "$PREVIOUS_RESULTS" ]; then
    echo "[*] Comparing with previous results before probing to save time..."
    # Get only subdomains that weren't previously found to be live
    cat "${RESULTS_DIR}/all_subdomains.txt" | anew "$PREVIOUS_RESULTS" > "${RESULTS_DIR}/potential_new_subdomains.txt" || echo "[!] Error comparing with previous results"
    
    # Use only the potentially new subdomains for probing
    SUBDOMAINS_TO_PROBE="${RESULTS_DIR}/potential_new_subdomains.txt"
    POTENTIAL_NEW_COUNT=$(wc -l < "$SUBDOMAINS_TO_PROBE")
    echo "[*] Only probing $POTENTIAL_NEW_COUNT potentially new subdomains (skipping $((TOTAL_SUBDOMAINS - POTENTIAL_NEW_COUNT)) already known)"
else
    # First run, probe all subdomains but sample to prevent timeout
    if [ "$TOTAL_SUBDOMAINS" -gt 10000 ]; then
        echo "[*] Too many subdomains ($TOTAL_SUBDOMAINS), sampling to prevent timeout"
        shuf "${RESULTS_DIR}/all_subdomains.txt" | head -10000 > "${RESULTS_DIR}/sampled_subdomains.txt"
        SUBDOMAINS_TO_PROBE="${RESULTS_DIR}/sampled_subdomains.txt"
        SAMPLED=true
    else
        SUBDOMAINS_TO_PROBE="${RESULTS_DIR}/all_subdomains.txt"
        SAMPLED=false
    fi
fi

# Split subdomains into smaller chunks to process in batches
BATCH_SIZE=250  # Reduced from 500
TEMP_DIR="${RESULTS_DIR}/temp"
mkdir -p "$TEMP_DIR"

# Split into batches
split -l "$BATCH_SIZE" "$SUBDOMAINS_TO_PROBE" "${TEMP_DIR}/batch_"

# Process each batch
LIVE_SUBDOMAINS_FILE="${RESULTS_DIR}/live_subdomains.txt"
> "$LIVE_SUBDOMAINS_FILE"  # Clear the file

BATCH_COUNT=0
for batch_file in "${TEMP_DIR}"/batch_*; do
    if [ -f "$batch_file" ]; then
        BATCH_COUNT=$((BATCH_COUNT + 1))
        echo "[*] Processing batch $BATCH_COUNT: $(basename "$batch_file")"
        
        # Probe this batch with very aggressive timeout and settings
        timeout 180 cat "$batch_file" | ~/local/bin/httpx-pd -ports 80,443 -threads 5 -silent -retries 1 -timeout 3 >> "$LIVE_SUBDOMAINS_FILE" 2>/dev/null || echo "[!] Batch $(basename "$batch_file") encountered issues or timed out"
        
        # Small delay between batches to avoid rate limiting
        sleep 1
    fi
done

# Clean up temp files
rm -rf "$TEMP_DIR"

# Count live subdomains
LIVE_SUBDOMAINS=$(wc -l < "$LIVE_SUBDOMAINS_FILE")
echo "[*] Found $LIVE_SUBDOMAINS live subdomains"

# If we sampled, note this in the Discord message
SAMPLE_NOTE=""
if [ "$SAMPLED" = "true" ]; then
    SAMPLE_NOTE=" (sampled from $TOTAL_SUBDOMAINS total)"
elif [ -f "$PREVIOUS_RESULTS" ]; then
    SAMPLE_NOTE=" (only probing potentially new subdomains)"
fi

# If we compared before probing, we already have the new subdomains
if [ -f "$PREVIOUS_RESULTS" ]; then
    NEW_COUNT=$(wc -l < "$SUBDOMAINS_TO_PROBE")
    echo "[*] $NEW_COUNT potentially new subdomains to verify"
    
    # Send new subdomains to Discord if any
    if [ -s "$SUBDOMAINS_TO_PROBE" ]; then
        echo "[*] Sending new subdomains to Discord..."
        
        # Limit the number of subdomains to send
        SUBDOMAINS_TO_SEND=$(head -15 "$SUBDOMAINS_TO_PROBE")
        
        # Create a properly formatted Discord message with newlines
        DISCORD_MESSAGE="🔍 **New Subdomains for $ORG**$SAMPLE_NOTE\n\n$(printf '%s\n' $SUBDOMAINS_TO_SEND | head -15 | sed 's/^/  /')"
        
        # Create a temporary file with the JSON payload
        echo "{\"content\":\"$DISCORD_MESSAGE\"}" > /tmp/discord_payload.json
        
        # Send the Discord notification
        curl -H "Content-Type: application/json" -X POST -d @/tmp/discord_payload.json "$WEBHOOK_URL" 2>/dev/null || echo "[!] Error sending Discord notification"
        
        # Clean up
        rm -f /tmp/discord_payload.json
    else
        echo "[*] No new subdomains found."
    fi
    
    # Copy all live subdomains to new_subdomains for the next phase
    cp "$LIVE_SUBDOMAINS_FILE" "$NEW_SUBDOMAINS"
else
    # First run or sampled run, find new subdomains by comparing with previous live
    if [ -f "$PREVIOUS_RESULTS" ]; then
        cat "$LIVE_SUBDOMAINS_FILE" | anew "$PREVIOUS_RESULTS" > "$NEW_SUBDOMAINS" || echo "[!] Error comparing with previous results"
    else
        cp "$LIVE_SUBDOMAINS_FILE" "$NEW_SUBDOMAINS"
    fi
    
    # Send new subdomains to Discord if any
    if [ -s "$NEW_SUBDOMAINS" ]; then
        echo "[*] Sending new subdomains to Discord..."
        
        # Limit the number of subdomains to send
        SUBDOMAINS_TO_SEND=$(head -15 "$NEW_SUBDOMAINS")
        NEW_COUNT=$(wc -l < "$NEW_SUBDOMAINS")
        
        # Create a properly formatted Discord message with newlines
        DISCORD_MESSAGE="🔍 **New Live Subdomains for $ORG**$SAMPLE_NOTE\n\n$NEW_COUNT new subdomains found (showing first 15):\n\n$(printf '%s\n' $SUBDOMAINS_TO_SEND | head -15 | sed 's/^/  /')"
        
        # Create a temporary file with the JSON payload
        echo "{\"content\":\"$DISCORD_MESSAGE\"}" > /tmp/discord_payload.json
        
        # Send the Discord notification
        curl -H "Content-Type: application/json" -X POST -d @/tmp/discord_payload.json "$WEBHOOK_URL" 2>/dev/null || echo "[!] Error sending Discord notification"
        
        # Clean up
        rm -f /tmp/discord_payload.json
    else
        echo "[*] No new subdomains found."
    fi
fi

# Update previous results for next run
cp "$LIVE_SUBDOMAINS_FILE" "$PREVIOUS_RESULTS"

echo "[+] Probing completed for $ORG"
