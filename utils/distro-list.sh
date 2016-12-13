#!/bin/bash
#author: jiyin@redhat.com

P=${0##*/}
baseurl='https://beaker.engineering.redhat.com/distros/'
tmpf=/tmp/.distro.$$
tgp_limit=50

getList() {
	local url=$1
	curl -u: "${url}" -k 2>/dev/null 1>$tmpf
	pageNum=$(grep -E -o 'Items found: [0-9]+' $tmpf|head -n1|awk "{print int((\$3+$tgp_limit)/$tgp_limit)}")
	for page in `seq 2 $pageNum`; do
		#curl -u: "${url}&list_tgp_no=$page&distrosearch--repetitions=1" -k 2>/dev/null 1>>$tmpf
		curl -u: "${url}&list_tgp_no=$page" -k 2>/dev/null 1>>$tmpf
	done
}

if [[ "$1" =~ ^[0-9] ]]; then
	set -- rtt "$@"
fi
export type=${1-rtt}

[ ${P} = getLatestRHEL ] || {
	echo -e "#Usage: ${0##*/} [all|rtt|stb|rel|ins|active (default rtt)]" >&2
	echo -e "#tag type: \033[1;34m<$type>\033[0m, fetch the list ...(please wait a minute)" >&2
}
case $type in
al|all) url="${baseurl}?";;
rt|rtt) url="${baseurl}?distrosearch-0.table=Tag&distrosearch-0.operation=is&distrosearch-0.value=RTT_ACCEPTED&Search=Search";;
s|st|stb) url="${baseurl}?distrosearch-0.table=Tag&distrosearch-0.operation=is&distrosearch-0.value=STABLE&Search=Search";;
re|rel) url="${baseurl}?distrosearch-0.table=Tag&distrosearch-0.operation=is&distrosearch-0.value=RELEASED&Search=Search";;
i|in|ins) url="${baseurl}?distrosearch-0.table=Tag&distrosearch-0.operation=is&distrosearch-0.value=INSTALLS&Search=Search";;
ac|act|acti|activ|active) url="${baseurl}?distrosearch-0.table=Tag&distrosearch-0.operation=is&distrosearch-0.value=Active&Search=Search";;
*) url="${baseurl}?";;
esac
getList "$url"

res=$(grep '/distros/view.*</a>' $tmpf |
	awk -F'[<>]' '($3!~/^[0-9]+$/) {print $3}' |
		sort -u -rV)
rm -f $tmpf

shift
#===============================================================================
getLatestRHEL() {
	[ $type = stb ] && sufix="$"
	rttList=$res
	[ -z "$1" -o "$1" = all ] && set 5c 5s 6 7 8 9 10
	for VER in "$@"; do
		[ ${VER:0:1} = 5 ] && {
			subv="[0-9]"; [ -n "${VER:2:1}" ] && subv=${VER:2:1}
			if echo $VER | grep -q 'c$'; then
				echo "$rttList" | egrep '^RHEL-?'${VER:0:1}'\.'"$subv"'+-C'$sufix | head -n1
				[ $type != all ] && echo "$rttList" | egrep '^RHEL-?'${VER:0:1}'-C.*-U'"$subv"'+'$sufix | head -n1
			else
				echo "$rttList" | egrep '^RHEL-?'${VER:0:1}'\.'"$subv"'+-S'$sufix | head -n1
				[ $type != all ] && echo "$rttList" | egrep '^RHEL-?'${VER:0:1}'-S.*-U'"$subv"'+'$sufix | head -n1
			fi
			continue
		}
		if [ $type = all ]; then
			echo "$rttList" | egrep "^RHEL-${VER}$" ||
				echo "$rttList" | egrep '^RHEL-?'${VER:0:3}'[.0-9]*-'$sufix | head -n1
		else
			echo "$rttList" | egrep "^RHEL-${VER}$" ||
				echo "$rttList" | egrep '^RHEL-?'${VER:0:3}'[.0-9]*'$sufix | head -n1
		fi
	done
}

if [ ${P} = getLatestRHEL ]; then
	getLatestRHEL "$@"
else
	echo "${res}"
fi

