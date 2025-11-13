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

# Split subdomains into chunks to process in batches
BATCH_SIZE=1000
TEMP_DIR="${RESULTS_DIR}/temp"
mkdir -p "$TEMP_DIR"

# Split into batches
split -l "$BATCH_SIZE" "${RESULTS_DIR}/all_subdomains.txt" "${TEMP_DIR}/batch_"

# Process each batch
LIVE_SUBDOMAINS_FILE="${RESULTS_DIR}/live_subdomains.txt"
> "$LIVE_SUBDOMAINS_FILE"  # Clear the file

for batch_file in "${TEMP_DIR}"/batch_*; do
    if [ -f "$batch_file" ]; then
        echo "[*] Processing batch: $(basename "$batch_file")"
        
        # Probe this batch with timeout and optimized settings
        timeout 900 cat "$batch_file" | ~/local/bin/httpx-pd -ports 80,443,8080,8000,8888,8443,9443 -threads 20 -silent -retries 1 -timeout 10 >> "$LIVE_SUBDOMAINS_FILE" 2>/dev/null || echo "[!] Batch $(basename "$batch_file") encountered issues or timed out"
        
        # Small delay between batches to avoid rate limiting
        sleep 5
    fi
done

# Clean up temp files
rm -rf "$TEMP_DIR"

# Count live subdomains
LIVE_SUBDOMAINS=$(wc -l < "$LIVE_SUBDOMAINS_FILE")
echo "[*] Found $LIVE_SUBDOMAINS live subdomains"

# Compare with previous results
PREVIOUS_RESULTS="${RESULTS_DIR}/previous_live_subdomains.txt"
NEW_SUBDOMAINS="${RESULTS_DIR}/new_subdomains.txt"

if [ -f "$PREVIOUS_RESULTS" ]; then
    echo "[*] Comparing with previous results..."
    cat "$LIVE_SUBDOMAINS_FILE" | anew "$PREVIOUS_RESULTS" > "$NEW_SUBDOMAINS" || echo "[!] Error comparing with previous results"
    
    # Send new subdomains to Discord if any
    if [ -s "$NEW_SUBDOMAINS" ]; then
        echo "[*] Sending new subdomains to Discord..."
        
        # Limit the number of subdomains to send to avoid hitting Discord limits
        SUBDOMAINS_TO_SEND=$(head -20 "$NEW_SUBDOMAINS")
        
        # Create a properly formatted Discord message
        DISCORD_MESSAGE="## New Live Subdomains Found for $ORG\n\n\`\`\`\n$SUBDOMAINS_TO_SEND\n\`\`\`"
        
        # Create a temporary file with the JSON payload
        echo "{\"content\":\"$DISCORD_MESSAGE\"}" > /tmp/discord_payload.json
        
        # Send the Discord notification
        curl -H "Content-Type: application/json" -X POST -d @/tmp/discord_payload.json "$WEBHOOK_URL" 2>/dev/null || echo "[!] Error sending Discord notification"
        
        # Clean up
        rm -f /tmp/discord_payload.json
    else
        echo "[*] No new subdomains found."
    fi
else
    echo "[*] No previous results found. All subdomains are considered new."
    cp "$LIVE_SUBDOMAINS_FILE" "$NEW_SUBDOMAINS"
    
    # Limit the number of subdomains to send to avoid hitting Discord limits
    SUBDOMAINS_TO_SEND=$(head -20 "$NEW_SUBDOMAINS")
    
    # Create a properly formatted Discord message
    DISCORD_MESSAGE="## Initial Live Subdomains for $ORG\n\n\`\`\`\n$SUBDOMAINS_TO_SEND\n\`\`\`"
    
    # Create a temporary file with the JSON payload
    echo "{\"content\":\"$DISCORD_MESSAGE\"}" > /tmp/discord_payload.json
    
    # Send the Discord notification
    curl -H "Content-Type: application/json" -X POST -d @/tmp/discord_payload.json "$WEBHOOK_URL" 2>/dev/null || echo "[!] Error sending Discord notification"
    
    # Clean up
    rm -f /tmp/discord_payload.json
fi

# Update previous results for next run
cp "$LIVE_SUBDOMAINS_FILE" "$PREVIOUS_RESULTS"

echo "[+] Probing completed for $ORG"
