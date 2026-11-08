#!/usr/bin/env python3
"""Validate a source against required keys from faq.altstore.io/developers/make-a-source (AltStore Classic)."""
import json, sys, re, datetime
s = json.load(open(sys.argv[1])); err = []
def req(o, k, t, where):
    if k not in o: err.append(f"{where}: missing {k}")
    elif not isinstance(o[k], t): err.append(f"{where}: {k} wrong type")
HEX = re.compile(r"^#?[0-9A-Fa-f]{6}$")
req(s, "name", str, "source"); req(s, "apps", list, "source")
if "tintColor" in s and not HEX.match(s["tintColor"]): err.append("source: bad tintColor")
ids = set()
for i, a in enumerate(s.get("apps", [])):
    w = f"apps[{i}]"
    for k in ["name", "bundleIdentifier", "developerName", "localizedDescription", "iconURL"]: req(a, k, str, w)
    req(a, "versions", list, w); req(a, "appPermissions", dict, w)
    if a.get("bundleIdentifier") in ids: err.append(f"{w}: duplicate bundleIdentifier")
    ids.add(a.get("bundleIdentifier"))
    if a.get("category", "other") not in {"developer","entertainment","games","lifestyle","other","photo-video","social","utilities"}: err.append(f"{w}: bad category")
    p = a.get("appPermissions", {})
    if not isinstance(p.get("entitlements", []), list) or not isinstance(p.get("privacy", {}), dict): err.append(f"{w}: bad appPermissions")
    if not a.get("versions"): err.append(f"{w}: no versions")
    builds = []
    for j, v in enumerate(a.get("versions", [])):
        vw = f"{w}.versions[{j}]"
        for k in ["version", "date", "downloadURL"]: req(v, k, str, vw)
        req(v, "size", int, vw)
        if not str(v.get("downloadURL", "")).startswith("https://"): err.append(f"{vw}: downloadURL not https")
        try: datetime.datetime.fromisoformat(v["date"].replace("Z", "+00:00"))
        except Exception: err.append(f"{vw}: date not ISO 8601")
        builds.append(int(v.get("buildVersion", 0)))
    if builds != sorted(builds, reverse=True): err.append(f"{w}: versions not newest-first")
if err: print("INVALID\n" + "\n".join(err)); sys.exit(1)
print(f"VALID: {len(s['apps'])} app(s)")
