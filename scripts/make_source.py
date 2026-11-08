#!/usr/bin/env python3
"""Create/refresh an AltStore-Classic/SideStore source JSON. Newest version first (order = latest)."""
import argparse, json, os, sys, datetime, zipfile, plistlib
ap = argparse.ArgumentParser()
ap.add_argument("--source", required=True); ap.add_argument("--ipa", required=True)
ap.add_argument("--version", required=True); ap.add_argument("--build", required=True)
ap.add_argument("--url", required=True); ap.add_argument("--notes", default="Factory update")
ap.add_argument("--repo", default="evenpagedigital/evenpage-ios"); ap.add_argument("--keep", type=int, default=5)
a = ap.parse_args()
BUNDLE = "com.benmcclain.factoryconsole"
privacy = {}
with zipfile.ZipFile(a.ipa) as z:
    names = [n for n in z.namelist() if n.count("/") == 2 and n.endswith(".app/Info.plist")]
    if names:
        info = plistlib.loads(z.read(names[0]))
        BUNDLE = info.get("CFBundleIdentifier", BUNDLE)
        privacy = {k: v for k, v in info.items() if k.endswith("UsageDescription")}
if os.path.exists(a.source):
    src = json.load(open(a.source))
else:
    src = {"name": "Ben's Factory", "identifier": "com.benmcclain.factory.source",
           "subtitle": "Private source for the Factory app", "website": f"https://github.com/{a.repo}",
           "tintColor": "#3B82F6", "apps": [], "news": []}
apps = [x for x in src["apps"] if x.get("bundleIdentifier") == BUNDLE]
if not apps:
    app = {"name": "Factory", "bundleIdentifier": BUNDLE, "developerName": "Ben McClain",
           "subtitle": "Factory console", "localizedDescription": "Phone shell for the factory dashboard.",
           "iconURL": f"https://raw.githubusercontent.com/{a.repo}/main/source/icon.png",
           "tintColor": "#3B82F6", "category": "utilities", "versions": [],
           "appPermissions": {"entitlements": [], "privacy": {}}}
    src["apps"].append(app)
else:
    app = apps[0]
app["appPermissions"]["privacy"] = privacy
v = {"version": a.version, "buildVersion": str(a.build),
     "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
     "localizedDescription": a.notes, "downloadURL": a.url, "size": os.path.getsize(a.ipa),
     "minOSVersion": "15.0"}
app["versions"] = [v] + [x for x in app["versions"] if x["buildVersion"] != str(a.build)][: a.keep - 1]
# legacy top-level keys some SideStore builds still read
app.update({"version": v["version"], "versionDate": v["date"], "downloadURL": v["downloadURL"], "size": v["size"]})
os.makedirs(os.path.dirname(a.source) or ".", exist_ok=True)
json.dump(src, open(a.source, "w"), indent=2)
print(f"source updated: {BUNDLE} {a.version} ({a.build}) -> {a.url}")
