#!/bin/bash

owner=$1
owner=${owner:-fs-qe}

brokenList=$(bkr list-systems --xml-filter='<system><owner op="==" value="'"$owner"'"/></system>' --status Broken)

for h in $brokenList; do
	hinfo=$(bkr-hosts.sh $h)
	if ! grep -q LoanedTo: <<<"$hinfo"; then
		bkr system-modify --condition Automated $h
	else
		bkr system-modify --condition Manual $h

		# send e-mail
		read key user < <(grep LoanedTo: <<<"$hinfo")
		cat <<-EOF | sendmail.sh -p '[Notice] ' -f "QE-Assistant <jiyin@redhat.com>" -c "${user}@redhat.com" - "Broken host remind"  &>/dev/null
		Hi ${user}

		host $h loaned to you was broken, I have recovered it to 'Manual'
		if that's not your expected, please try use follow command update the status:
		  bkr system-modify --condition Automated $h
		EOF
	fi
done
