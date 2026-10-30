#!/usr/bin/env python3
"""Read `pkgcheck scan -R JsonStream` on stdin, drop everything listed in
.ci/pkgcheck-skip.txt and profile-dependent classes, print the rest, exit 1 if
anything is left.  Skip file lines: `category/package` (all errors of that
package; category/* allowed) or `category/package:Class`."""
import fnmatch, json, sys

skip = []
for l in open(sys.argv[1]):
    l = l.split("#")[0].strip()
    if l:
        skip.append(l)
# overlay ebuilds are ~arch and may need GURU/other overlays: unsatisfiable on
# the stable/dev/exp profiles pkgcheck checks is expected, not a bug
IGNORE_CLASSES = {"NonsolvableDepsInStable", "NonsolvableDepsInDev", "NonsolvableDepsInExp"}

bad = []
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    r = json.loads(line)
    cls = r.get("__class__", "?")
    if cls in IGNORE_CLASSES:
        continue
    pkg = f"{r.get('category', '')}/{r.get('package', '')}"
    if any(fnmatch.fnmatch(pkg, s.split(":")[0]) and (":" not in s or s.split(":")[1] == cls) for s in skip):
        continue
    bad.append(f"{pkg} {r.get('version', '')} {cls}: {r.get('msg', r.get('desc', ''))}")
print("\n".join(bad) or "pkgcheck: no errors (after skip list)")
sys.exit(1 if bad else 0)
