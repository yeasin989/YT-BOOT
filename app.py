from flask import Flask, render_template_string, request, jsonify
from threading import Thread, Lock
import time

app = Flask(__name__)

progress_data = []
progress_lock = Lock()
RUNNING = False

HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>YouTube Watch Bot Admin</title>
    <style>
        body { font-family: sans-serif; max-width:700px; margin:30px auto; background:#fafafa; }
        table { width:100%; border-collapse: collapse; margin-top:20px;}
        th, td { border:1px solid #bbb; padding:8px; text-align:left;}
        th { background:#ddd;}
        tr:nth-child(even) {background: #f2f2f2;}
        .btn { padding:10px 20px; font-size:1rem; background:#4CAF50; color:#fff; border:none; border-radius:5px; cursor:pointer;}
        .btn[disabled] { background:#ccc;}
    </style>
</head>
<body>
    <h2>YouTube Watch Bot Admin Panel</h2>
    <form id="mainForm" method="POST" action="/">
        <label>Paste 1 video URL per line (max 10):</label><br>
        <textarea name="urls" rows="10" style="width:100%">{{urls}}</textarea><br><br>
        <label>Minutes to watch (per video, then loop):</label><br>
        <input type="number" name="minutes" value="{{minutes}}" min="1" max="1440"><br><br>
        <button class="btn" type="submit" name="action" value="start" {{'disabled' if running else ''}}>Start</button>
        <button class="btn" type="submit" name="action" value="stop" style="background:#e53935;" {{'' if running else 'disabled'}}>Stop</button>
    </form>
    <br>
    <h3>Progress (Live)</h3>
    <table>
        <tr><th>#</th><th>Video URL</th><th>Watched Minutes</th><th>Status</th></tr>
        <tbody id="progressRows">
        {% for v in progress %}
        <tr>
            <td>{{loop.index}}</td>
            <td><a href="{{v['url']}}" target="_blank">{{v['url']}}</a></td>
            <td>{{v['watched']}} / {{v['target']}}</td>
            <td>{{v['status']}}</td>
        </tr>
        {% endfor %}
        </tbody>
    </table>
    <script>
        function fetchProgress() {
            fetch("/progress")
                .then(response => response.json())
                .then(data => {
                    let rows = "";
                    data.forEach(function(v, i) {
                        rows += `<tr>
                            <td>${i+1}</td>
                            <td><a href="${v.url}" target="_blank">${v.url}</a></td>
                            <td>${v.watched} / ${v.target}</td>
                            <td>${v.status}</td>
                        </tr>`;
                    });
                    document.getElementById("progressRows").innerHTML = rows;
                });
        }
        setInterval(fetchProgress, 2000);  // update every 2 seconds
        fetchProgress();
    </script>
</body>
</html>
"""

def watch_video(idx):
    while RUNNING:
        with progress_lock:
            entry = progress_data[idx]
        # Simulate "watching" a minute every few seconds for demo (replace with actual watch logic)
        time.sleep(3)  # Pretend 1 minute is 3 seconds for testing
        with progress_lock:
            if not RUNNING: break
            entry['watched'] += 1
            entry['status'] = "Watching"
            if entry['watched'] >= entry['target']:
                entry['status'] = "Finished, restarting..."
                entry['watched'] = 0  # reset to loop
    with progress_lock:
        progress_data[idx]['status'] = "Stopped"

def start_all_threads():
    threads = []
    for idx in range(len(progress_data)):
        t = Thread(target=watch_video, args=(idx,), daemon=True)
        t.start()
        threads.append(t)
    return threads

@app.route("/", methods=["GET", "POST"])
def index():
    global RUNNING, progress_data
    urls = ""
    minutes = 1
    if request.method == "POST":
        action = request.form.get("action")
        if action == "start":
            urls = request.form.get("urls", "")
            minutes = int(request.form.get("minutes", "1"))
            url_list = [u.strip() for u in urls.splitlines() if u.strip()][:10]
            with progress_lock:
                progress_data = [{"url": u, "watched": 0, "target": minutes, "status": "Waiting"} for u in url_list]
            RUNNING = True
            Thread(target=start_all_threads, daemon=True).start()
        elif action == "stop":
            RUNNING = False
            with progress_lock:
                for entry in progress_data:
                    entry['status'] = "Stopped"
    with progress_lock:
        progress = list(progress_data)
        running = RUNNING
    return render_template_string(HTML, progress=progress, urls=urls, minutes=minutes, running=running)

@app.route("/progress")
def progress():
    with progress_lock:
        return jsonify(progress_data)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
