# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )
inherit distutils-r1 pypi

DESCRIPTION="Python client for Sentry (required by the Proton VPN API core)"
HOMEPAGE="https://github.com/getsentry/sentry-python https://pypi.org/project/sentry-sdk/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
# the upstream test-suite needs a dozen optional integrations
RESTRICT="test"

RDEPEND="
	dev-python/certifi[${PYTHON_USEDEP}]
	>=dev-python/urllib3-1.26.11[${PYTHON_USEDEP}]
"
