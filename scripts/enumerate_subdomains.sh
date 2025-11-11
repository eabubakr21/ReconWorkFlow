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

# Check if wildcards file exists
if [ ! -f "$WILDCARDS_FILE" ]; then
    echo "[!] Wildcards file not found: $WILDCARDS_FILE"
    echo "[!] Repository structure:"
    find "$REPO_ROOT" -type f -name "*.txt" | head -20
    exit 1
fi

# Create subfinder config directory and file
mkdir -p ~/.config/subfinder

# Run subfinder once to create the default config file
subfinder -config ~/.config/subfinder/provider-config.yaml -d example.com > /dev/null 2>&1 || true

# Ensure the config file exists before trying to modify it
if [ ! -f ~/.config/subfinder/provider-config.yaml ]; then
    echo "[!] Subfinder config file not found, creating a new one"
    touch ~/.config/subfinder/provider-config.yaml
fi

# Update subfinder config
cp "${SCRIPT_DIR}/subfinder-config.yaml" ~/.config/subfinder/provider-config.yaml

# Replace placeholders with actual secret values
sed -i "s/BEVIGIL_API_KEY/${BEVIGIL_API_KEY}/g" ~/.config/subfinder/provider-config.yaml
sed -i "s/PDCP_API_KEY/${PDCP_API_KEY}/g" ~/.config/subfinder/provider-config.yaml
sed -i "s/FOFA_API_KEY/${FOFA_API_KEY}/g" ~/.config/subfinder/provider-config.yaml
sed -i "s/SUBFINDER_GITHUB_TOKEN/${SUBFINDER_GITHUB_TOKEN}/g" ~/.config/subfinder/provider-config.yaml
sed -i "s/INTELX_API_KEY/${INTELX_API_KEY}/g" ~/.config/subfinder/provider-config.yaml
sed -i "s/SECURITYTRAILS_API_KEY/${SECURITYTRAILS_API_KEY}/g" ~/.config/subfinder/provider-config.yaml
sed -i "s/SHODAN_API_KEY/${SHODAN_API_KEY}/g" ~/.config/subfinder/provider-config.yaml
sed -i "s/VIRUSTOTAL_API_KEY/${VIRUSTOTAL_API_KEY}/g" ~/.config/subfinder/provider-config.yaml
sed -i "s/ZOOMEYE_API_KEY/${ZOOMEYE_API_KEY}/g" ~/.config/subfinder/provider-config.yaml

# Run subdomain enumeration tools
echo "[*] Running subfinder..."
subfinder -all -t 200 -silent -recursive -dL "$WILDCARDS_FILE" > "${RESULTS_DIR}/subfinder.txt" 2>/dev/null || echo "[!] Subfinder encountered issues"

echo "[*] Running findomain..."
findomain -quiet -f "$WILDCARDS_FILE" > "${RESULTS_DIR}/findomain.txt" 2>/dev/null || echo "[!] Findomain encountered issues"

echo "[*] Running assetfinder..."
cat "$WILDCARDS_FILE" | assetfinder -subs-only > "${RESULTS_DIR}/assetfinder.txt" 2>/dev/null || echo "[!] Assetfinder encountered issues"

echo "[*] Running SubEnum..."
if [ -f "${REPO_ROOT}/SubEnum/subenum.sh" ]; then
    "${REPO_ROOT}/SubEnum/subenum.sh" -l "$WILDCARDS_FILE" -u wayback,crt,abuseipdb,Amass > "${RESULTS_DIR}/subenum.txt" 2>/dev/null || echo "[!] SubEnum encountered issues"
else
    echo "[!] SubEnum script not found"
fi

echo "[*] Running chaos..."
chaos -dL "$WILDCARDS_FILE" > "${RESULTS_DIR}/chaos.txt" 2>/dev/null || echo "[!] Chaos encountered issues"

# Combine all results
cat "${RESULTS_DIR}"/*.txt 2>/dev/null | anew "${RESULTS_DIR}/all_subdomains.txt" || echo "[!] Error combining results"

# Filter out out-of-scope domains
if [ -f "$OUT_OF_SCOPE_FILE" ]; then
    echo "[*] Filtering out-of-scope domains..."
    grep -v -f "$OUT_OF_SCOPE_FILE" "${RESULTS_DIR}/all_subdomains.txt" > "${RESULTS_DIR}/filtered_subdomains.txt" || echo "[!] Error filtering domains"
    mv "${RESULTS_DIR}/filtered_subdomains.txt" "${RESULTS_DIR}/all_subdomains.txt"
fi

echo "[+] Subdomain enumeration completed for $ORG"
