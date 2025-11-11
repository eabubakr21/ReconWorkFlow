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

# Probe subdomains
cat "${RESULTS_DIR}/all_subdomains.txt" | ~/local/bin/httpx-pd -ports 80,443,8080,8000,8888,8443,9443 -threads 200 -silent > "${RESULTS_DIR}/live_subdomains.txt" 2>/dev/null || echo "[!] httpx encountered issues"

# Compare with previous results
PREVIOUS_RESULTS="${RESULTS_DIR}/previous_live_subdomains.txt"
NEW_SUBDOMAINS="${RESULTS_DIR}/new_subdomains.txt"

if [ -f "$PREVIOUS_RESULTS" ]; then
    echo "[*] Comparing with previous results..."
    cat "${RESULTS_DIR}/live_subdomains.txt" | anew "$PREVIOUS_RESULTS" > "$NEW_SUBDOMAINS" || echo "[!] Error comparing with previous results"
    
    # Send new subdomains to Discord if any
    if [ -s "$NEW_SUBDOMAINS" ]; then
        echo "[*] Sending new subdomains to Discord..."
        DISCORD_MESSAGE="## New Live Subdomains Found for $ORG\n\n\`\`\`\n$(cat "$NEW_SUBDOMAINS")\n\`\`\`"
        
        curl -H "Content-Type: application/json" -X POST -d "{\"content\":\"$DISCORD_MESSAGE\"}" "$WEBHOOK_URL" 2>/dev/null || echo "[!] Error sending Discord notification"
    else
        echo "[*] No new subdomains found."
    fi
else
    echo "[*] No previous results found. All subdomains are considered new."
    cp "${RESULTS_DIR}/live_subdomains.txt" "$NEW_SUBDOMAINS"
    
    # Send all subdomains to Discord
    DISCORD_MESSAGE="## Initial Live Subdomains for $ORG\n\n\`\`\`\n$(cat "$NEW_SUBDOMAINS")\n\`\`\`"
    
    curl -H "Content-Type: application/json" -X POST -d "{\"content\":\"$DISCORD_MESSAGE\"}" "$WEBHOOK_URL" 2>/dev/null || echo "[!] Error sending Discord notification"
fi

# Update previous results for next run
cp "${RESULTS_DIR}/live_subdomains.txt" "$PREVIOUS_RESULTS"

echo "[+] Probing completed for $ORG"
