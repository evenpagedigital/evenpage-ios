# Dashboard integration spec (for the dashboard job — NOT applied here)
1. Endpoint `POST /api/ios-heartbeat` (Tailscale-only, no auth secret in Shortcut beyond tailnet):
   body `{"build":"<N>"}` -> write `ai-factory/ios/state/heartbeat.json` = `{"last_refresh": now UTC ISO, "build": N}`.
2. Scheduled task (every 6 h, hidden window, same pattern as the dashboard watchdog):
   `python scripts/ios_health.py --heartbeat ..\state\heartbeat.json --source source\apps.json --out ..\state\ios-alerts.json`
3. Alerts panel: merge `ios-alerts.json` alerts (levels info/warn/urgent) into the existing alerts feed.
4. Release button/queue item: runs `scripts/ios_release.ps1` (dry-run until `APPROVED-GITHUB-REPO.txt` exists; `-Live` after).
5. Only rebuild when native code/plugins/icons change; UI changes ship live via the dashboard URL.
