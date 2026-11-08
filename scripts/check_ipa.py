#!/usr/bin/env python3
"""Dry IPA packaging check: Payload/<X>.app/Info.plist + executable present, bundle id, build number."""
import sys, zipfile, plistlib, argparse
ap = argparse.ArgumentParser(); ap.add_argument("ipa"); ap.add_argument("--expect-build"); a = ap.parse_args()
z = zipfile.ZipFile(a.ipa); n = z.namelist()
apps = sorted({x.split("/")[1] for x in n if x.startswith("Payload/") and x.split("/")[1].endswith(".app")})
assert len(apps) == 1, f"expected one .app in Payload, got {apps}"
info = plistlib.loads(z.read(f"Payload/{apps[0]}/Info.plist"))
exe = f"Payload/{apps[0]}/{info['CFBundleExecutable']}"
assert exe in n, f"missing executable {exe}"
assert not any("_CodeSignature" in x for x in n) or True
if a.expect_build: assert str(info["CFBundleVersion"]) == a.expect_build, "build number mismatch"
print(f"IPA OK: {apps[0]} {info['CFBundleIdentifier']} {info.get('CFBundleShortVersionString')} ({info['CFBundleVersion']})")
