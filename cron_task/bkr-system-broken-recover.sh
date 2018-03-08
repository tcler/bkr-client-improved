#!/bin/bash

Usage() {
	echo "Usage: $0 [-o owner] [-f emailFrom] [-c emailCc]" >&2
}

_at=`getopt -o ho:f:c: \
	--long help \
	--long owner: \
    -n "$0" -- "$@"`
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

owner=${owner:-fs-qe}
from=${from:-QE Assistant <jiyin@redhat.com>}

brokenList=$(bkr list-systems --xml-filter='<system><owner op="==" value="'"$owner"'"/></system>' --status Broken)

for h in $brokenList; do
	hinfo=$(bkr-hosts.sh $h)
	if ! grep -q LoanedTo: <<<"$hinfo"; then
		bkr system-modify --condition Automated $h
	else
		bkr system-modify --condition Manual $h

		# send e-mail
		read key user < <(grep LoanedTo: <<<"$hinfo")
		cat <<-EOF | sendmail.sh -p '[Notice] ' -f "$from" -t "${user}@redhat.com" -c "$cc" - "Broken host remind"  &>/dev/null
		Hi ${user}

		host $h loaned to you was broken, I have reverted it to 'Manual':
		$(bkr-hosts.sh $h)

		if it isn't your expected.. please try use follow command update the status:
		  bkr system-modify --condition Automated $h
		EOF
	fi
done
