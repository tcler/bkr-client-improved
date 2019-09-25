#!/bin/bash

Usage() {
	echo "Usage: $0 [-o owner] [-f emailFrom] [-c emailCc]" >&2
}

_at=`getopt -o ho:f:c: \
	--long help \
	--long owner: \
    -a -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help)   Usage; shift 1; exit 0;;
	-o|--owner)  owner=$2; shift 2;;
	-f)          from=$2; shift 2;;
	-c)          cc=$2; shift 2;;
	--) shift; break;;
	esac
done

logf=/tmp/bkr-system-broken-recover.log
baseUrl=http://beaker.engineering.redhat.com
owner=${owner:-fs-qe}
from=${from:-QE Assistant <jiyin@redhat.com>}

brokenList=$(bkr list-systems --xml-filter='<system><owner op="==" value="'"$owner"'"/></system>' --status Broken)

for h in $brokenList; do
	hinfo=$(bkr-hosts.sh $h)
	if ! grep -q LoanedTo: <<<"$hinfo"; then
		echo "[$(date +%F-%T)] $hinfo" >>$logf

		#skip if there is Broken flag in Notes
		egrep -qi '" *(Ticket|Broken):' <<<"$hinfo" && continue

		#try reboot and change condition back to Automated
		echo $'`-> reboot and return to Automated\n' >>$logf
		bkr system-power --action off $h
		bkr system-power --action on $h
		bkr system-modify --condition Automated $h

		#try reserve this host to see if it's real works fine
	else
		bkr system-modify --condition Manual $h

		# send e-mail
		read key user < <(grep LoanedTo: <<<"$hinfo")
		cat <<-EOF | sendmail.sh -p '[Notice] ' -f "$from" -t "${user}@redhat.com" -c "$cc" - "Broken host remind"  &>/dev/null
		Hi ${user}

		host $h loaned to you was broken, I have reverted it to 'Manual':
		$(bkr-hosts.sh $h)

		if it isn't your expected.. please try use follow command update the status:
		    bkr system-power --action off $h && bkr system-power --action on $h
		    bkr system-modify --condition Automated $h
		or update from webUI: $baseUrl/view/$h
		EOF
	fi
done
