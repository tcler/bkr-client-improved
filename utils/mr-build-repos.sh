#!/bin/bash

command -v jira &>/dev/null || {
	echo "{error} command jira is required!" >&2
	exit 1
}

preTestIssues="$*"
[[ -z "$preTestIssues" ]] && {
	preTestIssues=$(jira issue list --plain --no-truncate --no-headers --columns KEY \
		-q"project = RHEL and 'Preliminary Testing' = Requested and 'QA Contact' = currentUser()")
}

for issue in ${preTestIssues}; do
	echo -e $'\E[0;33;44m'"{get-mr-builds-by} jira-issue.py '${issue}' 'Testable Builds' fixVersions components" $'\E[0m'>&2
	issueInfo=$(jira-issue.py "${issue}" 'Testable Builds' fixVersions components)
	title=$(sed -n '/Title: */{s///;p;q}' <<<"$issueInfo")
	repos=$(echo "${issueInfo}" | awk '/Repo.URL:/{print $NF}')
	if [[ -n "${repos}" ]]; then
		rhelVersion=$(echo "${issueInfo}" | sed -rn "/BEGIN fixVersions/,/END fixVersions/{/^.*name='([^']+)'.*$/{s//\\1/;p}}")
		rhelVersion=${rhelVersion#*-}
		component=$(echo "${issueInfo}" | sed -rn "/BEGIN components/,/END components/{/^.*name='([^']+)'.*$/{s//\\1/;p}}")
		component=${component// /}; [[ "$component" = *kernel-rt* ]] && component=$'\E[0;33;45m'"$component"$'\E[0m'
		echo -e "${issue}  ${rhelVersion}  #${component}  [$title]"
		for repo in $repos; do
			dbgkOpt=
			[[ $repo = *_debug* ]] && dbgkOpt+=' -debugk'
			[[ $repo = *x86_64* ]] && yum-repo-query.sh $repo |& grep -q kernel-rt && dbgkOpt+=' rtk'
			echo -e "\t$repo$dbgkOpt"
		done
	else
		echo -e "${issue}   #{WARN} can not find MR-build-repo"
	fi
done
