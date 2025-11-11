#!/bin/bash

set -e  # Exit on any error

ORG=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WILDCARDS_FILE="${REPO_ROOT}/${ORG}/wildcards.txt"
OUT_OF_SCOPE_FILE="${REPO_ROOT}/${ORG}/out_of_scope.txt"
RESULTS_DIR="${REPO_ROOT}/${ORG}/results"
mkdir -p "$RESULTS_DIR"

echo "[*] Starting subdomain enumeration for $ORG..."
echo "[*] Script directory: $SCRIPT_DIR"
echo "[*] Repository root: $REPO_ROOT"
echo "[*] Working directory: $(pwd)"
echo "[*] Wildcards file: $WILDCARDS_FILE"

# Create organization directory if it doesn't exist
mkdir -p "${REPO_ROOT}/${ORG}"

# Check if wildcards file exists, create it if it doesn't
if [ ! -f "$WILDCARDS_FILE" ]; then
    echo "[!] Wildcards file not found: $WILDCARDS_FILE"
    echo "[*] Creating wildcards file with default content..."
    
    # Create default wildcards based on organization
    if [ "$ORG" = "Deutsche_Telekom" ]; then
        cat > "$WILDCARDS_FILE" << EOF
telekom.de
telekom.net
telekom.com
t-systems.com
open-telekom-cloud.com
otc-service.com
