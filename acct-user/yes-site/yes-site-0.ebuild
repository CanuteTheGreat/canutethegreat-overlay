# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

DESCRIPTION="User for the YES site (same as the .deb's system user)"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( yes-site )
ACCT_USER_HOME=/var/lib/yes-site
ACCT_USER_HOME_OWNER=yes-site:yes-site
ACCT_USER_HOME_PERMS=0750

acct-user_add_deps
