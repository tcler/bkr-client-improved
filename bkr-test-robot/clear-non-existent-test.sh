#!/bin/bash

repodir=${1%/}
prefix=${2}
[[ -z "$prefix" ]] && prefix=/${repodir##*/}/

[[ $# = 0 ]] && {
	cat <<-EOF
	Usage:
	  $0 <test-case-repo-dir> [prefix]

	Example:
	  $0 ~/ws/testcase/kernel
	  $0 ~/ws/testcase/nfs-utils.git /nfs-utils/
	EOF
	exit 0
}

## find non-existent test cases
while read _case; do
	case=${_case/#$prefix/}
	[[ -f $repodir/$case/Makefile && -f $repodir/$case/runtest.sh ]] || {
		echo "non-exist: $case"
		testcaseList+=($_case)
	}
done < <(bkr-autorun-stat -t | awk -F: '{print $1}' | uniq)

## remove them from data base
cnt=${#testcaseList[@]}
max=64
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
