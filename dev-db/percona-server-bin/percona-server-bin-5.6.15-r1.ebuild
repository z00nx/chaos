# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=2

inherit eutils systemd versionator

use x86 && M_ARCH="i686"
use amd64 && M_ARCH="x86_64"
MAJOR_MINOR=$(get_version_component_range 1-2)

BASE_URI="http://www.percona.com/redir/downloads"

#regular server builds
R_MY_PKG="Percona-Server"
R_RELEASE="63.0"
R_BUILD_NUMBER="519"
#R_RB_SEPARATOR="."

#cluster server builds
C_MY_PKG="Percona-XtraDB-Cluster"
C_RELEASE="25.4"
C_BUILD_NUMBER="731"
#C_RB_SEPARATOR="-"

#https://bugs.launchpad.net/percona-xtradb-cluster/+bug/999495
#for the silly 5 after release
C_X86_URI="${BASE_URI}/${C_MY_PKG}-56/release-${PV}-${C_RELEASE}/binary/linux/i686/${C_MY_PKG}-${PV}-${C_RELEASE}.${C_BUILD_NUMBER}.Linux.i686.tar.gz"
C_X86_64_URI="${BASE_URI}/${C_MY_PKG}-56/release-${PV}-${C_RELEASE}/binary/linux/x86_64/${C_MY_PKG}-${PV}-${C_RELEASE}.${C_BUILD_NUMBER}.Linux.x86_64.tar.gz"

R_X86_URI="${BASE_URI}/${R_MY_PKG}-${MAJOR_MINOR}/${R_MY_PKG}-${PV}-rel${R_RELEASE}/binary/linux/i686/${R_MY_PKG}-${PV}-rel${R_RELEASE}-${R_BUILD_NUMBER}.Linux.i686.tar.gz"
R_X86_64_URI="${BASE_URI}/${R_MY_PKG}-${MAJOR_MINOR}/${R_MY_PKG}-${PV}-rel${R_RELEASE}/binary/linux/x86_64/${R_MY_PKG}-${PV}-rel${R_RELEASE}-${R_BUILD_NUMBER}.Linux.x86_64.tar.gz"

SERVICE="percona"

SRC_URI="x86? ( !cluster? ( ${R_X86_URI} ) 
				 cluster? ( ${C_X86_URI} ) )
		 amd64? ( !cluster? ( ${R_X86_64_URI} )
		 		   cluster? ( ${C_X86_64_URI} ) )"

DESCRIPTION="A fast, multi-threaded, multi-user SQL database server."
HOMEPAGE="http://www.percona.com/"
LICENSE="GPL-2"
KEYWORDS="~amd64 ~x86"
RESTRICT="mirror"
SLOT="0"
IUSE="cluster"

# Be warned, *DEPEND are version-dependant
# These are used for both runtime and compiletime
DEPEND="userland_GNU? ( sys-process/procps )
		cluster? ( >=dev-db/xtrabackup-bin-2.1.4
					net-misc/socat
					sys-apps/iproute2
					sys-apps/pv
					net-analyzer/openbsd-netcat
					sys-apps/xinetd )
		>=dev-libs/openssl-1.0.1f
        >=sys-apps/sed-4
        >=sys-apps/texinfo-4.7-r1
        >=sys-libs/readline-4.1
        >=sys-libs/zlib-1.2.3
		dev-libs/libaio
		sys-libs/ncurses[tinfo]"

RDEPEND="${DEPEND}
		virtual/mysql"

if use cluster;then
	#Percona-XtraDB-Cluster-5.5.23-23..333.Linux.x86_64
	S="${C_MY_PKG}-${PV}-${C_RELEASE}.${C_BUILD_NUMBER}.Linux.${M_ARCH}"
else
	S="${R_MY_PKG}-${PV}-rel${R_RELEASE}-${R_BUILD_NUMBER}.Linux.${M_ARCH}"
fi

src_prepare() {
	rm -rf "${S}/mysql-test"
	rm -rf "${S}/sql-bench"
	if use cluster;then
		# they use flags that do not work with netcat/netcat6
		# nc -dl
		sed -i \
			-e "s|which nc|which nc.openbsd|" \
			"${S}"/bin/wsrep_sst_xtrabackup || die "failed to filter wsrep_sst_xtrabackup"
		
		sed -i \
			-e "s|tcmd=\"nc|tcmd=\"nc.openbsd|" \
			"${S}"/bin/wsrep_sst_xtrabackup || die "failed to filter wsrep_sst_xtrabackup"
		
		# they use flags that do not work with netcat/netcat6
		# nc -dl
		sed -i \
			-e "s|which nc|which nc.openbsd|" \
			"${S}"/bin/wsrep_sst_xtrabackup-v2 || die "failed to filter wsrep_sst_xtrabackup-v2"
		
		sed -i \
			-e "s|tcmd=\"nc|tcmd=\"nc.openbsd|" \
			"${S}"/bin/wsrep_sst_xtrabackup-v2 || die "failed to filter wsrep_sst_xtrabackup-v2"
		
		sed -i \
			-e "s|/usr/bin/clustercheck|/opt/percona/bin/clustercheck|" \
			"${S}"/xinetd.d/mysqlchk || die "failed to filter mysqlchk"
	fi
}

src_install() {
	keepdir /var/lib/${SERVICE}
	keepdir /var/log/${SERVICE}
	keepdir /var/run/${SERVICE}

	dodir "/etc/${SERVICE}/"
	cp -R "${S}/support-files/"*.cnf "${D}/etc/${SERVICE}"
	cp -a "${S}/support-files/wsrep_notify" "${D}/etc/${SERVICE}"
	cp "${FILESDIR}/my.cnf.sample" "${D}/etc/${SERVICE}/"
	rm -rf "${S}/support-files"
	mv "${S}/scripts/mysql_install_db" "${S}/bin"
	dodir "/opt/${SERVICE}"
	cp -R "${S}"/* "${D}/opt/${SERVICE}"

	chown -R mysql:mysql "${D}/var/lib/${SERVICE}"
	chown -R mysql:mysql "${D}/var/log/${SERVICE}"
	chown -R mysql:mysql "${D}/var/run/${SERVICE}"

	#Init scripts
	newconfd "${FILESDIR}/${PN}.conf" "percona"
	newinitd "${FILESDIR}/${PN}.init" "percona"
	dodir /etc/profile.d
	insinto /etc/profile.d
	doins "${FILESDIR}"/percona-bin-path.sh

	#NASTY HACK
	#https://bugs.launchpad.net/percona-xtradb-cluster/+bug/999492
	#ncurses now had tinfo use flag
	#dosym /lib/libncurses.so.5 /lib/libtinfo.so.5

	#NASTY HACK
	dosym /usr/$(get_libdir)/libssl.so /usr/$(get_libdir)/libssl.so.6
	dosym /usr/$(get_libdir)/libcrypto.so /usr/$(get_libdir)/libcrypto.so.6

	use cluster && {
		insinto /etc/xinetd.d/
		doins "${S}"/xinetd.d/mysqlchk
	}

	cp "${FILESDIR}/mysqld-post.sh" "${D}/opt/${SERVICE}/bin/mysqld-post"
	chmod +x "${D}/opt/${SERVICE}/bin/mysqld-post"

	systemd_newtmpfilesd "${FILESDIR}"/${PN}.tmpfile ${SERVICE}.conf || die
	systemd_newunit "${FILESDIR}"/${PN}.service ${SERVICE}.service || die
}

pkg_postinst() {
	einfo "You may wish to run emerge --config ${PN} at this time"
	einfo "to install the initial db"
	einfo ""
	einfo "Also note that the .sock is not in the normal"
	einfo "/var/run/mysql/mysqld.sock location so your applications may need to"
	einfo "be updated to use /var/run/percona/mysqld.sock"
	einfo "you may also create /etc/my.cnf and include"
	einfo ""
	einfo "[client]
socket = /var/run/percona/mysqld.sock
..."
	einfo ""
	einfo "an sh file has been installed to /etc/profile.d/percona-bin-path.sh"
	einfo "making the percona binary path takes precedence over standard mysql"
	einfo "if this is not desired simply comment the line out in the file"
	einfo ""
	einfo "you could also place the same logic into your .bashrc"
	einfo "please run 'soure /etc/profile' to reload your current shell"

	ewarn "You *must* copy /etc/percona/my.cnf.sample to"
	ewarn "/etc/percona/my.cnf and then edit as desired"

	if use cluster;then
		einfo ""
		einfo "you have installed the cluster flavor"
		einfo "http://www.percona.com/doc/percona-xtradb-cluster/installation.html"
		einfo ""
		einfo "you may want to copy /etc/${SERVICE}/wsrep.cnf.sample"
		einfo "to /etc/${SERVICE}/wsrep.cnf and use:"
		einfo "!include /etc/${SERVICE}/wsrep.cnf"
		einfo "in your standard /etc/${SERVICE}/my.cnf"
		einfo ""
		einfo "/etc/xinetd.d/mysqlchk has been installed"
		einfo "this is useful for monitoring/health checks with load balancing"
		einfo "systems.  In or to make use of it you must add the following to"
		einfo "/etc/services:"
		einfo "mysqlchk        9200/tcp                # mysqlchk"
		einfo ""
		einfo "Additionally make sure xinetd is added to default runlevel etc"
		einfo "as appropriate. More info is available here:"
		einfo "https://github.com/olafz/percona-clustercheck"
	fi

}

pkg_config() {
	MY_SHAREDSTATEDIR="/opt/percona/share"
	MY_DATADIR="/var/lib/percona"

	local pwd1="a"
	local pwd2="b"
	local maxtry=15

	if [ -z "${MYSQL_ROOT_PASSWORD}" ]; then

		einfo "Please provide a password for the mysql 'root' user now, in the"
		einfo "MYSQL_ROOT_PASSWORD env var or through the /root/.my.cnf file."
		ewarn "Avoid [\"'\\_%] characters in the password"
		read -rsp "    >" pwd1 ; echo

		einfo "Retype the password"
		read -rsp "    >" pwd2 ; echo

		if [[ "x$pwd1" != "x$pwd2" ]] ; then
			die "Passwords are not the same"
		fi
		MYSQL_ROOT_PASSWORD="${pwd1}"
		unset pwd1 pwd2
	fi

	local options=""
	local sqltmp="$(emktemp)"

	local help_tables="${ROOT}${MY_SHAREDSTATEDIR}/fill_help_tables.sql"
	[[ -r "${help_tables}" ]] \
	&& cp "${help_tables}" "${TMPDIR}/fill_help_tables.sql" \
	|| touch "${TMPDIR}/fill_help_tables.sql"
	help_tables="${TMPDIR}/fill_help_tables.sql"

	pushd "${TMPDIR}" &>/dev/null
	${ROOT}/opt/percona/bin/mysql_install_db --basedir=/opt/percona \
	--datadir=/var/lib/percona --user mysql \
	--defaults-file=${ROOT}/etc/percona/my.cnf.sample \
	>"${TMPDIR}"/mysql_install_db.log 2>&1
	#${ROOT}opt/percona/bin/mysql_install_db --basedir=/opt/percona --datadir=/var/lib/percona --user mysql
	if [ $? -ne 0 ]; then
		grep -B5 -A999 -i "ERROR" "${TMPDIR}"/mysql_install_db.log 1>&2
		die "Failed to run mysql_install_db. Please review /var/log/percona/mysqld.err AND ${TMPDIR}/mysql_install_db.log"
	fi
	popd &>/dev/null
	[[ -f "${ROOT}/${MY_DATADIR}/mysql/user.frm" ]] \
	|| die "MySQL databases not installed"
	chown -R mysql:mysql "${ROOT}/${MY_DATADIR}" 2>/dev/null
	chmod 0750 "${ROOT}/${MY_DATADIR}" 2>/dev/null

	# Figure out which options we need to disable to do the setup
	helpfile="${TMPDIR}/mysqld-help"
	${ROOT}/opt/percona/bin/mysqld --verbose --help >"${helpfile}" 2>/dev/null
	for opt in grant-tables host-cache name-resolve networking slave-start bdb \
		federated innodb ssl log-bin relay-log slow-query-log external-locking \
		ndbcluster \
		; do
		optexp="--(skip-)?${opt}" optfull="--skip-${opt}"
		egrep -sq -- "${optexp}" "${helpfile}" && options="${options} ${optfull}"
	done
	# But some options changed names
	egrep -sq external-locking "${helpfile}" && \
	options="${options/skip-locking/skip-external-locking}"

	${ROOT}/opt/percona/bin/mysql_tzinfo_to_sql "${ROOT}/usr/share/zoneinfo" > "${sqltmp}" 2>/dev/null

	if [[ -r "${help_tables}" ]] ; then
		cat "${help_tables}" >> "${sqltmp}"
	fi

	einfo "Creating the mysql database and setting proper"
	einfo "permissions on it ..."

	local socket="${ROOT}/var/run/percona/mysqld${RANDOM}.sock"
	local pidfile="${ROOT}/var/run/percona/mysqld${RANDOM}.pid"
	local mysqld="${ROOT}/opt/percona/bin/mysqld \
		--defaults-file=${ROOT}/etc/percona/my.cnf.sample
		${options} \
		--user=mysql \
		--basedir=${ROOT}/opt/percona \
		--datadir=${ROOT}/${MY_DATADIR} \
		--max_allowed_packet=8M \
		--net_buffer_length=16K \
		--default-storage-engine=MyISAM \
		--lc-messages-dir=/opt/percona/share
		--general-log=true
		--general-log-file=/var/log/percona/mysqld.log
		--socket=${socket} \
		--pid-file=${pidfile}"
	#einfo "About to start mysqld: ${mysqld}"
	ebegin "Starting mysqld"
	${mysqld} 2>/dev/null &
	rc=$?
	while ! [[ -S "${socket}" || "${maxtry}" -lt 1 ]] ; do
		maxtry=$((${maxtry}-1))
		echo -n "."
		sleep 1
	done
	eend $rc

	if ! [[ -S "${socket}" ]]; then
		die "Completely failed to start up mysqld with: ${mysqld}"
	fi

	ebegin "Setting root password"
	# Do this from memory, as we don't want clear text passwords in temp files
	local sql="UPDATE mysql.user SET Password = PASSWORD('${MYSQL_ROOT_PASSWORD}') WHERE USER='root'"
	"${ROOT}/usr/bin/mysql" \
		--socket=${socket} \
		-hlocalhost \
		-e "${sql}"
	eend $?

	ebegin "Loading \"zoneinfo\", this step may require a few seconds ..."
	"${ROOT}/opt/percona/bin/mysql" \
		--socket=${socket} \
		-hlocalhost \
		mysql < "${sqltmp}"
	rc=$?
	eend $?
	[ $rc -ne 0 ] && ewarn "Failed to load zoneinfo!"

	# Stop the server and cleanup
	einfo "Stopping the server ..."
	kill $(< "${pidfile}" )
	rm -f "${sqltmp}"
	wait %1
	einfo "Done"
#mysql_install_db --datadir=/var/lib/percona/ --user mysq
}
