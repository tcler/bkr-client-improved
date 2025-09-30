#!/bin/bash

for issue; do
	echo -e $'\E[0;33;44m'"{get-mr-builds-by} jira-issue.py ${issue} Summary 'Testable Builds' fixVersions components 'QA Contact'" $'\E[0m' >&2
	issueInfo=$(jira-issue.py "${issue}" Summary 'Testable Builds' fixVersions components 'QA Contact' 'Fixed in Build')
	[[ -z "$issueInfo" ]] && continue
	summary=$(echo "${issueInfo}" | sed -rn "/BEGIN Summary/,/END Summary/{/(BEGIN|END) /d;p}")
	qacontact=$(echo "${issueInfo}" | sed -rn "/BEGIN QA.Con/,/END QA.Con/{/(BEGIN|END) /d;p}")
	repos=$(echo "${issueInfo}" | awk '/Repo.URL:/{print $NF}')
	if [[ -n "${repos}" ]]; then
		rhelVersion=$(echo "${issueInfo}" | sed -rn "/BEGIN fixVersions/,/END fixVersions/{/^.*name='([^']+)'.*$/{s//\\1/;p}}")
		rhelVersion=${rhelVersion#*-}
		component=$(echo "${issueInfo}" | sed -rn "/BEGIN components/,/END components/{/^.*name='([^']+)'.*$/{s//\\1/;p}}")
		component=${component// /}; [[ "$component" = *kernel-rt* ]] && component=$'\E[0;33;45m'"$component"$'\E[0m'
		echo -e "${issue}  $qacontact  ${rhelVersion}  #${component}  [$summary] \n\`- https://issues.redhat.com/browse/${issue}"
		for repo in $repos; do
			dbgkOpt=
			[[ $repo = *_debug* ]] && dbgkOpt+=' -debugk'
			[[ $repo = *x86_64* ]] && yum-repo-query.sh $repo |& grep -q kernel-rt && dbgkOpt+=' rtk'
			echo -e "\t$repo$dbgkOpt"
		done
	else
		echo -e "${issue}  $qacontact  ${rhelVersion}  #${component}  [$summary] \n\`- https://issues.redhat.com/browse/${issue}"
		echo -e "\t#No MR-build-repo found, maybe a user-space package. https://issues.redhat.com/browse/${issue}"
		fixedBuild=$(echo "${issueInfo}" | sed -rn "/BEGIN Fixed.in.Build/,/END Fixed.in.Build/{/(BEGIN|END) /d;p}")
		echo -e "\tFixed.in.Build: $fixedBuild"
		if [[ "$fixedBuild" = None ]]; then
			echo -e $'\E[0;31m'"\t{Error} There is neither kernel MR-build nor user-space fixedBuild, IMO 'Preliminary Testing' value should not be 'Requested' here" $'\E[0m'>&2
		fi
	fi
done
