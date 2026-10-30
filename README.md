# canutethegreat-overlay

Personal Gentoo ebuilds of Ronald Farrer (CanuteTheGreat), used on his Horcrux (Gentoo) machines.
Source of truth: `https://git.canutethegreat.com/CanuteTheGreat/canutethegreat-overlay` (Forgejo);
`https://github.com/CanuteTheGreat/canutethegreat-overlay` is a push mirror. Please report outdated or broken ebuilds as an issue.

Rules: EAPI 8, thin Manifests, only the **newest release** of a package (plus an optional live `-9999`) is kept, binary
packages carry `RESTRICT="bindist mirror"` and an honest `LICENSE`. Everything is `~amd64` (arch testing).

## Use

    eselect repository add canutethegreat-overlay git https://github.com/CanuteTheGreat/canutethegreat-overlay.git
    emaint sync -r canutethegreat-overlay
    echo 'www-client/brave-bin ~amd64' >> /etc/portage/package.accept_keywords/brave
    emerge -av www-client/brave-bin

## Packages

| Package | Version | Notes |
|---|---|---|
| `www-client/brave-bin` | 1.98.62 | upstream .deb, amd64/arm64; sandbox needs USER_NS/PID_NS/NET_NS/SECCOMP in the kernel |
| `app-misc/alienfx` | 2.4.3, 9999 | Alienware lighting; 9999 (git master, python >= 3.14) carries the `187c:0551` udev rule |
| `app-containers/waydroid` | 1.6.3 | needs `dev-python/gbinder`, `dev-libs/libgbinder`, `dev-python/pyclip` from GURU (same package also in GURU) |
| `app-forensics/libewf` | 20260924 | libewf-experimental |
| `app-office/insync` | 3.9.11.60043 | proprietary |
| `games-util/geforcenow-electron` | 3.0.6 | |
| `net-misc/freedownloadmanager` | 6.35.2.7075 | upstream only publishes an unversioned "latest" .deb: the Manifest breaks when FDM updates |
| `net-fs/goofys-bin` | 0.24.0 | upstream binary; `net-fs/goofys` (source) does not build any more |
| `net-proxy/zaproxy` | 2.17.0 | |
| `app-mobilephone/easytether` | 0.8.9 | proprietary |
| `app-office/overgrive`, `net-ftp/filezillapro` | 3.5.4, 3.55.1 | `RESTRICT=fetch`: download the vendor file into DISTDIR yourself |
| `net-misc/nomachine`, `net-misc/nxplayer` | 9.3.7.1, 8.16.1.1 | vendor URLs currently serve the NoMachine homepage instead of the tarball: not installable until fixed |
| `cross-x86_64-unknown-linux-musl/*` | | crossdev-generated copy of ::gentoo toolchain ebuilds (newest per supported slot kept) |

Proposed for removal (see the maintainer's report / open issues): `sys-kernel/dkms` (::gentoo has it),
`www-client/brave-browser` (source build, does not source), `net-fs/goofys`, `net-misc/nxplayer` (part of nomachine),
`app-containers/waydroid` (GURU), and the `cross-*` tree (regenerate with crossdev instead).

## CI

* `.forgejo/workflows/update-check.yml` (weekly, Monday 06:17 UTC): `nvchecker` (`.nvchecker/nvchecker.toml`) compares
  upstream with the newest ebuild and opens one issue per new version.
* `.forgejo/workflows/pkgcheck.yml` (push/PR): `pkgcheck scan -k error` in a Gentoo stage3 container on the rw-man runners;
  accepted exceptions are in `.ci/pkgcheck-skip.txt`.
