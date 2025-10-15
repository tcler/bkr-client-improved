#!/bin/bash

command -v jira &>/dev/null || {
	echo "{error} command jira is required!" >&2
	exit 1
}

_args=()
for arg; do
	case $arg in
	-i*|-i=*)  arg=${arg#-i}; preTestIssues=${arg#*=};;
	*)  _args+=("$arg");;
	esac
done
set -- "${_args[@]}"

fsusers="yieli yoyang jiyin xzhou zlang xifeng kunwan bxue fs-qe"
maillist() { local list; for u; do list+="\"$u@redhat.com\", "; done; echo -n "${list%, }"; }
users=${*};
if [[ "$users" = fs || "$users" = all ]]; then
	users=$(maillist $fsusers)
elif [[ -n "$users" ]]; then
	users=$(maillist $users)
else
	users='currentUser()'
fi
[[ -z "$preTestIssues" ]] && {
	preTestIssues=$(jira issue list --plain --no-truncate --no-headers --columns KEY \
		-q"project = RHEL and 'Preliminary Testing' = Requested and 'QA Contact' in (${users})")
}

issue-info.sh ${preTestIssues}
