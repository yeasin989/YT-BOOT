#!/bin/bash
set -e

# --- CONFIGURATION ---
FOLDER=yt
API_KEY="AIzaSyABhMZekcrvV2Lh1yqntJPWJhiLcgWRigY"
GITHUB_REPO="https://github.com/yourusername/youtube-multiplayer-api.git"
TARGET_DIR="/var/www/html/$FOLDER"

echo "---- Updating System ----"
sudo apt-get update -y
sudo apt-get upgrade -y

echo "---- Installing Apache, PHP, and dependencies ----"
sudo apt-get install -y apache2 php php-curl php-xml php-mbstring git unzip

echo "---- Setting up project folder: $TARGET_DIR ----"
sudo mkdir -p $TARGET_DIR
sudo rm -rf $TARGET_DIR/*

echo "---- Cloning your GitHub repo ----"
sudo git clone $GITHUB_REPO $TARGET_DIR

echo "---- Injecting your API key into fetch-videos.php ----"
sudo sed -i "s|\$API_KEY = '.*';|\$API_KEY = '$API_KEY';|g" $TARGET_DIR/fetch-videos.php

echo "---- Setting permissions ----"
sudo chown -R www-data:www-data $TARGET_DIR

echo "---- Restarting Apache ----"
sudo systemctl restart apache2

echo "---- ALL DONE! ----"
echo
echo "Your YouTube Multi Video Player is ready at:"
echo "    http://$(curl -s ifconfig.me)/yt/"
echo "If using a domain, visit http://YOUR_DOMAIN/yt/"
echo
echo "Put your YouTube URLs and enjoy!"
