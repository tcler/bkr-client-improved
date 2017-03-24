#!/bin/bash
#author: jiyin@redhat.com

mkdir -p /var/cache/distroDB
pushd /var/cache/distroDB  >/dev/null
baseurl=http://download.devel.redhat.com/rel-eng
supath=compose/metadata/composeinfo.json
mailTo=fff@redhat.com
mailCc=kkk@redhat.com

kgitDir=/home/yjh/ws/code.repo
VLIST="6 7"
DVLIST=$(echo $VLIST)
latestDistroF=.latest.distro
dfList=$(eval echo $latestDistroF{${DVLIST// /,}})
#echo $dfList

#getLatestRHEL all >.distroListr
distro-list.sh all | egrep '^(RHEL|Pegas)-?[678]' >.distroListr
while read d; do
	pkgList=$(awk -v d=$d 'BEGIN{ret=1} $1 == d {$1=""; print; ret=0} END{exit ret}' .distroList.orig) || {
		r=$d
		[[ "$r" =~ ^RHEL-?[0-9]\.[0-9]$ ]] && r=${r%%-*}-./${r##*-}
		pkgList=$(vershow '^(kernel|nfs-utils|autofs|rpcbind|[^b].*fs-?progs)-[0-9]+\..*' "/$r$" |
			grep -v ^= | sed -r 's/\..?el[0-9]+.?\.(x86_64|i686|noarch|ppc64le)\.rpm//g' |
			uniq | xargs | sed -r 's/(.*)(\<kernel-[^ ]* )(.*)/\2\1\3/')
	}
	[ -z "$pkgList" ] && continue
	pkgList=${pkgList%%\"label\":*}
	#read auto kernel nfs rpcbind nil <<<$pkgList
	#echo -n -e "$d\t$kernel  $nfs  $auto  $rpcbind"
	read kernel nil <<<$pkgList
	echo -n "$d  ${pkgList}"

	curl $baseurl/$d/$supath 2>/dev/null|grep \"label\": || echo
done <.distroListr >.distroList
\cp .distroList .distroList.orig

test -n "`cat .distroList`" &&
	for V in $DVLIST; do
	    v=${V//[cs]/} t=${V//[0-9]/}
	    egrep -i "^(RHEL|Pegas)-?${v}.[0-9]+-${t}" .distroList >${latestDistroF}$V.tmp
	done

for f in $dfList; do
	[ ! -f ${f}.tmp ] && continue
	[ -z "`cat ${f}.tmp`" ] && continue
	[ -f ${f} ] || {
		mv ${f}.tmp ${f}
		continue
	}
	[ -n "$1" ] && {
		echo
		cat ${f}.tmp
		diff -pNur -w ${f} ${f}.tmp | sed 's/^/\t/'
		rm -f ${f}.tmp
		continue
	}

	v=${f/$latestDistroF/}
	t=${f##*.}; t=${t/$v/}

	available=1
	p=${PWD}/${f}.patch
	diff -pNur -w $f ${f}.tmp >$p && continue
	sed -i '/^[^+]/d' $p
	grep '^+[^+]' ${p} || continue

	Pegas=
	while read l; do
		[[ -z "$l" -o "$l" =~ ^\+\+\+ ]] && continue
		egrep -i pegas <<<$l || Pegas=and && {
			Pegas+=" Pegas"
			break
		}
	done <$p

	while read l; do
		[[ -z "$l" -o "$l" =~ ^\+\+\+ ]] && continue

		for chan in "#fs-qe" "#network-qe"; do
			ircmsg.sh -s fs-qe.usersys.redhat.com -p 6667 -n testBot -P rhqerobot:irc.devel.redhat.com -L testBot:testBot -C "$chan" \
				"{Notice} new distro: $l"
			sleep 2
		done
	done <$p

	#get stable version
	stbVersion=$(grep '^+[^+]' ${p} | awk '$(NF-1) ~ ".label.:"{print $1}' | head -n1)

	echo >>$p
	echo "#-------------------------------------------------------------------------------" >>$p
	url=https://home.corp.redhat.com/wiki/rhel${v%[cs]}changelog
	url=http://patchwork.lab.bos.redhat.com/status/rhel${v%[cs]}/changelog.html
	urlPegas=http://patchwork.lab.bos.redhat.com/status/pegas1/changelog.html
	echo "# $url" >>$p
	echo "# $urlPegas" >>$p
	tagr=$(awk '$1 ~ /^+/ && $2 ~ /kernel-/ {print $2}' $p|head -n1|sed s/$/.el${v%[cs]}/)
	(echo -e "\n{Info} ${tagr} change log:"

	vr=${tagr/kernel-/}
	vr=${vr/pegas-/}
	sed -n '/\*.*\['"${vr}"'\]/,/^$/{p}' /var/cache/kernelnvrDB/*changeLog${v%[cs]} >changeLog
	sed -n '1p;q' changeLog
	grep '^-' changeLog | sort -k2,2
	echo) >>$p

	echo -e "\n\n#===============================================================================" >>$p
	echo -e "\n#Generated by cron latestDistroCheck" >>$p
	echo -e "\n#cur:" >>$p; cat $f.tmp >>$p

	[ $available = 1 ] && {
		sendmail.sh -p '[Notice] ' -f "from@redhat.com" -t "$mailTo" -c "$mailCc" "$p" ": new RHEL${v} $Pegas ${t} available"  &>/dev/null
		#cat $p
		mv ${f}.tmp ${f}
	}

	#if there is a stable version released, create testplan run
	[[ "${stbVersion#+}" =~ ^RHEL-(6.7|7.1) ]] && {
		#bkr-autorun-create ${stbVersion#+} /home/yjh/ws/case.repo/nfs-utils/nfs-utils.testlist --name nfs-utils.testplan
		: #bkr-autorun-create ${stbVersion#+} /home/yjh/ws/case.repo/kernel/filesystems/nfs/nfs.testlist --name nfs.testplan
	}

	rm -f $p
done

exit 0

popd  >/dev/null

