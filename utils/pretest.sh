#!/bin/bash

command -v jira &>/dev/null || {
	echo "{error} command jira is required!" >&2
	exit 1
}

preTestIssues=$(jira issue list --plain --no-truncate --no-headers --columns KEY \
	-q"project = RHEL and 'Preliminary Testing' = Requested and 'QA Contact' = currentUser()")

for issue in ${preTestIssues}; do
	issueInfo=$(jira-issue.py "${issue}" 'Testable Builds' fixVersions components)
	repo=$(echo "${issueInfo}" | awk '/Debug.Repo.URL:/{print $NF}')
	if [[ -n "${repo}" ]]; then
		rhelVersion=$(echo "${issueInfo}" | sed -rn "/BEGIN fixVersions/,/END fixVersions/{/^.*name='([^']+)'.*$/{s//\\1/;p}}")
		component=$(echo "${issueInfo}" | sed -rn "/BEGIN components/,/END components/{/^.*name='([^']+)'.*$/{s//\\1/;p}}")
		echo -e "${issue}   '${repo}'\n    runtest ${rhelVersion#*-} -B='$repo'  #${component// /}"
	else
		echo -e "${issue}   #{WARN} can not find MR-build-repo"
	fi
done
