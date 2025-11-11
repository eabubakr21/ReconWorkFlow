#!/bin/bash

set -e  # Exit on any error

ORG=$1

echo "[*] Starting subdomain monitoring workflow for $ORG..."

# Phase 1: Subdomain enumeration
echo "[*] Phase 1: Subdomain enumeration"
./scripts/enumerate_subdomains.sh "$ORG"

# Phase 2: Probing live targets
echo "[*] Phase 2: Probing live targets"
./scripts/probe_subdomains.sh "$ORG"

# Phase 3: Scanning with Nuclei
echo "[*] Phase 3: Scanning with Nuclei"
./scripts/scan_with_nuclei.sh "$ORG"

echo "[+] Workflow completed for $ORG"
