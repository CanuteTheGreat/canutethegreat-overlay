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
| `app-misc/alienfx` | 2.4.3, 9999 | Alienware lighting; 9999 (git master, python >= 3.14) carries the `187c:0551` rule. The udev rules use `TAG+="uaccess"` (logged-in seat user, needs systemd-logind/elogind) instead of upstream's world-writable `MODE 666`; the sysfs `chmod 666` rule for the Alpha ASM100 is dropped |
| `app-forensics/libewf` | 20260924 | libewf-experimental |
| `games-util/geforcenow-electron` | 3.0.6 | |
| `net-misc/freedownloadmanager` | 6.35.2.7075 | upstream only publishes an unversioned "latest" .deb: the Manifest breaks when FDM updates |
| `net-fs/goofys-bin` | 0.24.0 | upstream binary (no source package any more) |
| `net-proxy/zaproxy` | 2.17.0 | |

Removed (replaced by ::gentoo/GURU or another package, or no longer maintained here): `sys-kernel/dkms` (::gentoo),
`app-containers/waydroid` (GURU carries 1.6.3: `eselect repository enable guru`), `www-client/brave-browser`
(use `brave-bin`), `net-fs/goofys` (use `goofys-bin`), `net-misc/nxplayer`, `net-misc/nomachine`, `app-office/overgrive`,
`net-ftp/filezillapro`, `app-office/insync`, `app-mobilephone/easytether`.

## CI

* `.forgejo/workflows/update-check.yml` (daily, 06:17 UTC): `nvchecker` (`.nvchecker/nvchecker.toml`) compares
  upstream with the newest ebuild and opens one issue per new version.
* `.forgejo/workflows/pkgcheck.yml` (push/PR): `pkgcheck scan -k error` in a Gentoo stage3 container on the rw-man runners;
  accepted exceptions are in `.ci/pkgcheck-skip.txt`.

## Cross toolchains
Not kept here. `crossdev` writes generated `cross-*` ebuilds into the highest-priority overlay when no dedicated crossdev repo exists; that is how a musl toolchain ended up in this overlay (removed 2026-10-29). Create one locally with a dedicated repo instead: `eselect repository create crossdev && crossdev --target x86_64-unknown-linux-musl`.
