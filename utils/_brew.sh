#!/bin/bash
#author jiyin@redhat.com

verx=$(lsb_release -sr|awk -F. '{print $1}')
dfix=f
echo "$(lsb_release -si)" | egrep -q "^(RedHat|Sci|Cent)" && dfix=el

installBrew2() {
	#https://mojo.redhat.com/docs/DOC-1024827
	urls="
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-6-server.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-6-client.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-6-workstation.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-7-server.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-7-client.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-7-workstation.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-8-baseos.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/internal/rcm-tools-fedora.repo
	"

	local name=$(lsb_release -sir|awk '{print $1}')
	local verx=$(lsb_release -sr|awk -F. '{print $1}')

	pushd /etc/yum.repos.d
	case $name in
	RedHatEnterprise*)
		case $verx in
		6|7)
			for type in server client workstation; do
				curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-${verx}-${type}.repo
				yum install -y koji brewkoji && break || rm rcm-tools-*.repo
			done
			;;
		8)
			curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-8-baseos.repo
			yum install -y koji brewkoji python3-koji python3-pycurl || rm rcm-tools-*.repo
			;;
		esac
		;;
	Fedora*)
		curl -L -O http://download.devel.redhat.com/rel-eng/internal/rcm-tools-fedora.repo
		yum install -y koji brewkoji
		;;
	esac
	popd

	which brew &>/dev/null
}
installBrewFromSourceCode() {
	git -c http.sslVerify=false clone  https://code.engineering.redhat.com/gerrit/rcm-brewkoji.git
	cd rcm-brewkoji
	make install >/dev/null

	which brew &>/dev/null
}

# fix ssl certificate verify failed
#curl https://password.corp.redhat.com/RH-IT-Root-CA.crt -o /etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt
#curl https://password.corp.redhat.com/legacy.crt -o /etc/pki/ca-trust/source/anchors/legacy.crt
#update-ca-trust

# install koji & brew
yum --setopt=strict=0 install -y koji python-koji python-pycurl brewkoji
which brew &>/dev/null || installBrew2 || installBrewFromSourceCode

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

