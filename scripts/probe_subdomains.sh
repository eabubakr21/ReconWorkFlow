#!/bin/bash

set -e  # Exit on any error

ORG=$1
WEBHOOK_VAR="DISCORD_WEBHOOK_${ORG^^}"
WEBHOOK_URL="${!WEBHOOK_VAR}"
RESULTS_DIR="${ORG}/results"
mkdir -p "$RESULTS_DIR"

echo "[*] Probing live subdomains for $ORG..."

# Probe subdomains
cat "${RESULTS_DIR}/all_subdomains.txt" | httpx-pd -ports 80,443,8080,8000,8888,8443,9443 -threads 200 -silent > "${RESULTS_DIR}/live_subdomains.txt"

# Compare with previous results
PREVIOUS_RESULTS="${RESULTS_DIR}/previous_live_subdomains.txt"
NEW_SUBDOMAINS="${RESULTS_DIR}/new_subdomains.txt"

if [ -f "$PREVIOUS_RESULTS" ]; then
    echo "[*] Comparing with previous results..."
    cat "${RESULTS_DIR}/live_subdomains.txt" | anew "$PREVIOUS_RESULTS" > "$NEW_SUBDOMAINS"
    
    # Send new subdomains to Discord if any
    if [ -s "$NEW_SUBDOMAINS" ]; then
        echo "[*] Sending new subdomains to Discord..."
        DISCORD_MESSAGE="## New Live Subdomains Found for $ORG\n\n\`\`\`\n$(cat "$NEW_SUBDOMAINS")\n\`\`\`"
        
        curl -H "Content-Type: application/json" -X POST -d "{\"content\":\"$DISCORD_MESSAGE\"}" "$WEBHOOK_URL"
    else
        echo "[*] No new subdomains found."
    fi
else
    echo "[*] No previous results found. All subdomains are considered new."
    cp "${RESULTS_DIR}/live_subdomains.txt" "$NEW_SUBDOMAINS"
    
    # Send all subdomains to Discord
    DISCORD_MESSAGE="## Initial Live Subdomains for $ORG\n\n\`\`\`\n$(cat "$NEW_SUBDOMAINS")\n\`\`\`"
    
    curl -H "Content-Type: application/json" -X POST -d "{\"content\":\"$DISCORD_MESSAGE\"}" "$WEBHOOK_URL"
fi

# Update previous results for next run
cp "${RESULTS_DIR}/live_subdomains.txt" "$PREVIOUS_RESULTS"

echo "[+] Probing completed for $ORG"
