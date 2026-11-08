# Factory iOS shell (phase 1)
Capacitor 7 wrapper that loads the live Factory Console over Tailscale (no rebuild needed for dashboard updates).
Build: push this folder to a PUBLIC GitHub repo (macOS runners free/unlimited for public repos; private repos use free minutes at 10x rate),
run the "ios-unsigned-ipa" workflow, download the artifact, install the .ipa with SideStore (iloader on Windows).
Phase 2 (native voice, from data\design_jobs\nativevoice2-20261101-2203): Swift plugin with WhisperKit STT + Silero VAD + barge-in; Kokoro bm_george stays on the PC.
Caveats: unverified build (no Mac/CI run yet). Tailscale VPN and LocalDevVPN cannot both be on; switch to LocalDevVPN only to refresh.
Repo must contain no secrets. Intended repository: `evenpagedigital/evenpage-ios`. Tailscale HTTPS serves the dashboard at `https://desktop-03poelq.tailb5a5a1.ts.net/` (no explicit port). Local HTTP port 8797 is not the phone HTTPS port.

SideStore source (available after first successful build): `https://raw.githubusercontent.com/evenpagedigital/evenpage-ios/main/source/apps.json`.

## Go live
Local project: `C:\Users\Ben\ai-factory\ios`. Follow `BEN-CHECKLIST.md`.
`./go-live.ps1 -DryRun` performs file/secret and CLI account preflight only; no files, repo or workflow changes.
The live path uses gh Git Data API with an explicit file allowlist (no git add -A), non-forced main updates,
local approval only after a successful push, unique workflow-run correlation and a 30-minute build timeout.
Existing local remotes must match; they are never rewritten. Empty/new projects need no Git for Windows.
Live API request bodies are retained under `.publish-work` locally, never uploaded as files.
A re-run preserves generated source/apps.json and refuses unexpected remote files.
Preparation did not install, authenticate, create a repository, publish or run CI. Build remains unverified until Ben runs it.
