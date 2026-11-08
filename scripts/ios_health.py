#!/usr/bin/env python3
"""Expiry watchdog. Reads heartbeat JSON (written by dashboard endpoint when the phone Shortcut pings it
after each refresh) and the published source; writes an alert JSON for the dashboard alerts feed.
heartbeat file: {"last_refresh": ISO8601, "build": "N"}   (no secrets)
"""
import json, sys, argparse, datetime as dt, os
ap = argparse.ArgumentParser()
ap.add_argument("--heartbeat", required=True); ap.add_argument("--source")
ap.add_argument("--out", required=True); ap.add_argument("--now")
ap.add_argument("--warn-days", type=float, default=5); ap.add_argument("--expiry-days", type=float, default=7)
a = ap.parse_args()
now = dt.datetime.fromisoformat(a.now) if a.now else dt.datetime.now(dt.timezone.utc)
def p(s): return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
alerts = []
if not os.path.exists(a.heartbeat):
    alerts.append({"level": "warn", "title": "iPhone app: no refresh seen yet", "detail": "Phone Shortcut has never pinged."})
else:
    hb = json.load(open(a.heartbeat)); age = (now - p(hb["last_refresh"])).total_seconds() / 86400
    left = a.expiry_days - age
    if age >= a.expiry_days:
        alerts.append({"level": "urgent", "title": "iPhone app has likely EXPIRED", "detail": f"Last refresh {age:.1f} days ago. Plug in to PC and re-run iloader."})
    elif age >= a.warn_days:
        alerts.append({"level": "warn", "title": f"iPhone app expires in ~{left:.1f} days", "detail": f"No refresh for {age:.1f} days. Open SideStore > Refresh All, or check the Shortcut automation / LocalDevVPN."})
    if a.source and os.path.exists(a.source):
        s = json.load(open(a.source)); latest = s["apps"][0]["versions"][0]["buildVersion"]
        if str(hb.get("build")) != str(latest):
            alerts.append({"level": "info", "title": f"iPhone app update ready (build {latest})", "detail": f"Phone has build {hb.get('build')}. Tap Update in SideStore."})
json.dump({"generated": now.isoformat(), "source": "ios_health", "alerts": alerts}, open(a.out, "w"), indent=2)
print(json.dumps(alerts)); sys.exit(2 if any(x["level"] == "urgent" for x in alerts) else 0)
