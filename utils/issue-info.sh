#!/bin/bash

issue-view-json() { local id=$1; jira issue view "$id" --raw|jq; }
get-summary() { jq -r '.fields.summary'; }
get-component() { jq -r '.fields.components[0].name'; }
get-qa() { jq -r '.fields.customfield_12315948.name'; }
get-devel() { jq -r '.fields.assignee.name'; }
get-team() { jq -r '.fields.customfield_12326540.value'; }
get-stat() { jq -r '.fields.status.name'; }
get-fixvers() { jq -r '.fields.fixVersions[].name'; }
get-fixedbuild() { jq -r '.fields.customfield_12318450'; }
get-mrbuilds() {
	jq -r '.fields.customfield_12321740' | awk -v RS= '
	/Downstream.Pipeline.Name:/ { pipel=$4; }
	/^[0-9]+\..*Repo.URL:/ {
		key = $1 pipel
		repo[key] = repo[key] (repo[key] ? " " : "") $NF
	}
	END {
		for (k in repo) { if (k !~ /.*CENTOS.*/) {print k, repo[k]} } 
	}' | sort
}

for issue; do
	echo -e $'\E[0;33;44m'"{custom field list} jira-issue.py ${issue}" $'\E[0m' >&2
	issueJson=$(issue-view-json $issue)
	[[ -z "$issueJson" ]] && continue

	summary=$(echo "$issueJson"|get-summary)
	qe=$(echo "$issueJson"|get-qa)
	component=$(echo "${issueJson}" | get-component)
	stat=$(echo "$issueJson"|get-stat)
	mr_repos=$(echo "${issueJson}" | get-mrbuilds)
	if [[ -n "${mr_repos}" ]]; then
		rhelVersion=$(echo "${issueJson}" | get-fixvers)
		rhelVersion=${rhelVersion#*-}
		component=${component// /}; [[ "$component" = *kernel-rt* ]] && component=$'\E[0;33;45m'"$component"$'\E[0m'
		echo -e "${issue}  $qe  ${rhelVersion}  #${component}  [$summary] $stat \n\`- https://issues.redhat.com/browse/${issue}"
		while read build repos; do
			echo -e "\n  $build"
			for repo in $repos; do echo "    $repo"; done
		done <<<"$mr_repos"
	else
		echo -e "${issue}  $qe  ${rhelVersion}  #${component}  [$summary] $stat \n\`- https://issues.redhat.com/browse/${issue}"
		echo -e "\t#No MR-build-repo found, maybe a user-space package. https://issues.redhat.com/browse/${issue}"
		fixedBuild=$(echo "${issueJson}" | get-fixedbuild)
		echo -e "\tFixed.in.Build: $fixedBuild"
		if [[ "$fixedBuild" = null ]]; then
			echo -e $'\E[0;31m'"\t{Error} There is neither kernel MR-build nor user-space fixedBuild, IMO 'Preliminary Testing' value should not be 'Requested' here" $'\E[0m'>&2
		fi
	fi
done
