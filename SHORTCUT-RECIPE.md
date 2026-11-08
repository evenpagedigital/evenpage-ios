# "Factory Refresh" Shortcut (build once, ~3 min) + daily automation
Shortcuts can't be pre-built/signed on our side as a file; an iCloud link can only be made from an Apple device,
so Ben builds it once (or, after building, shares its iCloud link so it can be reinstalled later in one tap).
Actions:
1. Get Network Details: Wi-Fi Network Name -> If it has any value (else Stop).
2. Set VPN: Connect to **LocalDevVPN** (iOS allows one VPN at a time; this drops Tailscale automatically).
3. Wait 2 seconds.
4. SideStore: **Refresh All Apps**.
5. Wait 3 seconds.
6. Set VPN: Disconnect LocalDevVPN.
7. Set VPN: Connect to **Tailscale**.
8. Wait 5 seconds.
9. Get Contents of URL: POST `https://desktop-03poelq.tailb5a5a1.ts.net/api/ios-heartbeat`, JSON body `build` = (text "current").
Automation tab > New > Time of Day 4:00 AM, Daily > Run Immediately (turn OFF "Notify When Run") > Factory Refresh.
Optional 2nd automation: When joining home Wi-Fi > same Shortcut > Run Immediately.
