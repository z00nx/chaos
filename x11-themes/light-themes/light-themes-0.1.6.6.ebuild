# Copyright 1999-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/x11-themes/tango-icon-theme/tango-icon-theme-0.7.2.ebuild,v 1.3 2006/06/02 12:51:20 corsair Exp $

inherit eutils

DESCRIPTION="Light Themes"
HOMEPAGE="http://www.ubuntu.com/"
SRC_URI="http://archive.ubuntu.com/ubuntu/pool/main/${PN:0:1}/${PN}/${PN}_${PV}.tar.gz"

LICENSE="CCPL-Attribution-ShareAlike-2.5"
SLOT="0"
KEYWORDS="~amd64 ~ppc ppc64 ~sparc ~x86"

RDEPEND=">=x11-themes/gtk-engines-murrine-0.90.3
	x11-themes/ubuntu-mono
	x11-themes/humanity-icon-theme"

DEPEND="${RDEPEND}"

S="${WORKDIR}/${PN}-${PV}"

src_install() {
	dodir /usr/share/themes
	for THEME in Ambiance Radiance; do
		cp -R "${THEME}" "${D}/usr/share/themes/"
	done
}
