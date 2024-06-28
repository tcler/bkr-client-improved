#!/bin/bash

git_repo_path=$1
tarball_path=$2
pattern=$3

[[ $# -lt 3 ]] && {
	echo -e "Usage: $0 <git-repo_dir> <dir-to-save-the-tarball> <pattern> [tar options]"
	echo -e "Example:\n  $0 ~/testrepos/kernel-test.git /www/testcase  ^networking  --include=networking"
	exit 1
}
shift 3

mkdir -p "${tarball_path}"
git_repo_path=$(readlink -f ${git_repo_path})
dirname=${git_repo_path##*/}
tarballf="${tarball_path}/${dirname%.git}.tar.gz"
pushd ${git_repo_path}
	pull_log=$(git pull --rebase 2>&1|tee /dev/tty)
	if [[ ! -f "${tarballf}" ]]; then
		tar -zcf "${tarballf}" "../${dirname}" --exclude-ignore=.git "$@"
	elif grep -Eqi "${pattern}" <<<"$pull_log"; then
		tar -zcf "${tarballf}.tmp" "../${dirname}" --exclude-ignore=.git "$@"
		mv "${tarball_path}/${dirname%.git}.tar.gz.tmp" "${tarball_path}/${dirname%.git}.tar.gz"
	fi
popd
