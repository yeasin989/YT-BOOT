#!/bin/bash

apt update
apt install -y python3 python3-pip unzip wget curl
pip3 install --upgrade pip

# Google Chrome & ChromeDriver
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
apt update
apt install -y google-chrome-stable

pip3 install -r requirements.txt

echo "All set! Run: python3 app.py"
