#!/bin/bash

repodir=${1%/}
prefix=${2}
[[ -z "$prefix" ]] && {
	auto_prefix=yes
	prefix=/${repodir##*/}/
}

[[ $# = 0 ]] && {
	cat <<-EOF
	Usage:
	  $0 <test-case-repo-dir> [prefix]

	Example:
	  $0 ~/ws/testcase/kernel
	  $0 ~/ws/testcase/nfs-utils.git [/nfs-utils/]  #optional
	  $0 ~/ws/testcase/libtirpc [/CoreOS/libtirpc/] #optional
	  $0 ~/ws/testcase/kernel.orig  /kernel.orig/
	EOF
	exit 0
}

## find non-existent test cases
while read _case; do
	if [[ "$auto_prefix" = yes ]]; then
		case ${_case} in
		${prefix}*) :;;
		${prefix%.git}*) prefix=${prefix%.git};;
		/CoreOS${prefix}*) prefix=/CoreOS${prefix};;
		/CoreOS${prefix%.git}*) prefix=/CoreOS${prefix%.git};;
		esac
	fi

	if [[ "$_case" != ${prefix}* ]]; then
		continue
	fi

	case=${_case/#$prefix/}
	[[ -f $repodir/$case/Makefile && -f $repodir/$case/runtest.sh ]] || {
		echo "non-exist: $case"
		testcaseList+=($_case)
	}
done < <(bkr-autorun-stat -t | awk -F: '{print $1}' | uniq)

## remove them from data base
cnt=${#testcaseList[@]}
max=32
if [[ $cnt -gt 0 ]]; then
	if [[ $cnt -gt $max ]]; then
		echo "[warn] the count of non-existent test cases is more than $max"
		read -p '`- still remove them? [y/n] ' ans
		[[ "$ans" != y ]] && {
			exit 0
		}
	fi
	bkr-autorun-del -y -delcase "${testcaseList[*]}"
fi
