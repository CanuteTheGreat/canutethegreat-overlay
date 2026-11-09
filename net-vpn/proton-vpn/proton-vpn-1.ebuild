# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Proton VPN for the GNOME desktop (app + CLI + daemon + keyring)"
HOMEPAGE="https://protonvpn.com/"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	net-vpn/proton-vpn-gtk-app
	net-vpn/proton-vpn-cli
	net-vpn/proton-vpn-daemon
	dev-python/proton-keyring-linux
	gnome-base/gnome-keyring
"
