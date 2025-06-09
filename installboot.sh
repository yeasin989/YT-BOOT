#!/bin/bash
set -e

# Install Python and pip
sudo apt update
sudo apt install -y python3 python3-pip unzip wget

# Install Google Chrome
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
sudo apt update
sudo apt install -y google-chrome-stable

# Install ChromeDriver
CHROME_VERSION=$(google-chrome --version | grep -oP '\d+\.\d+\.\d+' | head -1)
CHROMEDRIVER_VERSION=$(wget -qO- "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_$CHROME_VERSION")
wget -O chromedriver.zip "https://chromedriver.storage.googleapis.com/${CHROMEDRIVER_VERSION}/chromedriver_linux64.zip"
unzip chromedriver.zip
sudo mv chromedriver /usr/local/bin/
sudo chmod +x /usr/local/bin/chromedriver
rm chromedriver.zip

# Clone/download your repo files if not present
REPO="https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPO/main"
if [ ! -f app.py ]; then
    wget $REPO/app.py
fi
if [ ! -f requirements.txt ]; then
    wget $REPO/requirements.txt
fi

# Install Python requirements
pip3 install -r requirements.txt

echo " "
echo "======================"
echo " Installation Finished"
echo "======================"
echo ""
echo "To run your panel: python3 app.py"
echo "Then visit http://YOUR_VPS_IP:8000 in your browser"
echo ""
