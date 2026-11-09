# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

DESCRIPTION="User for net-dns/technitium-dns-bin"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( dns-server )
ACCT_USER_HOME=/etc/dns
ACCT_USER_HOME_PERMS=0700

acct-user_add_deps
