from flask import Flask, render_template_string, request, redirect, url_for, jsonify
from threading import Thread, Lock
import time

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager

app = Flask(__name__)

video_data = []
progress = {}
looping = False
lock = Lock()

HTML = '''
<!doctype html>
<title>YouTube Watch Bot Admin</title>
<h2 style="font-family:Arial;">YouTube Watch Time Bot</h2>
<form method=post>
  <label>Add up to 10 Video URLs (one per line):</label><br>
  <textarea name="urls" rows="10" cols="60">{{ urls }}</textarea><br><br>
  <label>Watch Time (minutes) for each video (comma separated, or single value for all):</label><br>
  <input name="watch_times" type="text" value="{{ watch_times }}"><br><br>
  <input type=submit value="Save List">
</form>
<br>
<form method=post action="/start">
    <button type=submit>Start Watching</button>
</form>
<br>
<h3>Status</h3>
<table border=1 cellpadding=5>
  <tr>
    <th>Video URL</th>
    <th>Target (min)</th>
    <th>Watched (min)</th>
    <th>Progress</th>
    <th>Status</th>
  </tr>
  {% for i, v in enumerate(videos) %}
  <tr>
    <td>{{ v['url'] }}</td>
    <td>{{ v['target'] }}</td>
    <td id="watched-{{i}}">{{ v['watched'] }}</td>
    <td id="progress-{{i}}">{{ v['progress'] }}%</td>
    <td id="status-{{i}}">{{ v['status'] }}</td>
  </tr>
  {% endfor %}
</table>
<script>
function reloadProgress() {
    fetch('/progress')
    .then(res => res.json())
    .then(data => {
        for (let i = 0; i < data.length; i++) {
            document.getElementById("watched-"+i).innerText = data[i].watched;
            document.getElementById("progress-"+i).innerText = data[i].progress + "%";
            document.getElementById("status-"+i).innerText = data[i].status;
        }
    });
}
setInterval(reloadProgress, 3000);
</script>
'''

def watcher():
    global looping
    looping = True
    for idx, v in enumerate(video_data):
        url, target = v['url'], v['target']
        video_data[idx]['watched'] = 0
        video_data[idx]['progress'] = 0
        video_data[idx]['status'] = "Waiting"
    while looping:
        all_done = True
        for idx, v in enumerate(video_data):
            if v['watched'] < v['target']:
                all_done = False
                with lock:
                    video_data[idx]['status'] = "Watching"
                # --- Start Selenium
                options = Options()
                options.add_argument('--headless')
                options.add_argument('--no-sandbox')
                options.add_argument('--disable-gpu')
                options.add_argument('--disable-dev-shm-usage')
                driver = webdriver.Chrome(ChromeDriverManager().install(), options=options)
                driver.get(v['url'])
                # Try to click play
                try:
                    play_button = driver.find_element('css selector', 'button.ytp-large-play-button')
                    play_button.click()
                except Exception:
                    pass
                minute_to_watch = min(1, v['target'] - v['watched'])
                time.sleep(minute_to_watch * 60)
                driver.quit()
                with lock:
                    video_data[idx]['watched'] += minute_to_watch
                    p = int((video_data[idx]['watched'] / v['target']) * 100)
                    video_data[idx]['progress'] = min(p, 100)
                    if video_data[idx]['watched'] >= v['target']:
                        video_data[idx]['status'] = "Complete"
                    else:
                        video_data[idx]['status'] = "Looping"
            else:
                with lock:
                    video_data[idx]['status'] = "Complete"
        if all_done:
            looping = False
        time.sleep(1)

@app.route('/', methods=['GET', 'POST'])
def index():
    global video_data
    urls = ""
    watch_times = ""
    if request.method == 'POST':
        urls = request.form['urls']
        watch_times = request.form['watch_times']
        url_list = [u.strip() for u in urls.splitlines() if u.strip()][:10]
        if "," in watch_times:
            wt_list = [int(w.strip()) for w in watch_times.split(",")]
        else:
            try:
                wt = int(watch_times.strip())
                wt_list = [wt]*len(url_list)
            except:
                wt_list = [1]*len(url_list)
        video_data = []
        for i, u in enumerate(url_list):
            video_data.append({
                "url": u,
                "target": wt_list[i] if i < len(wt_list) else wt_list[0],
                "watched": 0,
                "progress": 0,
                "status": "Ready"
            })
    return render_template_string(HTML, videos=video_data, urls=urls, watch_times=watch_times)

@app.route('/start', methods=['POST'])
def start():
    global looping
    if not looping and len(video_data):
        t = Thread(target=watcher)
        t.daemon = True
        t.start()
    return redirect(url_for('index'))

@app.route('/progress')
def get_progress():
    with lock:
        data = [{"watched": v["watched"], "progress": v["progress"], "status": v["status"]} for v in video_data]
    return jsonify(data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
