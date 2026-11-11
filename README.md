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
| `www-client/brave-bin` | 1.99.55 | upstream .deb, amd64/arm64; sandbox needs USER_NS/PID_NS/NET_NS/SECCOMP in the kernel |
| `app-misc/alienfx` | 2.4.3, 9999 | Alienware lighting; 9999 (git master, python >= 3.14) carries the `187c:0551` rule. The udev rules use `TAG+="uaccess"` (logged-in seat user, needs systemd-logind/elogind) instead of upstream's world-writable `MODE 666`; the sysfs `chmod 666` rule for the Alpha ASM100 is dropped |
| `app-forensics/libewf` | 20260924 | libewf-experimental |
| `games-util/geforcenow-electron` | 3.1.0 | |
| `net-misc/freedownloadmanager` | 6.35.2.7075 | upstream only publishes an unversioned "latest" .deb: the Manifest breaks when FDM updates |
| `media-video/davinci-resolve`, `media-video/davinci-resolve-studio` | 21.2.0 | **fetch-restricted**, you download the archive by hand (see below); free / Studio edition, block each other; eclass `davinci-resolve` |
| `net-fs/goofys-bin` | 0.24.0 | upstream binary (no source package any more) |
| `net-proxy/zaproxy` | 2.17.0 | |
| `app-admin/proton-pass-bin` | 1.43.0 | Proton Pass desktop (Electron), upstream .deb, amd64 only; wrapper reads `~/.config/proton-pass-flags.conf` |
| `app-admin/proton-pass-cli-bin` | 2.7.0 | Proton Pass CLI, official prebuilt binary (amd64/arm64) |
| `net-im/proton-meet-bin` | 1.0.14 | Proton Meet desktop (Electron), upstream .deb, amd64 only |
| `sys-auth/proton-authenticator-bin` | 1.1.6 | Proton Authenticator (Tauri), upstream .deb, amd64 only |
| `net-fs/proton-drive-cli-bin` | 0.9.0 | Proton Drive CLI, official prebuilt binary (amd64/arm64) |
| `mail-client/proton-mail-export-bin` | 1.0.7 | Proton Mail Export Tool CLI (amd64) |
| `net-analyzer/caido-bin`, `net-analyzer/caido-cli-bin` | 0.59.0 | Caido web-security proxy, upstream binaries |
| `net-analyzer/metasploit-bin` | 6.5.10_p20261106055829 | Rapid7 omnibus build under `/opt/metasploit-framework`, self-updater disabled |
| `app-misc/qflipper` | 1.3.3 | Flipper Zero desktop app (source build) |
| `dev-embedded/pineflash` | 0.5.5 | Pine64 flasher |
| `dev-db/pgbackrest` | 2.60.0-r1 | |
| `net-misc/ntfy-bin` | 2.37.2 | ntfy server/client, upstream binary |
| `net-fs/minio-client` | 2025.08.13 | `mc`, vendored Go modules |
| `www-apps/wp-cli` | 2.12.0 | |
| `net-misc/xrdp`, `net-misc/xorgxrdp` | 0.10.6.1-r1, 0.10.5-r2 | newer than ::gentoo |
| `net-vpn/proton-vpn`, `proton-vpn-cli`, `proton-vpn-daemon`, `proton-vpn-gtk-app` (+ `dev-python/proton-*`) | see tree | Proton VPN client stack; newer than GURU |

Removed (replaced by ::gentoo/GURU or another package, or no longer maintained here): `sys-kernel/dkms` (::gentoo),
`app-containers/waydroid` (GURU carries 1.6.3: `eselect repository enable guru`), `www-client/brave-browser`
(use `brave-bin`), `net-fs/goofys` (use `goofys-bin`), `net-misc/nxplayer`, `net-misc/nomachine`, `app-office/overgrive`,
`net-ftp/filezillapro`, `app-office/insync`, `app-mobilephone/easytether`.

## DaVinci Resolve (`media-video/davinci-resolve`, `media-video/davinci-resolve-studio`)
Proprietary, `RESTRICT=fetch`: Blackmagic only gives the archive out after a registration form (name, e-mail, ...), so there is
no scripted download and no Manifest in this overlay (thin Manifests, and a placeholder DIST would be a lie). Once per version:

1. Open <https://www.blackmagicdesign.com/support/family/davinci-resolve-and-fusion>, choose **DaVinci Resolve** (free) or
   **DaVinci Resolve Studio**, version = the ebuild version (`21.2.0`), platform **Linux**, fill in the form.
2. Put the download into DISTDIR (`portageq distdir`, normally `/var/cache/distfiles`) under exactly this name:
   `DaVinci_Resolve_21.2.0_Linux.zip` (free) or `DaVinci_Resolve_Studio_21.2.0_Linux.zip` (Studio).
3. `ebuild "$(portageq get_repo_path / canutethegreat-overlay)"/media-video/davinci-resolve/davinci-resolve-21.2.0.ebuild manifest`
   (same with `davinci-resolve-studio`), then `emerge -av media-video/davinci-resolve` (`ACCEPT_LICENSE` must allow
   `all-rights-reserved`: `echo 'media-video/davinci-resolve* all-rights-reserved' >> /etc/portage/package.license/resolve`).
4. `gpasswd -a $USER video`, log in again (licence/log/cache dirs below `/opt/davinci-resolve` are `root:video` 0775).
   Studio: activate with the dongle, Blackmagic Cloud licence or activation code.

GPU: `VIDEO_CARDS` decides the compute stack (`nvidia` -> `x11-drivers/nvidia-drivers` for CUDA+OpenCL, `amdgpu` -> ROCm OpenCL,
`intel` -> intel-compute-runtime); at least one is required. RTX 50xx (Blackwell) needs the open kernel modules. The package is
`strip`/`QA_PREBUILT` (bundled Qt/ffmpeg), RPATHs with Blackmagic's build paths are rewritten, the bundled glib is dropped for the
system one, the upstream world-writable (`MODE 0666`) udev rules become `TAG+="uaccess"`.
Third-party packagings checked: gentoo-zh `media-video/davinci-resolve`, bentoo, vowstar; none is in ::gentoo or GURU.
Tested without the real archive: the install logic was exercised against a *mock* archive with the same layout in a stage3
(rpath rewrite, desktop Exec targets exist, icons/mime/udev installed, `udevadm verify`, USE=nvidia/amdgpu variants);
the first run against Blackmagic's real archive may still need a path fix. nvchecker follows `.ci/resolve-latest.py`
(Blackmagic's public downloads index).

## Owner-specific packages
Host glue and the owner's own products (ctg-ops, ctg-timerd, ctg-backup, yes-site, rustinion-agent, the Steam config for one workstation, ...) live in a separate private overlay, not here.

## CI

* `.forgejo/workflows/update-check.yml` (daily, 06:17 UTC): `nvchecker` (`.nvchecker/nvchecker.toml`) compares
  upstream with the newest ebuild and opens one issue per new version.
* `.forgejo/workflows/pkgcheck.yml` (push/PR): `pkgcheck scan -k error` in a Gentoo stage3 container on the rw-man runners;
  accepted exceptions are in `.ci/pkgcheck-skip.txt`.

## Cross toolchains
Not kept here. `crossdev` writes generated `cross-*` ebuilds into the highest-priority overlay when no dedicated crossdev repo exists; that is how a musl toolchain ended up in this overlay (removed 2026-10-29). Create one locally with a dedicated repo instead: `eselect repository create crossdev && crossdev --target x86_64-unknown-linux-musl`.

## Proton apps
Official Linux builds only. Not duplicated here because ::gentoo/GURU already carry them: `mail-mta/proton-mail-bridge`
(::gentoo, source build), `net-vpn/proton-vpn-gtk-app` (GURU, with its `dev-python/proton-*` deps) and
`mail-client/proton-mail-bin` (GURU, desktop Mail+Calendar; often behind upstream). No official Linux desktop app exists for
Proton Drive (CLI only), Wallet (mobile/web), Docs, Sheets or Calendar (Calendar is inside the Mail desktop app).
Versions are tracked by `.ci/proton-latest.py` (reads proton.me/download metadata) in `.nvchecker/nvchecker.toml`.
