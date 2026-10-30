#!/bin/sh
# Run `pkgcheck scan -k error` for this overlay in a throw-away Gentoo stage3
# container (run on an rw-man host; never on crystalcave/ollivanders).
set -eu
cd "$(dirname "$0")/.."
name="pkgcheck-$$-$(date +%s)"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT
docker run --rm --name "$name" --memory=6g --cpus=4 -v "$PWD:/src:ro" gentoo/stage3:amd64-openrc sh -euc '
  emerge-webrsync -q >/dev/null
  getuto >/dev/null 2>&1
  echo "FEATURES=\"getbinpkg binpkg-request-signature\"" >> /etc/portage/make.conf
  emerge -q --getbinpkg dev-util/pkgcheck dev-vcs/git >/dev/null
  cp -a /src /work && cd /work
  git config --global --add safe.directory "*"
  repo=$(sed -n "s/^repo-name *= *//p" metadata/layout.conf)
  mkdir -p /etc/portage/repos.conf
  cp /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf
  printf "[%s]\nlocation = /work\n" "$repo" > /etc/portage/repos.conf/overlay.conf
  pkgcheck scan --repo "$repo" -k error -R JsonStream | python3 .ci/pkgcheck-filter.py .ci/pkgcheck-skip.txt
'
