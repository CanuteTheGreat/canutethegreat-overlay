# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

DESCRIPTION="User for net-misc/ntfy-bin"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( ntfy )
ACCT_USER_HOME=/var/lib/ntfy
ACCT_USER_HOME_PERMS=0750

acct-user_add_deps
