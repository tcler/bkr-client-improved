#!/bin/bash

command -v jira &>/dev/null || {
	echo "{error} command jira is required!" >&2
	exit 1
}

_args=()
for arg; do
	case $arg in
	-h|h|help)  echo "Usage: $0 [krb5_id ...]"; exit 0;;
	*)  _args+=("$arg");;
	esac
done
set -- "${_args[@]}"

fsusers="me yieli yoyang jiyin xzhou zlang xifeng kunwan bxue fs-qe"
maillist() { local list; for u; do [[ $u = me ]] && list+="currentUser(), " || list+="\"$u@redhat.com\", "; done; echo -n "${list%, }"; }
users=${*};
if [[ "$users" = fs || "$users" = all ]]; then
	users=$(maillist $fsusers)
elif [[ -n "$users" ]]; then
	users=$(maillist $users)
else
	users=me
fi
[[ "$users" = me ]] && users="currentUser()"
echo -e "{debug} users: $users" >&2
echo -e "Reported:"
reportedIssues=$(jira issue list --plain --no-truncate --no-headers --columns KEY  \
	-q"project = RHEL AND created >= startOfWeek() and created < endOfWeek() AND reporter in (${users})")
for issue in ${reportedIssues}; do
	issueInfo=$(jira-issue.py "${issue}" Summary versions components Reporter)
	summary=$(echo "${issueInfo}" | sed -rn "/BEGIN Summary/,/END Summary/{/(BEGIN|END) /d;p}")
	reporter=$(echo "${issueInfo}" | sed -rn "/BEGIN Reporter/,/END Reporter/{/(BEGIN|END) /d;p}")
	versions=$(echo "${issueInfo}" | sed -rn "/BEGIN versions/,/END versions/{/^.*name='([^']+)'.*$/{s//\\1/;p}}")
	echo "- https://issues.redhat.com/browse/${issue} $reporter  $summary  /$versions"
done | sort -k3

echo -e "\nPre-Verified:"
preVerifiedIssues=$(jira issue list --plain --no-truncate --no-headers --columns KEY  \
	-q"project = RHEL AND 'Preliminary Testing' = PASS AND (status = 'In Progress' OR status = Integration AND status CHANGED DURING (startOfWeek(), endOfweek())) AND 'QA Contact' in (${users})")
for issue in ${preVerifiedIssues}; do
	issueInfo=$(jira-issue.py "${issue}" Summary fixVersions components 'QA Contact')
	summary=$(echo "${issueInfo}" | sed -rn "/BEGIN Summary/,/END Summary/{/(BEGIN|END) /d;p}")
	qacontact=$(echo "${issueInfo}" | sed -rn "/BEGIN QA.Con/,/END QA.Con/{/(BEGIN|END) /d;p}")
	rhelVersion=$(echo "${issueInfo}" | sed -rn "/BEGIN fixVersions/,/END fixVersions/{/^.*name='([^']+)'.*$/{s//\\1/;p}}")
	rhelVersion=${rhelVersion#*-}
	echo "- https://issues.redhat.com/browse/${issue} $qacontact  $summary  /$rhelVersion"
done | sort -k3

echo -e "\nVerified:"
verifiedIssues=$(jira issue list --plain --no-truncate --no-headers --columns KEY  \
	-q"project = RHEL AND status = 'Release Pending' AND status CHANGED DURING (startOfWeek(), endOfweek()) AND 'QA Contact' in (${users})")
for issue in ${verifiedIssues}; do
	issueInfo=$(jira-issue.py "${issue}" Summary fixVersions components 'QA Contact')
	summary=$(echo "${issueInfo}" | sed -rn "/BEGIN Summary/,/END Summary/{/(BEGIN|END) /d;p}")
	qacontact=$(echo "${issueInfo}" | sed -rn "/BEGIN QA.Con/,/END QA.Con/{/(BEGIN|END) /d;p}")
	rhelVersion=$(echo "${issueInfo}" | sed -rn "/BEGIN fixVersions/,/END fixVersions/{/^.*name='([^']+)'.*$/{s//\\1/;p}}")
	rhelVersion=${rhelVersion#*-}
	echo "- https://issues.redhat.com/browse/${issue} $qacontact  $summary  /$rhelVersion"
done | sort -k3
