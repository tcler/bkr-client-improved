#!/bin/bash
#author jiyin@redhat.com

baseDownloadUrl=https://raw.githubusercontent.com/tcler/bkr-client-improved/master

is_intranet() {
	local iurl=http://download.devel.redhat.com
	curl --connect-timeout 5 -m 10 --output /dev/null --silent --head --fail $iurl &>/dev/null
}

is_intranet && {
	Intranet=yes
	baseDownloadUrl=http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved
}

# install brew
which brew &>/dev/null || {
	which brewkoji_install.sh || {
		_url=$baseDownloadUrl/utils/brewkoji_install.sh
		mkdir -p ~/bin && wget -O ~/bin/brewkoji_install.sh -N -q $_url
		chmod +x ~/bin/brewkoji_install.sh
	}
	brewkoji_install.sh >/dev/null || {
		echo "{WARN} install brewkoji failed" >&2
		exit 1
	}
}

progname=${0##*/}

_searchBrewBuild() {
	[ $# -lt 1 ] && {
		echo "usage: $0 <pkgName|pattern>" >&2
		return 1
	}
	local pattern=$1
	brew search build $dbgArg -r "$pattern" | sort -V -r
}
_stateBrewBuild() {
	[ $# -lt 1 ] && {
		echo "usage: $0 <pkgName>" >&2
		return 1
	}
	local nvr=$1
	brew buildinfo $nvr | awk '/State/ {print $2}'
}

case $progname in
searchBrewBuild)
	_searchBrewBuild "$@" ;;
stateBrewBuild)
	_stateBrewBuild "$@" ;;
esac

