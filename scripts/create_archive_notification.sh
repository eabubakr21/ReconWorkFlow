#!/bin/bash

# Create a formatted archive notification for Discord
ORG=$1
TIMESTAMP=$(date)

echo "📦 **Subdomain Monitoring Archive for $ORG**\n\nArchive created for the latest scan run.\n\nTimestamp: $TIMESTAMP"
# Adding a comment to force a new commit
