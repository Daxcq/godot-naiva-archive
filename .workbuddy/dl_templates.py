# -*- coding: utf-8 -*-
"""Download Godot 4.6.3-stable export templates tpz with fallback mirrors."""
import sys, time, os, urllib.request

URLS = [
    "https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz",
    "https://ghproxy.net/https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz",
    "https://gh-proxy.com/https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz",
]
DEST = os.path.join(os.environ.get("TEMP", "."), "godot_templates.tpz")
log = open(os.path.join(os.environ.get("TEMP", "."), "tpl_download.log"), "w", encoding="utf-8")

def L(msg):
    print(msg, flush=True)
    log.write(msg + "\n")
    log.flush()

ok = False
for url in URLS:
    try:
        L("TRY " + url)
        t0 = time.time()
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=60) as resp, open(DEST, "wb") as f:
            total = int(resp.headers.get("Content-Length", 0))
            done = 0
            last_pct = -1
            while True:
                chunk = resp.read(1 << 20)
                if not chunk:
                    break
                f.write(chunk)
                done += len(chunk)
                if total:
                    pct = int(done * 100 / total)
                    if pct >= last_pct + 10:
                        L("  %d%% (%d/%d MB)" % (pct, done >> 20, total >> 20))
                        last_pct = pct
        L("DONE from %s in %.0fs, size=%d bytes" % (url, time.time() - t0, done))
        ok = True
        break
    except Exception as e:
        L("  FAIL: %r" % e)

L("RESULT: " + ("OK " + DEST if ok else "ALL_FAILED"))
log.close()
sys.exit(0 if ok else 1)
