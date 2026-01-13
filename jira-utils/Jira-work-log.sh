#!/bin/bash

command -v jira &>/dev/null || {
	echo "{error} command jira is required!" >&2
	exit 1
}

issue-view-json() { local id=$1; jira issue view "$id" --raw|jq; }
get-summary() { jq -r '.fields.summary'; }
get-component() { jq -r '.fields.components[0].name'; }
get-versions() { jq -r '.fields.versions|map(.name)|join(",")'; }
get-fixvers() { jq -r '.fields.fixVersions[].name'; }
get-reporter() { jq -r '.fields.reporter.name'; }
get-qa() { jq -r '.fields.customfield_12315948.name'; }

_args=()
for arg; do
	case $arg in
	-h|h|help)  echo "Usage: $0 [krb5_id ...]"; exit 0;;
	-w*)  week=${arg#-w}; week=${week#=}w;;
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
	-q"project = RHEL AND created >= startOfWeek($week) and created < endOfWeek($week) AND reporter in (${users})")
for issue in ${reportedIssues}; do
	issueJson=$(issue-view-json $issue)
	summary=$(echo "$issueJson"|get-summary)
	versions=$(echo "${issueJson}" | get-versions)
	component=$(echo "${issueJson}" | get-component); component=${component// /};
	reporter=$(echo "$issueJson"|get-reporter)
	echo "- https://issues.redhat.com/browse/${issue} $reporter  $summary  /$versions"
done | sort -k3

echo -e "\nPre-Verified:"
preVerifiedIssues=$(jira issue list --plain --no-truncate --no-headers --columns KEY  \
	-q"project = RHEL AND 'Preliminary Testing' = PASS AND (status = 'In Progress' OR status = Integration AND status CHANGED DURING (startOfWeek($week), endOfweek($week))) AND 'QA Contact' in (${users})")
for issue in ${preVerifiedIssues}; do
	issueJson=$(issue-view-json $issue)
	qacontact=$(echo "$issueJson"|get-qa)
	summary=$(echo "$issueJson"|get-summary)
	rhelVersion=$(echo "${issueJson}" | get-fixvers)
	rhelVersion=${rhelVersion#*-}
	echo "- https://issues.redhat.com/browse/${issue} $qacontact  $summary  /$rhelVersion"
done | sort -k3

echo -e "\nVerified:"
verifiedIssues=$(jira issue list --plain --no-truncate --no-headers --columns KEY  \
	-q"project = RHEL AND status = 'Release Pending' AND status CHANGED DURING (startOfWeek($week), endOfweek($week)) AND 'QA Contact' in (${users})")
for issue in ${verifiedIssues}; do
	issueJson=$(issue-view-json $issue)
	qacontact=$(echo "$issueJson"|get-qa)
	summary=$(echo "$issueJson"|get-summary)
	rhelVersion=$(echo "${issueJson}" | get-fixvers)
	rhelVersion=${rhelVersion#*-}
	echo "- https://issues.redhat.com/browse/${issue} $qacontact  $summary  /$rhelVersion"
done | sort -k3
