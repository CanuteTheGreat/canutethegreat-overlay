#!/bin/sh
# Make the Go vendor tarball for an ebuild: make-go-vendor.sh <src-tarball-or-dir-with-go.mod> <out-name> [top-dir-in-tarball]
# e.g. .ci/make-go-vendor.sh mc-RELEASE.2025-08-13T08-35-41Z minio-client-2025.08.13-vendor.tar.xz
# The tarball holds <top>/vendor so it unpacks next to the source into ${S}. Upload it as an asset of the "distfiles" release
# (git.canutethegreat.com/CanuteTheGreat/canutethegreat-overlay/releases/tag/distfiles) and reference it in SRC_URI.
set -eu
src=${1:?source dir}; out=${2:?output tarball}; top=${3:-$(basename "$src")}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
( cd "$src" && GOMODCACHE="$tmp/mod" GOFLAGS=-modcacherw go mod vendor )
mkdir -p "$tmp/t/$top"; cp -a "$src/vendor" "$tmp/t/$top/"
( cd "$tmp/t" && XZ_OPT='-T0 -9' tar -acf "$OLDPWD/$out" "$top" )
ls -la "$out"
