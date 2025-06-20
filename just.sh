#!/bin/bash
set -e

echo "---- Updating system ----"
sudo apt-get update -y
sudo apt-get upgrade -y

echo "---- Installing Apache, PHP, and dependencies ----"
sudo apt-get install -y apache2 php php-curl php-xml php-mbstring git unzip

echo "---- Cloning your GitHub repo ----"
# (Change this to your actual GitHub repo URL)
REPO_URL="https://github.com/yourusername/youtube-multiplayer-api.git"
TARGET_DIR="/var/www/html/youtube-multiplayer-api"

sudo rm -rf $TARGET_DIR
sudo git clone $REPO_URL $TARGET_DIR

echo "---- Setting up your API key in PHP ----"
# Replace the API_KEY line in fetch-videos.php automatically
sudo sed -i "s|\$API_KEY = '.*';|\$API_KEY = 'AIzaSyABhMZekcrvV2Lh1yqntJPWJhiLcgWRigY';|g" $TARGET_DIR/fetch-videos.php

echo "---- Setting permissions ----"
sudo chown -R www-data:www-data $TARGET_DIR

echo "---- Configuring Apache ----"
# Symlink or copy index.html and fetch-videos.php to /var/www/html if you want to use root domain
sudo cp $TARGET_DIR/index.html /var/www/html/index.html
sudo cp $TARGET_DIR/fetch-videos.php /var/www/html/fetch-videos.php

echo "---- Restarting Apache ----"
sudo systemctl restart apache2

echo "---- All done! ----"
echo "Visit http://YOUR_SERVER_IP/ to use your multi video player system."
