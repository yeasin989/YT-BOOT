from flask import Flask, render_template_string, request, redirect, url_for
from threading import Thread
import time

try:
    from selenium import webdriver
    from selenium.webdriver.chrome.options import Options
except ImportError:
    webdriver = None

app = Flask(__name__)

# Global state for bot progress
bot_state = {
    "running": False,
    "urls": [],
    "target_minutes": 0,
    "watched_minutes": 0,
}

HTML = """
<html>
<head><title>YouTube Watch Bot Admin</title></head>
<body style="font-family:sans-serif;">
    <h1>YouTube Watch Bot Admin Panel</h1>
    <form method="post" action="/start">
        <label>Video URLs (one per line, up to 10):<br>
            <textarea name="urls" rows="10" cols="60">{{ urls }}</textarea>
        </label><br><br>
        <label>Total Watch Time (minutes): <input type="number" name="minutes" value="{{ minutes }}" min="1" max="10080"></label><br><br>
        {% if not running %}
            <button type="submit">Start Watching</button>
        {% else %}
            <p style="color:green;"><b>Bot is running!</b></p>
        {% endif %}
    </form>
    <br>
    <form method="post" action="/stop">
        {% if running %}
            <button type="submit">Stop Bot</button>
        {% endif %}
    </form>
    <hr>
    <h3>Progress:</h3>
    <ul>
        <li>Running: {{ running }}</li>
        <li>Videos: {{ urls|length }}</li>
        <li>Target Minutes: {{ minutes }}</li>
        <li>Watched Minutes: {{ watched }}</li>
        <li>Watched Hours: {{ "%.2f"|format(watched/60) }}</li>
    </ul>
</body>
</html>
"""

@app.route('/', methods=["GET"])
def index():
    return render_template_string(HTML, 
        running=bot_state["running"],
        urls="\n".join(bot_state["urls"]),
        minutes=bot_state["target_minutes"],
        watched=bot_state["watched_minutes"]
    )

@app.route('/start', methods=["POST"])
def start():
    if not bot_state["running"]:
        urls = [u.strip() for u in request.form["urls"].strip().splitlines() if u.strip()]
        urls = urls[:10]
        minutes = max(1, int(request.form["minutes"]))
        bot_state["urls"] = urls
        bot_state["target_minutes"] = minutes
        bot_state["watched_minutes"] = 0
        bot_state["running"] = True
        t = Thread(target=watch_bot, daemon=True)
        t.start()
    return redirect(url_for('index'))

@app.route('/stop', methods=["POST"])
def stop():
    bot_state["running"] = False
    return redirect(url_for('index'))

def watch_bot():
    if webdriver is None:
        bot_state["running"] = False
        return
    chrome_options = Options()
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    driver = webdriver.Chrome(options=chrome_options)
    try:
        per_video = max(1, bot_state["target_minutes"] // max(1, len(bot_state["urls"])))
        for url in bot_state["urls"]:
            if not bot_state["running"]:
                break
            driver.get(url)
            time.sleep(5)
            try:
                play_button = driver.find_element("css selector", "button.ytp-large-play-button")
                play_button.click()
            except Exception:
                pass
            for i in range(per_video):
                if not bot_state["running"] or bot_state["watched_minutes"] >= bot_state["target_minutes"]:
                    break
                bot_state["watched_minutes"] += 1
                time.sleep(60)
        bot_state["running"] = False
    except Exception as e:
        print("Bot crashed:", e)
        bot_state["running"] = False
    finally:
        driver.quit()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
