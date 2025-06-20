#!/bin/bash
set -e

# --------- CONFIG ---------
FOLDER="yt"
TARGET_DIR="/var/www/html/$FOLDER"
GITHUB_REPO="https://github.com/yourusername/youtube-multiplayer-api.git" # CHANGE THIS to your public repo!
API_KEY="AIzaSyABhMZekcrvV2Lh1yqntJPWJhiLcgWRigY"

echo "---- Updating System ----"
sudo apt-get update -y
sudo apt-get upgrade -y

echo "---- Installing Apache, PHP, and dependencies ----"
sudo apt-get install -y apache2 php php-curl php-xml php-mbstring git unzip

echo "---- Creating project folder: $TARGET_DIR ----"
sudo mkdir -p $TARGET_DIR
sudo rm -rf $TARGET_DIR/*

echo "---- Cloning your PUBLIC GitHub repo ----"
sudo git clone $GITHUB_REPO $TARGET_DIR

echo "---- Injecting your API key into fetch-videos.php ----"
sudo sed -i "s|\$API_KEY = '.*';|\$API_KEY = '$API_KEY';|g" $TARGET_DIR/fetch-videos.php

echo "---- Setting permissions ----"
sudo chown -R www-data:www-data $TARGET_DIR

echo "---- Restarting Apache ----"
sudo systemctl restart apache2

# Print access info
SERVER_IP=$(curl -s ifconfig.me)
echo ""
echo "========================================="
echo "✅ DONE! Access your YouTube player at:"
echo "   http://$SERVER_IP/yt/"
echo ""
echo "If using a domain, visit http://YOUR_DOMAIN/yt/"
echo "========================================="
