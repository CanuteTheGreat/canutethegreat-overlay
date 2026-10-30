#!/usr/bin/env bash
# make-brave-distfiles.sh VERSION [OUTDIR]
#
# Turns Brave's network-based "npm run init / gclient sync" into plain, reproducible
# distfiles for the www-client/brave ebuild (Portage forbids network in src_*).
#
# For Brave release VERSION (e.g. 1.93.137) it writes into OUTDIR (default ./out-VERSION):
#
#   brave-core-VERSION.tar.xz   `git archive` of github.com/brave/brave-core at tag vVERSION
#                               (prefix brave-core-VERSION/). Unpacked to ${S}/brave by the ebuild.
#   brave-deps-VERSION.tar.xz   everything else Brave's sync step pulls, laid out relative to
#                               brave-core's root (prefix brave-deps-VERSION/):
#                                 <path>/...            each pinned git dep from brave-core/DEPS
#                                                       (linux-relevant ones only, .git removed,
#                                                       a stub .git/HEAD kept where GN lists it as input)
#                                 node_modules/         `npm ci` of brave-core/package-lock.json (incl. the
#                                                       @brave/leo `prepare` build output)
#                                 vendor/web-discovery-project/node_modules/
#                                 DEPS-RESOLVED.json    path/url/sha of every dep that went in
#   SHA256SUMS, distfiles.json  checksums + the Chromium version Brave pins (for SRC_URI)
#
# The Chromium tarball is NOT regenerated: the ebuild uses the same
# chromium-${CHROMIUM}-linux.tar.xz from chromium-linux-tarballs that ::gentoo's
# www-client/chromium uses (the pinned version is printed and stored in distfiles.json).
#
# Requirements: bash, git, curl, python3, xz, GNU tar, node >= engines.node of brave-core
# (24.x) with npm, x86_64 Linux (node_modules carry native optional deps; the ebuild is amd64 only).
# Network is required here (and only here). Output is deterministic as far as the upstream
# inputs are: fixed mtime (tag commit time), sorted names, numeric owner, single-threaded xz.
set -euo pipefail

VER=${1:?usage: $0 VERSION [OUTDIR]}
OUT=$(realpath -m "${2:-./out-$VER}")
WORK=${BRAVE_DISTFILES_WORK:-$(mktemp -d "${TMPDIR:-/var/tmp}/brave-distfiles.XXXXXX")}
KEEP_WORK=${KEEP_WORK:-0}
TAG=v$VER
CORE_REPO=${CORE_REPO:-https://github.com/brave/brave-core.git}

for t in git curl python3 xz tar node npm; do
	command -v "$t" >/dev/null || { echo "missing tool: $t" >&2; exit 1; }
done
[[ $(uname -m) == x86_64 ]] || { echo "run on x86_64 (native node_modules)" >&2; exit 1; }

mkdir -p "$OUT" "$WORK"
cleanup() { [[ $KEEP_WORK == 1 ]] || rm -rf "$WORK"; }
trap cleanup EXIT

tarx() { # tarx OUTFILE PREFIX SRCDIR MTIME
	local outf=$1 prefix=$2 src=$3 mtime=$4
	tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$mtime" \
		--transform "s,^\.,$prefix," -C "$src" -cf - . | xz -T1 -9e >"$outf"
}

echo "== brave-core $TAG"
git -c advice.detachedHead=false clone -q --depth 1 --branch "$TAG" "$CORE_REPO" "$WORK/core"
COMMIT=$(git -C "$WORK/core" rev-parse HEAD)
MTIME=$(git -C "$WORK/core" log -1 --format=%ct)
CHROMIUM=$(python3 - "$WORK/core/package.json" <<'EOF'
import json, sys
print(json.load(open(sys.argv[1]))["config"]["projects"]["chrome"]["tag"])
EOF
)
echo "   commit $COMMIT, pins Chromium $CHROMIUM"
if [[ ${SKIP_CORE_ARCHIVE:-0} == 1 && -s $OUT/brave-core-$VER.tar.xz ]]; then
	echo "   reusing existing $OUT/brave-core-$VER.tar.xz"
else
	git -C "$WORK/core" archive --format=tar --prefix="brave-core-$VER/" HEAD |
		xz -T1 -9e >"$OUT/brave-core-$VER.tar.xz"
fi

echo "== DEPS (linux-relevant git deps)"
DEPSDIR="$WORK/deps/brave-deps-$VER"
mkdir -p "$DEPSDIR"
python3 - "$WORK/core/DEPS" "$DEPSDIR" <<'EOF'
import json, os, shutil, subprocess, sys

deps_file, dest = sys.argv[1:3]

# gclient evaluates `condition` strings with these names; we are linux/x64, no mac/win/android/ios.
env = dict(checkout_linux=True, checkout_win=False, checkout_mac=False, checkout_ios=False,
           checkout_android=False, checkout_dmg_tool=False, host_os="linux", host_cpu="x64",
           download_prebuilt_sparkle=False)
ns = {"Var": lambda n: env.get(n)}
exec(open(deps_file).read(), ns)

# Not needed for a Linux build: reclient configs are only used by Brave's remote-exec CI.
SKIP = {"third_party/reclient_configs/src"}

resolved = []
for path, spec in sorted(ns["deps"].items()):
    cond = None
    if isinstance(spec, dict):
        url, cond = spec["url"], spec.get("condition")
    else:
        url = spec
    if cond and not eval(cond, {}, dict(env)):
        continue
    if path in SKIP:
        continue
    repo, sha = url.rsplit("@", 1)
    target = os.path.join(dest, path)
    os.makedirs(target, exist_ok=True)
    print(f"   {path}  {repo}@{sha[:12]}", flush=True)
    run = lambda *a: subprocess.run(["git", "-C", target, *a], check=True,
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run("init", "-q")
    run("fetch", "-q", "--depth", "1", repo, sha)
    run("checkout", "-q", "FETCH_HEAD")
    # Drop the history, keep a stub .git/HEAD: GN lists //brave/vendor/web-discovery-project/.git/HEAD
    # as an action input (and the real checkout would carry it).
    shutil.rmtree(os.path.join(target, ".git"))
    os.makedirs(os.path.join(target, ".git"))
    with open(os.path.join(target, ".git", "HEAD"), "w") as f:
        f.write(sha + "\n")
    resolved.append({"path": path, "url": repo, "sha": sha})
with open(os.path.join(dest, "DEPS-RESOLVED.json"), "w") as f:
    json.dump(resolved, f, indent=1, sort_keys=True)
EOF

# Lifecycle scripts must run: git dependencies such as @brave/leo generate files the build needs
# (tokens/skia/*.h, icons) in their `prepare` script.
echo "== npm: brave-core node_modules (npm ci)"
( cd "$WORK/core" && npm ci --no-audit --no-fund --loglevel=error )
[[ -f $WORK/core/node_modules/@brave/leo/tokens/skia/nala_color_id.h ]] ||
	{ echo "@brave/leo build output missing" >&2; exit 1; }
mv "$WORK/core/node_modules" "$DEPSDIR/node_modules"

echo "== npm: vendor/web-discovery-project node_modules"
( cd "$DEPSDIR/vendor/web-discovery-project" &&
	npm install --no-save --yes --no-audit --no-fund --loglevel=error )

echo "== packing brave-deps-$VER.tar.xz"
tarx "$OUT/brave-deps-$VER.tar.xz" "brave-deps-$VER" "$DEPSDIR" "$MTIME"

( cd "$OUT" && sha256sum brave-core-"$VER".tar.xz brave-deps-"$VER".tar.xz >SHA256SUMS )
python3 - "$OUT" "$VER" "$COMMIT" "$CHROMIUM" <<'EOF'
import json, os, sys
out, ver, commit, chromium = sys.argv[1:5]
json.dump({"brave": ver, "brave_core_commit": commit, "chromium": chromium,
           "files": {f: os.path.getsize(os.path.join(out, f))
                     for f in sorted(os.listdir(out)) if f.endswith(".tar.xz")}},
          open(os.path.join(out, "distfiles.json"), "w"), indent=1)
EOF
echo "== done"
cat "$OUT/SHA256SUMS" "$OUT/distfiles.json"
