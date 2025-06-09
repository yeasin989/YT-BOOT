#!/bin/bash
sudo apt update
sudo apt install -y python3 python3-pip chromium-driver chromium-browser
pip3 install Flask selenium

git clone https://github.com/yeasin989/YT-WatchBot.git
cd YT-WatchBot

echo "Run: python3 app.py"
