#!/bin/bash

echo "[*] Installing required tools..."

# Install Go tools
go install github.com/tomnomnom/assetfinder@latest
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/projectdiscovery/chaos-client/cmd/chaos@latest
go install -v github.com/tomnomnom/anew@latest

# Install findomain
echo "[*] Installing findomain..."
curl -LO https://github.com/findomain/findomain/releases/latest/download/findomain-linux-i386.zip
unzip findomain-linux-i386.zip
chmod +x findomain
sudo mv findomain /usr/bin/findomain
rm findomain-linux-i386.zip

# Install httpx
echo "[*] Installing httpx..."
pip install 'httpx[cli]'
echo "[*] Downloading latest httpx release from ProjectDiscovery..."
URL=$(curl -s https://api.github.com/repos/projectdiscovery/httpx/releases/latest \
| grep "browser_download_url.*linux_amd64.zip" \
| cut -d '"' -f 4)
wget "$URL" -O httpx_latest.zip
unzip -o httpx_latest.zip > /dev/null
chmod +x httpx
sudo mv httpx /usr/local/bin/httpx-pd
rm httpx_latest.zip LICENSE.md README.md 2>/dev/null

# Install SubEnum
echo "[*] Installing SubEnum..."
git clone https://github.com/bing0o/SubEnum.git
cd SubEnum
chmod +x setup.sh
./setup.sh
cd ..

# Create a dummy go.sum file for caching purposes
touch go.sum

# Create subfinder config directory and file
mkdir -p ~/.config/subfinder
subfinder -config ~/.config/subfinder/provider-config.yaml -d example.com > /dev/null 2>&1 || true

echo "[+] Setup complete!"
