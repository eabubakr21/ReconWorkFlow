#!/bin/bash

# This script cleans up old results to prevent the repository from growing too large
# It should be run periodically (e.g., once a month)

# Number of days to keep results
DAYS_TO_KEEP=7

# Find and remove old result files
find . -name "*.txt" -path "*/results/*" -type f -mtime +${DAYS_TO_KEEP} -delete

echo "[+] Cleaned up result files older than ${DAYS_TO_KEEP} days"
