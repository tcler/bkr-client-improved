#!/bin/bash
#jiyin@redhat.com
#be used to create a Restraint build of a specific PR,commit or master

P=$0; [[ $0 = /* ]] && P=${0##*/}
User=restraint-harness
PrjName=restraint
PrjPath=${User}/${PrjName}
curdir=$PWD

_requires_cmds() {
	local cmd= rc=0
	for cmd; do
		command -v $cmd &>/dev/null || {
			echo -e "\033[1;31m{ERROR} command  \033[1;34m$cmd\033[1;31m  is required by $P, but not found\033[0m" >&2
			let rc++
		}
	done
	return $rc
}
_requires_cmds rhpkg brew || exit 2

## argparse
Usage() {
	echo "Usage: $P <prID|commitID|master> [target: beaker-harness-rhel-\$N|eng-fedora-\$N] [--arches=<arch,list|all>] [--prj=tcler/nrestraint] [-n|--dry] [-v|--version \$VER] [--download[=targetdir]]"
	echo "Args and Options:"
	echo "  \$1            a {PR(pull request) ID} or {commit ID(sha)} or {master}"
	echo "  \$2            the build target name: beaker-harness-rhel-\$N|eng-fedora-\$N  #default:beaker-harness-rhel-9"
	echo "  -h,--help     output this help info"
	echo "  -a,--arches:  comma seperated arch list: aarch64,ppc64le  #default is x86_64, 'all' means all availables"
	echo "  -p,--prj:     build from fork: anotherUser/newReponame"
	echo "  -n,--dry:     only download tarball and create srpm but don't realy submmit the build"
	echo "  -v,--version: specific version-release, e.g: 0.5.2-1"
	echo "  --download[=dir]:   download the rpms after build finish"
	echo -e "\nExamples:"
	echo "  $P 303"
	echo "  $P 303 beaker-harness-rhel-8"
	echo "  $P 73ad3be eng-fedora-40 -a ppc64le,s390x"
	echo "  $P master -p tcler/nrestraint -a all eng-fedora-42 --version 0.5.2-1"
	echo "  $P master -p tcler/nrestraint -a all beaker-harness-rhel-9 --version 0.5.2-1 --download=rhel-9"
}
_at=`getopt -o ha:p:nv: \
	--long help \
	--long arch: --long arches: \
	--long prj: \
	--long dry \
	--long version: \
	--long download:: \
    -a -n '$P' -- "$@"`
eval set -- "$_at"

while true; do
	case "$1" in
	-h|--help)      Usage; shift 1; exit 0;;
	-a|--arch*)     arches="$2"; shift 2;;
	-p|--prj)       prjPath="$2"; fork=${prjPath%%/*}; shift 2;;
	-n|--dry)       dryRun="yes"; shift 1;;
	-v|--version)   read Version Release <<<"${2/-/ }"; shift 2;;
	--download)     DOWNLOAD=yes; downloaddir="${2}"; shift 2;;
	--) shift; break;;
	esac
done

[[ $# = 0 ]] && {
	Usage >&2
	exit 1
}

prcoID=$1
prjPath=${prjPath:-$PrjPath}
target=${2:-beaker-harness-rhel-9}
webBaseUrl=https://github.com/${prjPath}
apiBaseUrl=https://api.github.com/repos/${prjPath}

pullBaseUrl=${apiBaseUrl}/tarball/pull
commitBaseUrl=${webBaseUrl}/archive
masterUrl=${webBaseUrl}/archive/refs/heads/master.tar.gz

#get the tarball url and infix according the PR or Commit ID
if [[ "${prcoID}" =~ ^[1-9][0-9]+$ ]]; then
	_type=pr; _infix=pr.${prcoID}
	tarballUrl=${pullBaseUrl}/${prcoID}/head
elif [[ "${prcoID,,}" =~ ^[0-9a-f]+$ ]]; then
	_type=co; _infix=co.${prcoID}
	tarballUrl=${commitBaseUrl}/${prcoID}.tar.gz
elif [[ "${prcoID,,}" = ma* ]]; then
	_coID=$(curl -Ls ${apiBaseUrl}/commits/master |
		awk -F'[ :",]+' '$2=="sha"{print substr($3,0,7); exit}')
	_type=ma; _infix=master.$_coID
	tarballUrl=$masterUrl
else
	{ Usage >&2; exit 1; }
fi
[[ -n "$fork" ]] && _infix=${fork}.${_infix}

#clone/copy the Restraint rh-build repo
_spec_repodir=~/restraint-build
[[ -d "$_spec_repodir" ]] || rhpkg clone restraint $_spec_repodir
spec_repodir=~/Restraint-prbuild-${_infix}
[[ -d "$spec_repodir" ]] || cp -r $_spec_repodir $spec_repodir

#__main__
(cd $spec_repodir || exit 1
rm -f restraint.spec && git checkout .
git pull --rebase && git checkout $target || exit $?
git status
tarballName=${PrjName}-${_infix/./-}.tgz

#download PR tarball
echo -e "\033[1;34m{INFO} download tarball of ${prcoID} from $tarballUrl\033[0m"
rm -f ${tarballName}
curl -L -f $tarballUrl -o ${tarballName}
if [[ "$?" != 0 ]]; then
	echo -e "\033[1;31m{ERROR}: downloading tarball fail, please verify the pr/commit ID or network\033[0m" >&2;
	exit 1;
fi

#get topdir-name(format: restraint-harness-restraint-$commitID) from tarball
#and get restraint.spec from it
oldTopdir=$(tar taf $tarballName | sed -rn "1{s|/$||; p; q}")
tar -C . -zxf ${tarballName} --warning=no-timestamp
cp $oldTopdir/restraint.spec .

if [[ -n "$Version" ]]; then
	#awk -v ver=$Version -i inplace '/Version:/{$2=ver}{print}' restraint.spec
	sed -ri "s/^(Version:[[:space:]]+).*$/\1$Version/" restraint.spec
fi

#get version info from restraint.spec
#and gen new topdir-name that must be restraint-${ver}
grep -e Version: -e Release: -e Source0: restraint.spec | GREP_COLORS='ms=34' grep --color=always . >&2
ver=$(awk '/Version:/{print $2}' restraint.spec)
newTopdir=restraint-${ver}

#gen new tarballName that must not be restraint-${ver}.tar.gz
#Otherwise rhpkg will always download and overwrite it when creating srpm
ntarballName=${newTopdir}-${_infix/./-}.tar.gz

#extract tarball, rename topdir and re-archive
echo -e "\033[1;34m{INFO} generate the tarball(${ntarballName}) that will be included in srpm\033[0m"
rm -rf $newTopdir && mv -T $oldTopdir $newTopdir
tar zcf ${ntarballName} ${newTopdir}
pwd
ls -l ${ntarballName}

#gen relInfix and update Release value in spec file
relInfix=${_infix}
[[ $_type = pr ]] && { _coID=${oldTopdir/*-/}; relInfix=${_infix}.${_coID}; }
[[ -n "$Release" ]] && sed -ri "/Release:/{s/\<([^[:space:]%]+)%/${Release}%/}" restraint.spec
sed -ri -e "/Release:/{s/%/.${relInfix:-wrongInfix.}&/}" \
	-e "/Source0:/{s|/[^/]+$|/${ntarballName}|}" restraint.spec
grep -e Version: -e Release: -e Source0: restraint.spec | GREP_COLORS='ms=34' grep --color=always . >&2

#gen srpm and submit scratch-build
rm -f *.rpm
echo -e "\033[1;34m{INFO} generate the srpm file\033[0m"
rhpkg srpm
srpmfile=$(ls *.src.rpm)
if [[ -z "$srpmfile" ]]; then
	echo "{Error} create srpm file fail" >&2
	exit 2
fi
cp -u $(ls *.{gz,xz,bz2}|grep -v $ntarballName) $_spec_repodir/.

arches=${arches:-x86_64}
##tips: like curl rhpkg doesn't support '--options=xyz', please use '--options xyz'
[[ "${arches,,}" != all ]] && archOpt="--arches ${arches//,/ }"
echo -e "\033[1;34m{DEBUG} run: rhpkg scratch-build --srpm $srpmfile $archOpt\033[0m";
[[ "$dryRun" = yes ]] && exit 0
rhpkg scratch-build --srpm $srpmfile $archOpt |& tee build-screen.log

#get build state
prBuildInfoFile=/tmp/rstrnt-prbuild-${_infix}-${target}.info
brewTaskID=$(awk '/Created task:/{print $NF}' build-screen.log)
brew taskinfo -r $brewTaskID |& tee $prBuildInfoFile
buildStat=$(awk '/^State:/{print $NF}' $prBuildInfoFile)
if [[ "$buildStat" != closed ]]; then
	cat <<-LOG >&2
	{Error} restraint PR($prcoID) build failed. see:
	  https://brewweb.engineering.redhat.com/brew/taskinfo?taskID=$brewTaskID
	LOG
	exit 1
else
	#fixme: if want create a permenant yum repo for test section
	echo -e "\033[1;34m{INFO} restraint PR($prcoID) build success, see you in test section\033[0m"
	if [[ "$DOWNLOAD" = yes ]]; then
		(cd "$curdir/${downloaddir}"; brewinstall.sh -downloadonly -arch=all $brewTaskID)
	else
		echo -e "{INFO} you can download the build rpms by:"
		echo -e "  brewinstall.sh -downloadonly -arch=all $brewTaskID"
	fi
fi
)
