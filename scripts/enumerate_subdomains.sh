#!/bin/bash

set -e  # Exit on any error

ORG=$1
WILDCARDS_FILE="${ORG}/wildcards.txt"
OUT_OF_SCOPE_FILE="${ORG}/out_of_scope.txt"
RESULTS_DIR="${ORG}/results"
mkdir -p "$RESULTS_DIR"

echo "[*] Starting subdomain enumeration for $ORG..."

# Update subfinder config
cp scripts/subfinder-config.yaml ~/.config/subfinder/provider-config.yaml

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
subfinder -all -t 200 -silent -recursive -dL "$WILDCARDS_FILE" >> "${RESULTS_DIR}/subfinder.txt"

echo "[*] Running findomain..."
findomain -quiet -f "$WILDCARDS_FILE" >> "${RESULTS_DIR}/findomain.txt"

echo "[*] Running assetfinder..."
cat "$WILDCARDS_FILE" | assetfinder -subs-only >> "${RESULTS_DIR}/assetfinder.txt"

echo "[*] Running SubEnum..."
./SubEnum/subenum.sh -l "$WILDCARDS_FILE" -u wayback,crt,abuseipdb,Amass >> "${RESULTS_DIR}/subenum.txt"

echo "[*] Running chaos..."
chaos -dL "$WILDCARDS_FILE" >> "${RESULTS_DIR}/chaos.txt"

# Combine all results
cat "${RESULTS_DIR}"/*.txt | anew "${RESULTS_DIR}/all_subdomains.txt"

# Filter out out-of-scope domains
if [ -f "$OUT_OF_SCOPE_FILE" ]; then
    echo "[*] Filtering out-of-scope domains..."
    grep -v -f "$OUT_OF_SCOPE_FILE" "${RESULTS_DIR}/all_subdomains.txt" > "${RESULTS_DIR}/filtered_subdomains.txt"
    mv "${RESULTS_DIR}/filtered_subdomains.txt" "${RESULTS_DIR}/all_subdomains.txt"
fi

echo "[+] Subdomain enumeration completed for $ORG"
