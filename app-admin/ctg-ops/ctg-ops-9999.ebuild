# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit ctg-ops git-r3

DESCRIPTION="Errant/owner host ops tools (alert mail, ollivanders monitors, deploy watchers, ...)"
HOMEPAGE="https://git.canutethegreat.com/CanuteTheGreat/ctg-infrastructure"
# private repo: needs an ssh key (or a token in the URL) on the building machine
EGIT_REPO_URI="ssh://git@git.canutethegreat.com/CanuteTheGreat/ctg-infrastructure.git"
EGIT_BRANCH="main"

LICENSE="all-rights-reserved"
RESTRICT="mirror"
SLOT="0"
IUSE="alert-mail offhost-watch ollivanders-ops deploy-watchers ollivanders-ssh azkaban-host
	sudoers-crystalcave forgejo-host crystalcave-host pg-restore-drill wordpress-ops nextcloud-ops"
REQUIRED_USE="
	offhost-watch? ( alert-mail )
	ollivanders-ops? ( alert-mail )
	deploy-watchers? ( alert-mail )
"

RDEPEND="
	dev-lang/python
	app-admin/ctg-timerd
	ollivanders-ops? ( acct-group/ctg-alerts dev-db/postgresql sys-process/cronie )
	offhost-watch? ( virtual/openssh )
	deploy-watchers? ( virtual/openssh )
	ollivanders-ssh? ( net-misc/openssh net-analyzer/fail2ban )
	sudoers-crystalcave? ( app-admin/sudo )
	forgejo-host? ( net-misc/curl dev-db/postgresql sys-process/cronie )
	wordpress-ops? ( sys-process/cronie )
	nextcloud-ops? ( sys-process/cronie )
"
DEPEND="ollivanders-ops? ( acct-group/ctg-alerts )"
BDEPEND="dev-lang/python"
