# Factory iOS — Ben's remaining steps

Project folder: **`C:\Users\Ben\ai-factory\ios`**

1. PC PowerShell: `winget install GitHub.cli`, then reopen PowerShell. No Git installation is needed for this fresh pipeline folder.
2. Run `gh auth login --scopes workflow`. Choose **GitHub.com → HTTPS → browser**, signed in as **evenpagedigital**. The workflow scope allows uploading the workflow file. Never paste a token into chat or a file.
3. Run:
   ```powershell
   Set-Location 'C:\Users\Ben\ai-factory\ios'
   .\go-live.ps1
   ```
   This publishes only the printed allowlist to the **public** `evenpagedigital/evenpage-ios` repo, starts one build, and waits at most 30 minutes. It does not install or authenticate anything. Stop and report any error. Reruns are non-forcing and safe; a successful rerun requests a fresh build. This step is the publication approval; nothing was published during preparation. Keep paid Actions disabled; no paid plan or billing upgrade is needed.
4. Do the **one-time SideStore install** below.
5. In SideStore, add this source, available after the first successful build, and install **Factory**:
   **https://raw.githubusercontent.com/evenpagedigital/evenpage-ios/main/source/apps.json**
6. Build the **Factory Refresh Shortcut** from `SHORTCUT-RECIPE.md`, run once, then add its daily automation. Keep Tailscale connected for normal dashboard use.

Optional read-only check before step 3: `.\go-live.ps1 -DryRun` (no file/repo/workflow changes). If gh is missing it exits 2 cleanly. No factory recurring tasks are enabled by these scripts.

## iPhone / SideStore
1. PC: install iTunes (apple.com version) and iloader (iloader.app). Plug in the iPhone, tap Trust, enter passcode.
2. iloader: sign in with a free Apple ID, pick the iPhone, Install SideStore (Stable). In iloader > Management > Manage Pairing File > Place for SideStore.
3. iPhone (iOS forces these, once): Settings > Privacy & Security > Developer Mode On (restarts); Settings > General > VPN & Device Management > your Apple ID > Trust.
4. App Store: install LocalDevVPN, open it, allow the VPN profile, Connect. Open SideStore, sign in with the same Apple ID, Refresh once.
5. SideStore > Sources > + > paste `https://raw.githubusercontent.com/evenpagedigital/evenpage-ios/main/source/apps.json`. Install "Factory" from it. Allow Microphone/Speech when asked.
6. Shortcuts: build "Factory Refresh" (SHORTCUT-RECIPE.md, 9 actions) and the daily 4 AM "Run Immediately" automation. Run it once by hand to confirm.
7. Settings > General > Background App Refresh: On for SideStore.
## Honest limits iOS forces
- App updates: SideStore shows an Update button; it does not silently install. Most changes need no update at all (the app loads the live dashboard), and the dashboard will alert when a new build is waiting.
- If the phone is off/away from Wi-Fi for 7 days, or SideStore gets logged out, or a major iOS update breaks pairing, the app stops opening: replug to PC and redo step 2. The dashboard warns at 5 days with no refresh.
- Free Apple ID: 3 apps incl. SideStore, 10 App IDs/week.

## Heartbeat
POST **https://desktop-03poelq.tailb5a5a1.ts.net/api/ios-heartbeat**, JSON body `{"build":"current"}`. Use Tailscale after the SideStore refresh. No `:8797`: local HTTP port 8797 is not the Tailscale HTTPS port. The live no-port endpoint was verified by the parallel PC job; the earlier `:8797` URL failed.

Recurring jobs remain paused; this checklist does not enable any factory schedule. SideStore refreshes and iOS background execution are best-effort, not a guarantee of zero future intervention.
