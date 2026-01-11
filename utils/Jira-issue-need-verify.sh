#!/bin/bash

command -v jira &>/dev/null || {
	echo "{error} command jira is required!" >&2
	exit 1
}

issue-view-json() { local id=$1; jira issue view "$id" --raw|jq; }
get-summary() { jq -r '.fields.summary'; }
get-component() { jq -r '.fields.components[0].name'; }
get-qa() { jq -r '.fields.customfield_12315948.name'; }
get-devel() { jq -r '.fields.assignee.name'; }
get-stat() { jq -r '.fields.status.name'; }
get-fixvers() { jq -r '.fields.fixVersions[].name'; }
get-fixedbuild() { jq -r '.fields.customfield_12318450'; }

maillist() { local list; for u; do list+="\"$u@redhat.com\", "; done; echo -n "${list%, }"; }
fsusers="yieli yoyang jiyin xzhou zlang xifeng kunwan bxue fs-qe"

_args=()
for arg; do
	case $arg in (-s*) SPLIT=yes;; (*) _args+=("$arg");; esac
done
set -- "${_args[@]}"

users=${*}
if [[ "$users" = fs || "$users" = all ]]; then
	users=$(maillist $fsusers)
elif [[ -n "$users" ]]; then
	users=$(maillist $users)
else
	users='currentUser()'
fi
IssuesNeedVerify=$(jira issue list --plain --no-truncate --no-headers --columns KEY \
	-q"issueFunction in issueFieldMatch('project = RHEL AND status = Integration AND \"QA Contact\" in (${users})', 'customfield_12318450', '.{3,}')")
[[ $? != 0 && -z "$IssuesNeedVerify" ]] && {
	echo "[WARN] getting issues fail, if you updated system version, might need re-install jira-cli" >&2
}

[[ ${#IssuesNeedVerify[@]} -gt 0 ]] &&
	echo -e $'\E[0;33;44m'"{custom field list} jira-issue.py \${issue}" $'\E[0m' >&2
for issue in ${IssuesNeedVerify}; do
	echo "${issue} - https://issues.redhat.com/browse/${issue}"
	issueJson=$(issue-view-json $issue)
	[[ -z "$issueJson" ]] && continue

	summary=$(echo "$issueJson"|get-summary)
	qe=$(echo "$issueJson"|get-qa)
	component=$(echo "${issueJson}" | get-component); component=${component// /};
	[[ "$component" = *kernel-rt* ]] && component=$'\E[0;33;45m'"$component"$'\E[0m'
	stat=$(echo "$issueJson"|get-stat)
	fixedBuild=$(echo "${issueJson}" | get-fixedbuild)
	rhelVersion=$(echo "${issueJson}" | get-fixvers)
	rhelVersion=${rhelVersion#*-}
	echo -e "  ${fixedBuild} $qe #${rhelVersion} ${component} [$summary] - $stat"
	[[ "$SPLIT" = yes ]] && {
		echo "{info} creating [Integration Testing Task] for $issue ..."
		issue-split.sh $issue int
	}
done
