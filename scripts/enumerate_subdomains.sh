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
EOF
    elif [ "$ORG" = "Bitdefender" ]; then
        cat > "$WILDCARDS_FILE" << EOF
bitdefender.com
bitdefender.net
horangi.com
EOF
    else
        echo "[!] Unknown organization: $ORG"
        exit 1
    fi
    
    echo "[*] Created wildcards file: $WILDCARDS_FILE"
fi

# Create out_of_scope file if it doesn't exist
if [ ! -f "$OUT_OF_SCOPE_FILE" ]; then
    echo "[*] Creating out_of_scope file with default content..."
    
    # Create default out_of_scope based on organization
    if [ "$ORG" = "Deutsche_Telekom" ]; then
        cat > "$OUT_OF_SCOPE_FILE" << EOF
*.reverse.open-telekom-cloud.com
EOF
    elif [ "$ORG" = "Bitdefender" ]; then
        cat > "$OUT_OF_SCOPE_FILE" << EOF
lsems.gravityzone.bitdefender.com
ssems.gravityzone.bitdefender.com
community.bitdefender.com
resellerportal.bitdefender.com
stats.bitdefender.com
sstats.bitdefender.com
brand.bitdefender.com
partner-marketing.bitdefender.com
businessinsights.bitdefender.com
businessemail.bitdefender.com
businessresources.bitdefender.com
oemhub.bitdefender.com
oemresources.bitdefender.com
crp.bitdefender.com
telcosuccess.bitdefender.com
demo.bitdefender.com
EOF
    fi
    
    echo "[*] Created out_of_scope file: $OUT_OF_SCOPE_FILE"
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

# Run subdomain enumeration tools with timeouts and optimized settings
echo "[*] Running subfinder..."
timeout 1800 subfinder -all -t 50 -silent -recursive -dL "$WILDCARDS_FILE" > "${RESULTS_DIR}/subfinder.txt" 2>/dev/null || echo "[!] Subfinder encountered issues or timed out"

echo "[*] Running findomain..."
timeout 900 findomain -quiet -f "$WILDCARDS_FILE" > "${RESULTS_DIR}/findomain.txt" 2>/dev/null || echo "[!] Findomain encountered issues or timed out"

echo "[*] Running assetfinder..."
timeout 900 cat "$WILDCARDS_FILE" | assetfinder -subs-only > "${RESULTS_DIR}/assetfinder.txt" 2>/dev/null || echo "[!] Assetfinder encountered issues or timed out"

echo "[*] Running SubEnum..."
if [ -f "${REPO_ROOT}/SubEnum/subenum.sh" ]; then
    timeout 1800 "${REPO_ROOT}/SubEnum/subenum.sh" -l "$WILDCARDS_FILE" -u wayback,crt,abuseipdb,Amass > "${RESULTS_DIR}/subenum.txt" 2>/dev/null || echo "[!] SubEnum encountered issues or timed out"
else
    echo "[!] SubEnum script not found"
fi

echo "[*] Running chaos..."
timeout 900 chaos -dL "$WILDCARDS_FILE" > "${RESULTS_DIR}/chaos.txt" 2>/dev/null || echo "[!] Chaos encountered issues or timed out"

# Combine all results
cat "${RESULTS_DIR}"/*.txt 2>/dev/null | anew "${RESULTS_DIR}/all_subdomains.txt" || echo "[!] Error combining results"

# Filter out out-of-scope domains
if [ -f "$OUT_OF_SCOPE_FILE" ]; then
    echo "[*] Filtering out-of-scope domains..."
    grep -v -f "$OUT_OF_SCOPE_FILE" "${RESULTS_DIR}/all_subdomains.txt" > "${RESULTS_DIR}/filtered_subdomains.txt" || echo "[!] Error filtering domains"
    mv "${RESULTS_DIR}/filtered_subdomains.txt" "${RESULTS_DIR}/all_subdomains.txt"
fi

echo "[+] Subdomain enumeration completed for $ORG"
