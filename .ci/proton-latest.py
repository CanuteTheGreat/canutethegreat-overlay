#!/usr/bin/env python3
"""Newest official Linux release of a Proton app (nvchecker `cmd` source).

Usage: proton-latest.py pass|meet|authenticator|pass-cli|drive-cli
Reads Proton's own download metadata on proton.me/download (the same JSON the apps
and https://proton.me/<app>/download use); stdlib only. Exits 1 when nothing is found.
"""
import json
import re
import sys
import urllib.request

BASE = "https://proton.me/download/"


def get(path):
    req = urllib.request.Request(BASE + path, headers={"User-Agent": "proton-latest"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode()


def stable(path):
    # newest first; skip EarlyAccess/Alpha channels, require a full rollout
    for rel in json.loads(get(path))["Releases"]:
        if rel.get("CategoryName") == "Stable" and rel.get("RolloutPercentage", 1) >= 1:
            return rel["Version"]


def main():
    app = sys.argv[1]
    if app == "pass":
        v = stable("PassDesktop/linux/x64/version.json")
    elif app == "meet":
        v = stable("meet/linux/version.json")
    elif app == "authenticator":
        v = stable("authenticator/linux/version.json")
    elif app == "pass-cli":
        v = json.loads(get("pass-cli/versions.json"))["passCliVersions"]["version"]
    elif app == "drive-cli":
        m = re.search(r"Proton Drive CLI (\d+\.\d+\.\d+)", get("drive/cli/index.html"))
        v = m and m.group(1)
    else:
        sys.exit(f"unknown app {app}")
    if not v:
        sys.exit(1)
    print(v)


main()
