#!/bin/bash
#author: jiyin@redhat.com

LANG=C

# https://en.wikichip.org/wiki/irc/colors
ircBold=$'\x02'
ircItalics=$'\x1D'
ircUnderline=$'\x1F'
ircReverse=$'\x16'
ircPlain=$'\x0F'

ircWhite=$'\x03'00
ircBlack=$'\x03'01
ircNavy=$'\x03'02
ircGreen=$'\x03'03
ircRed=$'\x03'04
ircMaroon=$'\x03'05
ircPurple=$'\x03'06
ircOlive=$'\x03'07
ircYellow=$'\x03'08
ircLightGreen=$'\x03'09
ircTeal=$'\x03'10
ircCyan=$'\x03'11
ircRoyalblue=$'\x03'12
ircMagenta=$'\x03'13
ircGray=$'\x03'14
ircLightGray=$'\x03'15

mkdir -p /var/cache/distroDB
pushd /var/cache/distroDB  >/dev/null
mailTo=fs@redhat.com
mailCc=net@redhat.com
from="distro monitor <from@redhat.com>"
chanList="#fs-qe #network-qe #kernel-qe-sti"
fschan="#fs-qe"

kgitDir=/home/yjh/ws/code.repo
DVLIST="7 8 9"
prefix=.latest.distro
debug=$1

distro-list.sh --tag all | sort -r | egrep '^RHEL-'"[${DVLIST// /}]" >.distroListr

\cp .distroList .distroList.orig
while read d; do
	pkgList=$(awk -v d=$d 'BEGIN{ret=1} $1 == d {$1=""; print; ret=0} END{exit ret}' .distroList.orig 2>/dev/null) || {
		r=$d
		[[ "$r" =~ ^RHEL-?[0-9]\.[0-9]$ ]] && r=${r%%-*}-./${r##*-}
		pkgList=$(distro-compose -p '^(kernel|nfs-utils|autofs|rpcbind|[^b].*fs-?progs)-[0-9]+\..*' -d "$d" |
			grep -v ^= | sed -r 's/\.(x86_64|i686|noarch|ppc64le)\.rpm//g' |
			sort --unique | xargs | sed -r 's/(.*)(\<kernel-[^ ]* )(.*)/\2\1\3/')
		# Append the compose label if NOT a nightly distro
		if [ -n "$pkgList" ] && ! echo $d | egrep -q 'RHEL[-.[:digit:]]+n[.[:digit:]]+'; then
			pkgList="$pkgList  $(distro-compose -d $d --composeinfo 2>/dev/null | grep -o '"label": "[^"]*"')"
		fi
	}
	[ -z "$pkgList" ] && continue

	echo "$d  ${pkgList}"
done <.distroListr >.distroList

test -n "`cat .distroList`" &&
	for V in $DVLIST; do
	    egrep -a -i "^RHEL-${V}.[0-9]+" .distroList >${prefix}$V.tmp
	done

for V in $DVLIST; do
	f=${prefix}$V
	[ ! -f ${f}.tmp ] && continue
	[ -z "`cat ${f}.tmp`" ] && continue
	[ -f ${f} ] || {
		mv ${f}.tmp ${f}
		continue
	}
	[ -n "$debug" ] && {
		echo
		cat ${f}.tmp
		diff -pNur -w ${f} ${f}.tmp | sed 's/^/\t/'
		rm -f ${f}.tmp
		continue
	}

	available=1
	mailf=${PWD}/${f}.mail
	patchf=${PWD}/${f}.patch
	# print lines of file "${f}.tmp" for which the first column
	# (distro name) has not been seen in file "$f"
	awk 'NR==FNR{c[$1]++;next};c[$1] == 0' $f ${f}.tmp | tac > $patchf
	wc $patchf
	[[ $(wc -c < "$patchf") -lt 16 ]] && continue
	[[ $(wc -l < "$patchf") -gt 8 ]] && continue

	while read line; do
		[[ -z "$line" ]] && continue

		labs=
		read distro knvr pkglist <<< "$line"
		labs=$(distro-compose -d $distro -trees | awk '/^ *lab/ {n=split($1,a,"."); print a[n-2]}' | sort -u | paste -sd ,)
		label=
		[[ "$line" = *label?:* ]] && label="${line/*label?:/- with label:}"
		for chan in $chanList; do
			if test "$fschan" = "$chan"; then
				ircmsg.sh -s fs-qe.usersys.redhat.com -p 6667 -n testBot -P rhqerobot:irc.devel.redhat.com -L testBot:testBot \
				-C "$chan" "${ircBold}${ircRoyalblue}{Notice}${ircPlain} new distro: $line #labs: $labs"
			else
				ircmsg.sh -s fs-qe.usersys.redhat.com -p 6667 -n testBot -P rhqerobot:irc.devel.redhat.com -L testBot:testBot \
				-C "$chan" "${ircBold}${ircRoyalblue}{Notice}${ircPlain} new distro: ${_distro} ${ircRed}${knvr}${ircPlain} ${ircBold}${label}${ircPlain} #labs: $labs"
			fi
			sleep 1
		done

		# Highlight the packages whose version is increasing
		if echo $distro | egrep -q 'RHEL[-.[:digit:]]+n[.[:digit:]]+$'; then
			# nightly
			dtype="n"
		elif echo $distro | egrep -q 'RHEL[-.[:digit:]]+d[.[:digit:]]+$'; then
			# development
			dtype="d"
		elif echo $distro | egrep -q 'RHEL-[.[:digit:]]+-[.[:digit:]]+$'; then
			# rtt
			dtype="r"
		else
			# should not be here
			continue
		fi
		echo $line | sed 's/\s\+/\n/g' > ${f}.pkgvers_${dtype}.tmp
		test -f ${f}.pkgvers_${dtype} && {
			tmpKernel=$(awk -F'-' '/^kernel/{print $3}' ${f}.pkgvers_${dtype}.tmp)
			preKernel=$(awk -F'-' '/^kernel/{print $3}' ${f}.pkgvers_${dtype})
			if /usr/local/bin/vercmp "$tmpKernel" lt "$preKernel"; then
				# ignore the distro whose (kernel) version gets reversed
				continue
			fi
			if ! grep -q "${tmpKernel}" /var/cache/kernelnvrDB/*changeLog-${V}; then
				# skip if kernel dose not exist in the changelog
				continue
			fi
			pkgDiff=$(diff -pNur -w ${f}.pkgvers_${dtype} ${f}.pkgvers_${dtype}.tmp | awk '/^+[^+]/{ORS=" "; print $0 }' | cut -d " " -f 2-)
			if [ -n "$pkgDiff" ]; then
				preDistro=$(head -1 ${f}.pkgvers_${dtype})
				ircmsg.sh -s fs-qe.usersys.redhat.com -p 6667 -n testBot -P rhqerobot:irc.devel.redhat.com -L testBot:testBot -C "$fschan" \
				    "${ircPlain}highlight newer pkg: ${ircTeal}${pkgDiff} ${ircPlain}(vary to $preDistro)"
			fi
		}
		mv ${f}.pkgvers_${dtype}.tmp ${f}.pkgvers_${dtype}
		# provide latest distro info via ftp
		[ -s ${f}.pkgvers_${dtype} ] && cp -f ${f}.pkgvers_${dtype} /var/ftp/pub/distro-latest/rhel${V}.${dtype}
	done <$patchf

	#get stable version
	stbVersion=$(grep '^+[^+]' ${patchf} | awk '$(NF-1) ~ ".label.:"{print $1}' | head -n1)


	[[ $(wc -l < "$patchf") -lt 1 ]] && continue

	# print kernel changelog
	cat $patchf >$mailf
	echo >>$mailf
	echo "#-------------------------------------------------------------------------------" >>$mailf
	url=ftp://fs-qe.usersys.redhat.com/pub/kernel-changelog/changeLog-$V.html
	echo "# $url" >>$mailf
	tagr=$(awk '$1 ~ /^RHEL-/ && $2 ~ /kernel-/ {print $2}' $mailf | tail -n1 | sed s/$/.el${V}/)
	(echo -e "{Info} ${tagr} change log:"

	vr=${tagr/kernel-/}
	sed -n '/\*.*\['"${vr}a\?"'\]/,/^$/{p}' /var/cache/kernelnvrDB/*changeLog-${V} >changeLog
	sed -n '1p;q' changeLog
	grep '^-' changeLog | sort -k2,2
	echo) >>$mailf

	echo -e "\n\n#===============================================================================" >>$mailf
	echo -e "\n#Generated by cron latestDistroCheck" >>$mailf
	echo -e "\n#cur:" >>$mailf; cat $f.tmp >>$mailf
	echo -e "\n#pre:" >>$mailf; cat $f     >>$mailf

	[ $available = 1 ] && {
		sendmail.sh -p '[Notice] ' -f "$from" -t "$mailTo" -c "$mailCc" "$mailf" ": new RHEL${V} distro available"  &>/dev/null
		#cat $mailf
		mv ${f}.tmp ${f}
	}

	#if there is a stable version released, create testplan run
	[[ "${stbVersion#+}" =~ ^RHEL-(6.7|7.1) ]] && {
		#bkr-autorun-create ${stbVersion#+} /home/yjh/ws/case.repo/nfs-utils/nfs-utils.testlist --name nfs-utils.testplan
		: #bkr-autorun-create ${stbVersion#+} /home/yjh/ws/case.repo/kernel/filesystems/nfs/nfs.testlist --name nfs.testplan
	}

	rm -f $mailf $patchf
done

exit 0

popd  >/dev/null

