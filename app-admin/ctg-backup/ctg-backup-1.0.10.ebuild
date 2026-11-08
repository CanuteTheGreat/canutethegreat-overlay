# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit ctg-backup

SRC_URI="https://git.canutethegreat.com/api/packages/CanuteTheGreat/generic/ctg-backup/${PV}/ctg-backup-${PV}.tar.gz"
S="${WORKDIR}/ctg-backup-${PV}"
KEYWORDS="~amd64 ~arm64"
DESCRIPTION="CanuteTheGreat/Errant encrypted restic backup kit (ctg-restic, B2, timers) and host configs"
HOMEPAGE="https://git.canutethegreat.com/CanuteTheGreat/ctg-infrastructure"
LICENSE="all-rights-reserved"
RESTRICT="mirror"
SLOT="0"
IUSE="admin tm laptop cloud-copy pve guest unit-failure-mail agent-ssh plex-guard host-crystalcave host-ollivanders host-captainjack host-gringotts"
REQUIRED_USE="
	pve? ( unit-failure-mail )
	guest? ( unit-failure-mail )
	?? ( host-crystalcave host-ollivanders host-captainjack host-gringotts )
"

RDEPEND="
	>=app-backup/restic-0.14
	app-admin/ctg-timerd
	dev-lang/python
	net-misc/curl
	cloud-copy? ( >=net-misc/rclone-1.70 sys-fs/fuse:3 )
	unit-failure-mail? ( virtual/mailx )
	agent-ssh? ( virtual/openssh )
"
BDEPEND="dev-lang/python"
