#!/bin/bash

command -v jira &>/dev/null || {
	echo "{error} command jira is required!" >&2
	exit 1
}

fsusers="yieli yoyang jiyin xzhou zlang xifeng kunwan bxue fs-qe"
maillist() { local list; for u; do list+="\"$u@redhat.com\", "; done; echo -n "${list%, }"; }
users=${*}
if [[ "$users" = fs || "$users" = all ]]; then
	users=$(maillist $fsusers)
elif [[ -n "$users" ]]; then
	users=$(maillist $users)
else
	users=me
fi
IssuesNeedVerify=$(jira issue list --plain --no-truncate --no-headers --columns KEY \
	-q"issueFunction in issueFieldMatch('project = RHEL AND status = Integration AND \"QA Contact\" in (currentUser(), ${users})', 'customfield_12318450', '.{3,}')")

[[ ${#IssuesNeedVerify[@]} -gt 0 ]] &&
	echo -e $'\E[0;33;44m'"{get-issue-info-by} jira-issue.py \${issue} Summary 'Fixed in Build' fixVersions components 'QA Contact'" $'\E[0m'>&2
for issue in ${IssuesNeedVerify}; do
	echo "${issue} - https://issues.redhat.com/browse/${issue}"
	issueInfo=$(jira-issue.py "${issue}" Summary 'Fixed in Build' fixVersions components 'QA Contact')
	summary=$(echo "${issueInfo}" | sed -rn "/BEGIN Summary/,/END Summary/{/(BEGIN|END) /d;p}")
	qacontact=$(echo "${issueInfo}" | sed -rn "/BEGIN QA.Con/,/END QA.Con/{/(BEGIN|END) /d;p}")
	fixedBuild=$(echo "${issueInfo}" | sed -rn "/BEGIN Fixed.in.Build/,/END Fixed.in.Build/{/(BEGIN|END) /d;p}")
	rhelVersion=$(echo "${issueInfo}" | sed -rn "/BEGIN fixVersions/,/END fixVersions/{/^.*name='([^']+)'.*$/{s//\\1/;p}}")
	rhelVersion=${rhelVersion#*-}
	component=$(echo "${issueInfo}" | sed -rn "/BEGIN components/,/END components/{/^.*name='([^']+)'.*$/{s//\\1/;p}}")
	component=${component// /}; [[ "$component" = *kernel-rt* ]] && component=$'\E[0;33;45m'"$component"$'\E[0m'
	echo -e "  ${fixedBuild}  $qacontact  #${rhelVersion}  ${component}  [$summary]"
done
