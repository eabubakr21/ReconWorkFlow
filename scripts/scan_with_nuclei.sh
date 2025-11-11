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
    timeout 1800 nuclei -t ~/nuclei-templates/http -l "$NEW_SUBDOMAINS" -es info -mhe 5 -stats \
    -H "X-Forwarded-For: 127.0.0.1" \
    -H "X-Forwarded-Host: 127.0.0.1" \
    -H "X-Forwarded: 127.0.0.1" \
    -H "Forwarded-For: 127.0.0.1" > "$NUCLEI_RESULTS" 2>/dev/null || echo "[!] Nuclei encountered issues or timed out"
    
    # Send Nuclei findings to Discord if any
    if [ -s "$NUCLEI_RESULTS" ]; then
        echo "[*] Sending Nuclei findings to Discord..."
        
        # Limit the number of findings to send to avoid hitting Discord limits
        FINDINGS_TO_SEND=$(head -20 "$NUCLEI_RESULTS")
        DISCORD_MESSAGE="## Nuclei Scan Results for $ORG\n\n\`\`\`\n$FINDINGS_TO_SEND\n\`\`\`"
        
        # Escape special characters for JSON
        DISCORD_MESSAGE_JSON=$(echo "$DISCORD_MESSAGE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        
        curl -H "Content-Type: application/json" -X POST -d "{\"content\":\"$DISCORD_MESSAGE_JSON\"}" "$WEBHOOK_URL" 2>/dev/null || echo "[!] Error sending Discord notification"
    else
        echo "[*] No vulnerabilities found by Nuclei."
    fi
else
    echo "[*] No new subdomains to scan with Nuclei."
fi

echo "[+] Nuclei scanning completed for $ORG"
