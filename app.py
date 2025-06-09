import threading
import time
from flask import Flask, render_template_string, request, redirect, url_for, jsonify

try:
    from selenium import webdriver
    from selenium.webdriver.chrome.options import Options
except ImportError:
    webdriver = None  # So code doesn't crash if selenium not installed

app = Flask(__name__)

HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>YouTube Watch Bot Admin Panel</title>
    <style>
        body { font-family: Arial; background: #f5f5f5; }
        .container { max-width: 900px; margin: 40px auto; background: #fff; border-radius: 8px; padding: 24px; box-shadow: 0 2px 10px #ccc; }
        table { border-collapse: collapse; width: 100%; margin-top: 24px;}
        th, td { border: 1px solid #e3e3e3; padding: 8px; text-align: center; }
        th { background: #e3e3e3; }
        input[type='text'], input[type='number'] { width: 85%; padding: 6px; margin: 2px 0; }
        .btn { padding: 8px 20px; border: none; border-radius: 5px; background: #198754; color: #fff; cursor: pointer; margin: 0 5px; }
        .btn-stop { background: #d33; }
        .status { font-weight: bold; }
        .progress { width: 100px; }
    </style>
    <script>
        function fetchProgress() {
            fetch("/progress")
                .then(response => response.json())
                .then(data => {
                    data.forEach(function(v, idx) {
                        document.getElementById("watched-"+idx).innerText = v.watched_min + " / " + v.target_min;
                        document.getElementById("progress-"+idx).innerText = v.progress + "%";
                        document.getElementById("status-"+idx).innerText = v.status;
                    });
                });
        }
        setInterval(fetchProgress, 3000);
        window.onload = fetchProgress;
    </script>
</head>
<body>
    <div class="container">
        <h2>YouTube Watch Bot Admin Panel</h2>
        <form method="POST" action="/add" style="margin-bottom: 14px;">
            <b>Add Video URL:</b> <input name="url" type="text" required placeholder="YouTube Video URL" />
            <b>Watch Minutes:</b> <input name="minutes" type="number" min="1" max="9999" value="30" required />
            <button class="btn" type="submit">Add</button>
        </form>
        <form method="POST" action="/start" style="display:inline;">
            <button class="btn" type="submit">Start Watching</button>
        </form>
        <form method="POST" action="/stop" style="display:inline;">
            <button class="btn btn-stop" type="submit">Stop All</button>
        </form>
        <form method="POST" action="/reset" style="display:inline;">
            <button class="btn" style="background:#666;" type="submit">Reset List</button>
        </form>
        <table>
            <tr>
                <th>#</th>
                <th>Video URL</th>
                <th>Target<br>(min)</th>
                <th>Watched<br>(min)</th>
                <th class="progress">Progress</th>
                <th>Status</th>
            </tr>
            {% for v in videos %}
            <tr>
                <td>{{ loop.index }}</td>
                <td style="word-break:break-all;"><a href="{{ v['url'] }}" target="_blank">{{ v['url'] }}</a></td>
                <td>{{ v['target_min'] }}</td>
                <td id="watched-{{ loop.index0 }}">{{ v['watched_min'] }}</td>
                <td id="progress-{{ loop.index0 }}">{{ v['progress'] }}%</td>
                <td class="status" id="status-{{ loop.index0 }}">{{ v['status'] }}</td>
            </tr>
            {% endfor %}
        </table>
        <div style="margin-top:14px;font-size:13px;">
            <i>Max 10 videos. If watch time expires and video is short, it will loop video to reach target. <b>For educational/testing only.</b></i>
        </div>
    </div>
</body>
</html>
"""

# ---- BOT DATA ----
video_data = []
bot_threads = []
bot_stop_event = threading.Event()

def new_video_data(url, target_min):
    return {
        'url': url,
        'target_min': int(target_min),
        'watched_min': 0,
        'progress': 0,
        'status': 'Queued',
    }

# ---- WATCH LOGIC ----

def watch_video(idx):
    v = video_data[idx]
    v['status'] = 'Running'
    total_seconds = v['target_min'] * 60
    seconds_watched = 0

    # Chrome Headless
    if webdriver is None:
        v['status'] = 'Selenium Not Installed'
        return

    chrome_options = Options()
    chrome_options.add_argument("--headless=new")
    chrome_options.add_argument("--mute-audio")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-gpu")
    chrome_options.add_argument("--window-size=1280,800")

    while seconds_watched < total_seconds and not bot_stop_event.is_set():
        try:
            driver = webdriver.Chrome(options=chrome_options)
            driver.set_page_load_timeout(40)
            driver.get(v['url'])
            v['status'] = 'Watching...'
            time.sleep(6)  # Let player load
            video_length = 180  # Fallback to 3min

            try:
                duration = driver.execute_script("""
                    return document.querySelector('video') ? document.querySelector('video').duration : 0;
                """)
                if duration and duration > 10:  # Real duration in seconds
                    video_length = int(duration)
            except Exception:
                pass

            # Watch as many seconds as possible in this run (either to video end, or to target)
            left = min(video_length, total_seconds - seconds_watched)
            watch_per_loop = min(left, 40)  # Watch in 40s segments (simulate user)
            start_time = time.time()
            elapsed = 0
            while elapsed < left and not bot_stop_event.is_set():
                loop_watch = min(watch_per_loop, left - elapsed)
                time.sleep(loop_watch)
                elapsed = int(time.time() - start_time)
                seconds_watched += loop_watch
                # Update progress
                v['watched_min'] = int(seconds_watched // 60)
                v['progress'] = int((seconds_watched / total_seconds) * 100)
                v['status'] = 'Watching...'
            driver.quit()
            if seconds_watched < total_seconds and not bot_stop_event.is_set():
                v['status'] = 'Looping video'
        except Exception as e:
            v['status'] = f'Error: {str(e)}'
            try:
                driver.quit()
            except: pass
            break

    # Finished or stopped
    if seconds_watched >= total_seconds:
        v['watched_min'] = v['target_min']
        v['progress'] = 100
        v['status'] = 'Complete'
    elif bot_stop_event.is_set():
        v['status'] = 'Stopped'

# ---- ROUTES ----

@app.route("/", methods=["GET"])
def index():
    return render_template_string(HTML, videos=video_data)

@app.route("/add", methods=["POST"])
def add():
    if len(video_data) >= 10:
        return redirect(url_for("index"))
    url = request.form.get("url")
    minutes = request.form.get("minutes")
    if url and minutes:
        video_data.append(new_video_data(url, minutes))
    return redirect(url_for("index"))

@app.route("/reset", methods=["POST"])
def reset():
    stop_all()
    video_data.clear()
    return redirect(url_for("index"))

@app.route("/start", methods=["POST"])
def start():
    if not video_data:
        return redirect(url_for("index"))
    stop_all()
    bot_stop_event.clear()
    bot_threads.clear()
    for idx, v in enumerate(video_data):
        v['watched_min'] = 0
        v['progress'] = 0
        v['status'] = 'Queued'
    for idx, v in enumerate(video_data):
        t = threading.Thread(target=watch_video, args=(idx,))
        t.daemon = True
        bot_threads.append(t)
        t.start()
    return redirect(url_for("index"))

@app.route("/stop", methods=["POST"])
def stop():
    stop_all()
    return redirect(url_for("index"))

def stop_all():
    bot_stop_event.set()
    for t in bot_threads:
        if t.is_alive():
            t.join(timeout=1)
    for v in video_data:
        if v['status'] not in ('Complete', 'Stopped'):
            v['status'] = 'Stopped'

@app.route("/progress", methods=["GET"])
def progress():
    # Return realtime progress as JSON for frontend
    data = []
    for v in video_data:
        data.append({
            'watched_min': v['watched_min'],
            'target_min': v['target_min'],
            'progress': v['progress'],
            'status': v['status'],
        })
    return jsonify(data)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
