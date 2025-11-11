# Subdomain Monitoring Workflow

This repository contains a GitHub Actions workflow for monitoring subdomains of multiple organizations.

## Organizations Monitored

1. Deutsche Telekom
2. Bitdefender

## Workflow Phases

1. **Subdomain Enumeration**: Uses multiple tools to discover subdomains
2. **Probing Live Targets**: Checks which subdomains are live and notifies about new ones
3. **Nuclei Scanning**: Scans new live subdomains for vulnerabilities

## Tools Used

- Subfinder
- Assetfinder
- Findomain
- Chaos
- SubEnum
- httpx
- Nuclei
- anew

## Setup

1. Fork this repository
2. Add the following secrets to your repository settings:
   - BEVIGIL_API_KEY
   - PDCP_API_KEY
   - FOFA_API_KEY
   - SUBFINDER_GITHUB_TOKEN
   - INTELX_API_KEY
   - SECURITYTRAILS_API_KEY
   - SHODAN_API_KEY
   - VIRUSTOTAL_API_KEY
   - ZOOMEYE_API_KEY
   - DISCORD_WEBHOOK_TELEKOM
   - DISCORD_WEBHOOK_BITDEFENDER
   - DISCORD_WEBHOOK_ARCHIVE

3. Enable GitHub Actions for your repository

## Schedule

The workflow runs every 12 hours via a cron job. It can also be triggered manually.

## Adding New Organizations

1. Create a new directory with the organization name
2. Add wildcards.txt and out_of_scope.txt files
3. Add a new job to the GitHub Actions workflow
4. Add the corresponding Discord webhook secret

## License

This project is licensed under the MIT License.
