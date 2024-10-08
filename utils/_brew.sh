#!/bin/bash
#author jiyin@redhat.com

LOOKASIDE_BASE_URL=${LOOKASIDE:-http://download.devel.redhat.com/qa/rhts/lookaside}
baseDownloadUrl=https://raw.githubusercontent.com/tcler/bkr-client-improved/master

is_rh_intranet() { host ipa.redhat.com &>/dev/null; }

is_rh_intranet && {
	Intranet=yes
	baseDownloadUrl=${LOOKASIDE_BASE_URL}/bkr-client-improved
}

# install brew
which brew &>/dev/null || {
	if [[ $(id -u) != 0 ]]; then
		echo "{WARN} command brew is required, please exec 'sudo brewkoji_install.sh' at first" >&2
		exit 1
	fi
	which brewkoji_install.sh || {
		_url=$baseDownloadUrl/utils/brewkoji_install.sh
		mkdir -p ~/bin && curl -o ~/bin/brewkoji_install.sh -k -Ls $_url
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

