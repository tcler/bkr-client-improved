#!/bin/bash
# author jiyin@redhat.com

#This is a beaker recipe use status checker, that invoked by cron

declare -A HostMax

eval "$(tclsh <<EOF
$(cat /etc/bkr-client-improved/bkr-autorun.conf ~/.bkr-client-improved/bkr-autorun.conf 2>/dev/null)
puts "
HostMax\[x86_64\]=\$HostAvilable(x86_64)
HostMax\[i386\]=\$HostAvilable(i386)
HostMax\[ppc64\]=\$HostAvilable(ppc64)
HostMax\[ppc64le\]=\$HostAvilable(ppc64le)
HostMax\[aarch64\]=\$HostAvilable(aarch64)
HostMax\[s390x\]=\$HostAvilable(s390x)
"
EOF
)"

ret=0
users="$1"

recipeCheck() {
	local arch=${1:-x86_64}
	local user=${2:-jiyin}
	local url=http://nest.test.redhat.com/mnt/qa/scratch/azelinka/beaker-stats/top-recipe-owners.$arch
	I=$(echo $url; curl $url 2>/dev/null)
	T=$(echo "$I" | tail -n1)
	read Date Hour Min Sec ignore <<<"${T//[:.]/ }"
	[[ $Date = $(date +%F) && $Hour = $(date +%H) ]] || {
		echo "[$(date +%F_%T)] Data time is wrong $Date $Hour:$Min:$Sec "
		return 0
	}

	M=$(echo "$I" | awk '$1 ~ "'$user'" {print $1, $2}')
	while read U N; do
		[ "${N:-0}" -gt ${HostMax[$arch]} ] && {
			let ret++
			echo "$I" | sendmail.sh -p '[Remind warning line !@#%^&*] ' -t "$U@redhat.com" -c "jiyin@redhat.com" - \
				"You($U) hold too much($N/${HostMax[$arch]}) $arch recipes"  &>/dev/null
		}
	done <<<"$M"
	echo -e "\033[1;34m$arch host usage status\033[0m:\n$I"
}

users="${users:-^(jiyin)$}"
recipeCheck x86_64  "$users"
recipeCheck ppc64   "$users"
recipeCheck ppc64le "$users"
recipeCheck s390x   "$users"
recipeCheck i386    "$users"

exit $ret
