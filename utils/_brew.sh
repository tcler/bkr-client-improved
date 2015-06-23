#!/bin/bash
#author jiyin@redhat.com

verx=$(lsb_release -sr|awk -F. '{print $1}')
dfix=f
echo "$(lsb_release -si)" | egrep -q "^(RedHat|Sci|Cent)" && dfix=el

# install koji
yum install -y koji &>/dev/null
which koji &>/dev/null || {
	#git clone https://git.fedorahosted.org/git/koji
	wget --no-check-certificate https://fedorahosted.org/released/koji/koji-1.9.0.tar.bz2
	tar jxf koji-1.9.0.tar.bz2
	(cd koji-1.9.0; make install &>koji_install.log)
	[ $? != 0 ] && {
		echo "[Error] Install koji/brew from source fail!" >&2
		exit 1
	}
}
which brew &>/dev/null || {
	#cat <<END > ~/.koji/config
	mkdir -p ~/.koji /etc/koji.conf.d
	cat <<END > /etc/koji.conf.d/brew.conf
[brew]
server = http://brewhub.devel.redhat.com/brewhub
authtype = kerberos
topdir = /mnt/redhat/brewroot
weburl = http://brewweb.devel.redhat.com/brew
topurl = http://download.devel.redhat.com/brewroot
END
	ln -s /usr/bin/koji /usr/local/bin/brew
}

progname=${0##*/}

_searchBrewBuild() {
	[ $# -lt 1 ] && {
		echo "usage: $0 <pkgName|pattern>" >&2
		return 1
	}
	local pattern=$1
	brew search build $dbgArg -r "$pattern" | sortV -r
}
_downloadBrewBuild() {
	[ $# -lt 1 ] && {
		echo "usage: $0 <pkgName> [--arch=<src|i386|ppc64|...>]" >&2
		return 1
	}
	brew  $dbgArg download-build "$@"
}
_installBrewPkg() {
Usage() {
	echo "usage: $0 [-f] [-n] <pkgNamePattern> [pkgNamePattern ...]"
	echo "   ex: $0 ^autofs-[0-9].*"
	echo "   ex: $0 -n ^autofs-[0-9].*\.el7"
	echo "   -f	Force install package"
	echo "   -n	Not append distroVersion info at search pattern"
	echo "   --debuginfo	install the debuginfo pkg"
	return 1
}
	TEMP=`getopt -o "fna:" --long debuginfo --long target   -n 'example.bash' -- "$@"`
	if [ $? != 0 ] ; then Usage >&2 ; exit 1 ; fi

	# Note the quotes around `$TEMP': they are essential!
	eval set -- "$TEMP"
	#===============================================================================
	autofix='.*\.'"${dfix}${verx}"
	# parse the argument
	OPTIND=1
	local arch=$(arch)
	while true ; do
		case $1 in
		-f)	force="--force --nodeps"; shift 1;;
		-n)	autofix=; shift 1;;
		-a)	arch=$2; shift 2;;
		--debuginfo)	debuginfo=--debuginfo; shift 1;;
		--)	shift; break;;
		*) echo "Internal error!"; exit 1;;
		esac
	done
	[ $# -lt 1 ] && { Usage >&2; exit 1; }
	test $arch = i686 && vercmp $(lsb_release -sr) match '^5\..*' && arch=i386
	local list="$@"
	[ -n "${BrewPkgList}" ] && list=${BrewPkgList}

	local dir=$(mktemp -d)
	pushd $dir
	for pkg in ${list}; do
		local bname=`_searchBrewBuild "${pkg}${autofix}" | head -n 1`
		[ -z "$bname" ] && echo "[Warn] brew search fail in '${pkg}${autofix#\\}'"
		_downloadBrewBuild $bname --arch=$arch $debuginfo || _downloadBrewBuild $bname --arch=noarch
	done
	ls *.rpm &>/dev/null && {
		rpm -ivh *.rpm $force || yum install -y *.rpm
	}
	popd
	rm -rf $dir
}

case $progname in
searchBrewBuild)
	_searchBrewBuild "$@" ;;
downloadBrewBuild)
	_downloadBrewBuild "$@" ;;
installBrewPkg)
	_installBrewPkg "$@" ;;
*)
	brew "$@" ;;
esac

