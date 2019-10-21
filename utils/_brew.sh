#!/bin/bash
#author jiyin@redhat.com

# install brew
which brew &>/dev/null || {
	which brewkoji_install.sh || {
		_url=https://raw.githubusercontent.com/tcler/bkr-client-improved/master/utils/brewkoji_install.sh
		mkdir -p ~/bin && wget -O ~/bin/brewkoji_install.sh -N -q $_url
		chmod +x ~/bin/brewkoji_install.sh
	}
	brewkoji_install.sh >/dev/null || {
		echo "{WARN} install brewkoji failed" >&2
		exit 1
	}
}

verx=$(lsb_release -sr|awk -F. '{print $1}')
dfix=f
echo "$(lsb_release -si)" | egrep -q "^(RedHat|Sci|Cent)" && dfix=el

progname=${0##*/}

_searchBrewBuild() {
	[ $# -lt 1 ] && {
		echo "usage: $0 <pkgName|pattern>" >&2
		return 1
	}
	local pattern=$1
	brew search build $dbgArg -r "$pattern" | sort -V -r
}
_downloadBrewBuild() {
	[ $# -lt 1 ] && {
		echo "usage: $0 <pkgName> [--arch=<src|i386|ppc64|...>]" >&2
		return 1
	}
	brew  $dbgArg download-build "$@"
}
_stateBrewBuild() {
	[ $# -lt 1 ] && {
		echo "usage: $0 <pkgName>" >&2
		return 1
	}
	local nvr=$1
	brew buildinfo $nvr | awk '/State/ {print $2}'
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
stateBrewBuild)
	_stateBrewBuild "$@" ;;
installBrewPkg)
	_installBrewPkg "$@" ;;
*)
	brew "$@" ;;
esac

