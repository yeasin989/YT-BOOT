#!/bin/bash
set -e

FOLDER="yt"
TARGET_DIR="/var/www/html/$FOLDER"
API_KEY="AIzaSyABhMZekcrvV2Lh1yqntJPWJhiLcgWRigY"

echo "---- Installing Apache, PHP, and dependencies ----"
sudo apt-get update -y
sudo apt-get install -y apache2 php php-curl php-xml php-mbstring

echo "---- Creating /yt folder ----"
sudo mkdir -p $TARGET_DIR

echo "---- Writing fetch-videos.php ----"
sudo tee $TARGET_DIR/fetch-videos.php > /dev/null <<EOF
<?php
header('Content-Type: application/json');
\$API_KEY = '$API_KEY';
if (\$_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['error' => 'Invalid request method']); exit;
}
\$urls_raw = isset(\$_POST['urls']) ? \$_POST['urls'] : '';
\$count_raw = isset(\$_POST['count']) ? \$_POST['count'] : '';
if (empty(trim(\$urls_raw))) {
    echo json_encode(['error' => 'No URLs provided']); exit;
}
\$count = intval(\$count_raw); if (\$count <= 0) \$count = 10;
function extractYoutubeId(\$url) {
    \$url = trim(\$url);
    if (preg_match('#youtu\.be/([A-Za-z0-9_\-]+)#', \$url, \$m)) return \$m[1];
    if (preg_match('#youtube\.com/watch\?v=([A-Za-z0-9_\-]+)#', \$url, \$m)) return \$m[1];
    if (preg_match('#youtube\.com/embed/([A-Za-z0-9_\-]+)#', \$url, \$m)) return \$m[1];
    return '';
}
\$urls = preg_split('/[\\r\\n,]+/', \$urls_raw);
\$videoIds = [];
foreach (\$urls as \$url) {
    \$id = extractYoutubeId(\$url);
    if (\$id !== '') \$videoIds[] = \$id;
}
if (empty(\$videoIds)) {
    echo json_encode(['error' => 'No valid video IDs found']); exit;
}
\$fullList = [];
for (\$i = 0; \$i < \$count; \$i++) {
    \$fullList[] = \$videoIds[\$i % count(\$videoIds)];
}
function youtubeApiRequest(\$url) {
    \$ch = curl_init(\$url);
    curl_setopt(\$ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt(\$ch, CURLOPT_TIMEOUT, 10);
    curl_setopt(\$ch, CURLOPT_SSL_VERIFYPEER, false);
    \$result = curl_exec(\$ch);
    \$err = curl_error(\$ch);
    curl_close(\$ch);
    if (\$result === false) return ['error' => \$err];
    return \$result;
}
\$results = [];
\$chunks = array_chunk(\$fullList, 50);
foreach (\$chunks as \$chunk) {
    \$ids = implode(',', \$chunk);
    \$apiUrl = "https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics&id=\$ids&key=\$API_KEY";
    \$response = youtubeApiRequest(\$apiUrl);
    if (is_array(\$response) && isset(\$response['error'])) {
        echo json_encode(['error' => 'YouTube API request failed', 'details' => \$response['error']]);
        exit;
    }
    \$data = json_decode(\$response, true);
    if (!isset(\$data['items'])) {
        echo json_encode(['error' => 'Invalid YouTube API response', 'raw' => \$response]);
        exit;
    }
    foreach (\$data['items'] as \$item) {
        \$results[] = [
            'videoId'      => \$item['id'],
            'title'        => \$item['snippet']['title'],
            'channelTitle' => \$item['snippet']['channelTitle'],
            'thumbnail'    => \$item['snippet']['thumbnails']['medium']['url'],
            'viewCount'    => isset(\$item['statistics']['viewCount']) ? \$item['statistics']['viewCount'] : 'N/A'
        ];
    }
}
echo json_encode(['videos' => \$results]);
exit;
EOF

echo "---- Writing index.html ----"
sudo tee $TARGET_DIR/index.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>YouTube Multi Video Player</title>
<style>
  body { background-color: #121212; color: #fff; font-family: Arial, sans-serif; margin: 20px; }
  label { display: block; margin-top: 15px; }
  textarea, input[type=number] { width: 100%; padding: 10px; border-radius: 6px; border: none; font-size: 16px; box-sizing: border-box; }
  button { margin-top: 15px; padding: 10px 20px; background-color: #7e57c2; color: #fff; border: none; border-radius: 6px; cursor: pointer; font-size: 16px; }
  button:hover { background-color: #5e35b1; }
  #videoGrid { margin-top: 30px; display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 15px; }
  .videoItem { background-color: #1e1e1e; border-radius: 8px; padding: 10px; }
  .videoTitle { margin: 8px 0 4px 0; font-weight: bold; }
  .videoChannel { font-size: 14px; color: #bbb; margin-bottom: 8px; }
  iframe { width: 100%; height: 170px; border-radius: 8px; border: none; }
  .viewCount { font-size: 13px; color: #888; }
</style>
</head>
<body>

<h1>YouTube Multi Video Player</h1>

<label for="urlsInput">Enter YouTube URLs (comma or newline separated):</label>
<textarea id="urlsInput" rows="5" placeholder="https://youtu.be/VIDEOID1, https://www.youtube.com/watch?v=VIDEOID2"></textarea>

<label for="countInput">Number of videos to play:</label>
<input type="number" id="countInput" min="1" value="10" />

<button id="loadBtn">Load Videos</button>

<div id="videoGrid"></div>

<script>
const loadBtn = document.getElementById('loadBtn');
const urlsInput = document.getElementById('urlsInput');
const countInput = document.getElementById('countInput');
const videoGrid = document.getElementById('videoGrid');

loadBtn.addEventListener('click', () => {
  const urls = urlsInput.value.trim();
  const count = parseInt(countInput.value);

  if (!urls) {
    alert('Please enter YouTube URLs.');
    return;
  }
  if (!count || count < 1) {
    alert('Please enter a valid number of videos to play.');
    return;
  }

  videoGrid.innerHTML = '<p style="color:#888;">Loading videos...</p>';

  fetch('fetch-videos.php', {
    method: 'POST',
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: `urls=${encodeURIComponent(urls)}&count=${count}`
  })
  .then(response => response.json())
  .then(data => {
    if (data.error) {
      videoGrid.innerHTML = `<p style="color:red;">Error: ${data.error}</p>`;
      return;
    }
    if (!data.videos || data.videos.length === 0) {
      videoGrid.innerHTML = '<p style="color:#888;">No videos found.</p>';
      return;
    }

    videoGrid.innerHTML = '';
    data.videos.forEach(video => {
      const videoItem = document.createElement('div');
      videoItem.className = 'videoItem';

      videoItem.innerHTML = `
        <iframe src="https://www.youtube.com/embed/${video.videoId}?rel=0&showinfo=1&autoplay=0&modestbranding=1" allowfullscreen allow="autoplay"></iframe>
        <div class="videoTitle">${video.title}</div>
        <div class="videoChannel">${video.channelTitle}</div>
        <div class="viewCount">${Number(video.viewCount).toLocaleString()} views</div>
      `;

      videoGrid.appendChild(videoItem);
    });
  })
  .catch(() => {
    videoGrid.innerHTML = '<p style="color:red;">Failed to load videos.</p>';
  });
});
</script>

</body>
</html>
EOF

echo "---- Setting permissions ----"
sudo chown -R www-data:www-data $TARGET_DIR

echo "---- Restarting Apache ----"
sudo systemctl restart apache2

echo ""
echo "========================================="
echo "✅ DONE! Access your YouTube player at:"
echo "   http://$(curl -s ifconfig.me)/yt/"
echo "========================================="
