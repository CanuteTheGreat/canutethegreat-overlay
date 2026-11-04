# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Portage config to use ::steam-overlay and build the 32-bit Steam client (opt-in)"
HOMEPAGE="https://github.com/anyc/steam-overlay"
S=${WORKDIR}

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

# sync-type git needs git; nothing here pulls in games-util/steam-launcher:
# it lives in a repository that does not exist until this package is merged
# and the repository has been synced (see pkg_postinst).
RDEPEND="dev-vcs/git"

src_install() {
	insinto /etc/portage/repos.conf
	newins "${FILESDIR}"/steam-overlay.conf steam-overlay.conf
	insinto /etc/portage/package.use
	newins "${FILESDIR}"/steam.use steam
	insinto /etc/portage/package.accept_keywords
	newins "${FILESDIR}"/steam.accept_keywords steam
	insinto /etc/portage/package.license
	newins "${FILESDIR}"/steam.license steam
}

pkg_postinst() {
	elog "steam-overlay is registered and the abi_x86_32 USE settings for Steam are in"
	elog "/etc/portage/package.use/steam. Finish with:"
	elog "  emaint sync -r steam-overlay"
	elog "  emerge -av games-util/steam-launcher"
	elog
	elog "Requirements: a multilib profile (default/linux/amd64/23.0 is; the"
	elog "'no-multilib' profiles are not). With x11-drivers/nvidia-drivers the 32-bit"
	elog "driver libraries come from USE=abi_x86_32 on nvidia-drivers (set in the"
	elog "file above); a dist-kernel/kernel-open setup is unaffected."
	elog "If another repos.conf entry for steam-overlay exists (e.g. from"
	elog "'eselect repository enable steam-overlay'), remove one of the two."
	elog "Do NOT install this on machines that do not run Steam."
}
