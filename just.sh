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
  body {
    background-color: #181818;
    color: #fff;
    font-family: "Segoe UI", Arial, sans-serif;
    margin: 0;
  }
  .topbar {
    background: #242424cc;
    position: sticky;
    top: 0;
    z-index: 10;
    padding: 12px 20px 8px 20px;
    box-shadow: 0 2px 10px #0002;
    display: flex;
    flex-direction: column;
    align-items: flex-start;
  }
  .topbar h1 {
    font-size: 1.2rem;
    margin: 0 0 7px 0;
    letter-spacing: 1px;
    font-weight: 500;
  }
  .controls {
    width: 100%;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 7px;
  }
  .controls label {
    margin: 0;
    font-size: 0.99rem;
    font-weight: 400;
    color: #bbb;
  }
  .controls textarea, .controls input[type=number] {
    padding: 7px;
    border-radius: 6px;
    border: none;
    font-size: 14px;
    width: 180px;
    background: #222;
    color: #fff;
    margin-right: 6px;
    margin-bottom: 2px;
  }
  .controls textarea { width: 260px; height: 40px; resize: vertical;}
  .controls button {
    padding: 7px 16px;
    background: #e53935;
    color: #fff;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 15px;
    font-weight: bold;
    transition: background .15s;
    margin-left: 4px;
  }
  .controls button:hover { background: #b71c1c; }
  #videoGrid {
    margin: 0 auto;
    margin-top: 12px;
    display: grid;
    grid-template-columns: repeat(8, 1fr); /* 8 columns! */
    gap: 13px;
    max-width: 1800px;
    padding: 10px 15px;
  }
  @media (max-width: 1700px) { #videoGrid { grid-template-columns: repeat(6, 1fr); } }
  @media (max-width: 1350px) { #videoGrid { grid-template-columns: repeat(4, 1fr); } }
  @media (max-width: 950px) { #videoGrid { grid-template-columns: repeat(2, 1fr); } }
  @media (max-width: 680px) { #videoGrid { grid-template-columns: 1fr; } }
  .videoItem {
    background-color: #212121;
    border-radius: 8px;
    box-shadow: 0 2px 8px #0003;
    padding: 0;
    transition: box-shadow .15s, transform .13s;
    display: flex;
    flex-direction: column;
    align-items: stretch;
    overflow: hidden;
    position: relative;
  }
  .videoItem:hover { box-shadow: 0 6px 20px #0005; transform: translateY(-3px) scale(1.02);}
  .videoPlayer {
    width: 100%;
    aspect-ratio: 16 / 9;
    background: #191919;
    border: none;
    display: block;
  }
  .videoInfo {
    padding: 7px 9px 6px 9px;
    background: #262626;
    font-size: 13px;
    border-bottom-left-radius: 8px;
    border-bottom-right-radius: 8px;
    margin-top: -3px;
  }
  .videoTitle {
    font-weight: bold;
    margin-bottom: 2px;
    font-size: 13px;
    color: #fafafa;
    text-overflow: ellipsis;
    white-space: nowrap;
    overflow: hidden;
  }
  .videoChannel { font-size: 12px; color: #c7c7c7; margin-bottom: 2px;}
  .viewCount { font-size: 11px; color: #979797; }
</style>
</head>
<body>
  <div class="topbar">
    <h1>YT Multi Video Player</h1>
    <form class="controls" id="videoForm" onsubmit="return false;">
      <label for="urlsInput">URLs:</label>
      <textarea id="urlsInput" placeholder="Paste YouTube URLs"></textarea>
      <label for="countInput">Count:</label>
      <input type="number" id="countInput" min="1" max="80" value="16" />
      <button id="loadBtn">Load</button>
    </form>
  </div>

  <div id="videoGrid"></div>

<script>
const loadBtn = document.getElementById('loadBtn');
const urlsInput = document.getElementById('urlsInput');
const countInput = document.getElementById('countInput');
const videoGrid = document.getElementById('videoGrid');
const videoForm = document.getElementById('videoForm');

videoForm.addEventListener('submit', loadVideos);
loadBtn.addEventListener('click', loadVideos);

function loadVideos(e) {
  if (e) e.preventDefault();
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
    data.videos.forEach((video, idx) => {
      const videoItem = document.createElement('div');
      videoItem.className = 'videoItem';

      // For Chrome autoplay, set mute=1 if autoplay=1 is present
      // Only first video will auto-play with sound; others will be muted and autoplay
      const autoplay = idx === 0 ? 1 : 1;
      const mute = idx === 0 ? 0 : 1;

      videoItem.innerHTML = `
        <iframe class="videoPlayer"
          src="https://www.youtube.com/embed/${video.videoId}?autoplay=${autoplay}&mute=${mute}&rel=0&showinfo=1&modestbranding=1"
          allow="autoplay; encrypted-media" allowfullscreen></iframe>
        <div class="videoInfo">
          <div class="videoTitle" title="${video.title}">${video.title}</div>
          <div class="videoChannel">${video.channelTitle}</div>
          <div class="viewCount">${Number(video.viewCount).toLocaleString()} views</div>
        </div>
      `;

      videoGrid.appendChild(videoItem);
    });
  })
  .catch(() => {
    videoGrid.innerHTML = '<p style="color:red;">Failed to load videos.</p>';
  });
}
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
