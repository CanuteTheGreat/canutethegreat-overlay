#!/usr/bin/env python3
"""Newest Brave *release* that www-client/brave (source build) can actually be built from.

The source ebuild reuses ::gentoo's www-client/chromium inputs (same chromium-linux tarball
+ same chromium-patches set + same LLVM/Rust), so a Brave version is only bumpable when the
Chromium it pins (brave-core package.json / release title "Release vX (Chromium A.B.C.D)")
has an ebuild in ::gentoo. This prints the highest such Brave version (nvchecker `cmd` source),
or exits 1 when none is found. `www-client/brave-bin` tracks plain latest Brave instead.

Env: GITHUB_TOKEN (optional, rate limits). Stdlib only.
"""
import json
import os
import re
import sys
import urllib.request


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "brave-source-latest"})
    tok = os.environ.get("GITHUB_TOKEN")
    if tok:
        req.add_header("Authorization", f"Bearer {tok}")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def vkey(v):
    return tuple(int(x) for x in v.split("."))


def main():
    contents = get("https://api.github.com/repos/gentoo/gentoo/contents/www-client/chromium")
    gentoo = {m.group(1) for e in contents
              if (m := re.fullmatch(r"chromium-(\d+\.\d+\.\d+\.\d+)(?:-r\d+)?\.ebuild", e["name"]))}
    best = None
    for page in range(1, 6):
        for rel in get(f"https://api.github.com/repos/brave/brave-browser/releases?per_page=100&page={page}"):
            if rel.get("prerelease") or rel.get("draft"):
                continue
            m = re.match(r"Release v(\d+\.\d+\.\d+) \(Chromium (\d+\.\d+\.\d+\.\d+)\)", rel.get("name") or "")
            if m and m.group(2) in gentoo and (best is None or vkey(m.group(1)) > vkey(best)):
                best = m.group(1)
        if best:  # releases are newest first and versions are monotonic: first hit page is enough
            break
    if not best:
        print("no Brave release matches a Chromium version in ::gentoo", file=sys.stderr)
        return 1
    print(best)
    return 0


if __name__ == "__main__":
    sys.exit(main())
