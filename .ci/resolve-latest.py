#!/usr/bin/env python3
"""Newest DaVinci Resolve (free) release with a Linux build, from Blackmagic's
public downloads index (no registration needed for the index itself).
Prints e.g. 21.1.2 (nvchecker `cmd` source)."""
import json, urllib.request

req = urllib.request.Request(
    "https://www.blackmagicdesign.com/api/support/us/downloads.json",
    headers={"User-Agent": "Mozilla/5.0"})
data = json.load(urllib.request.urlopen(req, timeout=60))["downloads"]
best = None
for d in data:
    for l in d.get("urls", {}).get("Linux", []):
        if l.get("product") == "davinci-resolve" and l.get("beta") == 255:
            v = (l["major"], l["minor"], l["releaseNum"])
            if best is None or v > best:
                best = v
print(".".join(map(str, best)))
