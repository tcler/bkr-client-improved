#!/bin/bash

issue-view-json() { local id=$1; jira issue view "$id" --raw|jq; }
get-split-tasks() { jq -r '.fields.issuelinks[] | select(.type.outward == "split to") | .outwardIssue | [.key, .fields.summary] | join(" ")'; }
get-summary() { jq -r '.fields.summary'; }
get-component() { jq -r '.fields.components[0].name'; }
get-stat() { jq -r '.fields.status.name'; }
get-fixvers() { jq -r '.fields.fixVersions[].name'; }
get-qa() { jq -r '.fields.customfield_10470.displayName'; }
get-fixedbuild() { jq -r '.fields.customfield_10578'; }
get-preliminary() { jq -r '.fields.customfield_10879.value'; }
get-mrbuilds2() {
	jq -r '
  .fields.customfield_10894.content[]
  | select(.type == "paragraph")
  | .content as $content

  # Downstream Pipeline Name
  | if any($content[]; .type == "text" and (.text | startswith("Downstream Pipeline Name: "))) then
      "\n" + ($content[] | select(.type == "text" and (.text | startswith("Downstream Pipeline Name: "))) | .text | sub("Downstream Pipeline Name: "; ""))

  # get buildName and repoURLs, if content match "Repo URL:"
  elif any($content[]; .type == "text" and .text == "Repo URL: ") then
      ($content[0] | select(.type == "text") | .text | sub(":$"; "")) + " " +
      (($content[] | select(.marks? // [] | map(.type == "link") | any) | .marks[0].attrs.href) // "")

  else empty
  end' 2>/dev/null | awk '
        /\([a-z0-9_-]+\)/ { pipel=$1; }
        /^[0-9]+\..*https:/ {
                key = $1 "@" pipel
                repo[key] = repo[key] (repo[key] ? " " : "") $NF
        }
        END {
                for (k in repo) {
			if (k !~ /.*CENTOS.*/) {
				#printf("%s\n%s\n\n", k, gensub(/ /, "\n", "g", repo[k]));
				printf("%s %s\n\n", k, repo[k]);
			}
		}
        }'
}
get-mrbuilds() {
	jq -r '.fields.customfield_10894.content[-1].content[-1].text | gsub("\\\\n"; "\n")' | awk -v RS= '
	/Downstream.Pipeline.Name:/ { pipel=$4; }
	/^[0-9]+\..*Repo.URL:/ {
		key = $1 pipel
		repo[key] = repo[key] (repo[key] ? " " : "") $NF
	}
	END {
		for (k in repo) { if (k !~ /.*CENTOS.*/) {print k, repo[k]} } 
	}' | sort
}

_args=()
for arg; do
	case $arg in
	-mr=*) arg=${arg#-mr=}; mrbuild_pat=${arg,,};;
	-sp*) showSplit=yes;;
	*) _args+=("$arg");;
	esac
done
set -- "${_args[@]}"

mrbuild_pat=${mrbuild_pat:-'x86_64.*(realtime|rhel)'}
echo "{debug} mrbuild pattern: ${mrbuild_pat}" >&2
for issue; do
	echo -e $'\E[0;33;44m'"{custom field list} jira-issue.py ${issue}" $'\E[0m' >&2
	issueJson=$(issue-view-json $issue)
	[[ -z "$issueJson" ]] && continue

	summary=$(echo "$issueJson"|get-summary)
	qe=$(echo "$issueJson"|get-qa)
	component=$(echo "${issueJson}" | get-component); component=${component// /};
	stat=$(echo "$issueJson"|get-stat)
	preliminaryStat=$(echo "${issueJson}" | get-preliminary)
	[[ ${preliminaryStat,,} = requested ]] && {
		mr_repos=$(echo "${issueJson}" | get-mrbuilds)
		[[ -z "$mr_repos" ]] &&
			mr_repos=$(echo "${issueJson}" | get-mrbuilds2)
	}
	rhelVersion=$(echo "${issueJson}" | get-fixvers)
	rhelVersion=${rhelVersion#*-}
	fixedBuild=$(echo "${issueJson}" | get-fixedbuild)
	[[ "$component" = *kernel-rt* ]] && component=$'\E[0;33;45m'"$component"$'\E[0m'
	echo -e "${issue} $qe ${rhelVersion} #${component} [$summary] - $stat \n\`- https://redhat.atlassian.net/browse/${issue} #Preliminary:${preliminaryStat}"
	if [[ "${preliminaryStat,,}" =~ (requested|fail) ]]; then
		[[ -z "${mr_repos}" ]] && {
			echo -e "\t#No MR-build-repo found, Maybe: user-space pkg. Or: the developer didn't follow the agreed workflow"
			if [[ "$fixedBuild" != null ]]; then
				echo -e "\tFixed.in.Build: $fixedBuild"
			fi
		}
		while read build repos; do
			[[ -z "${build}" ]] && continue
			[[ "${build,,}" =~ $mrbuild_pat ]] || continue
			echo -e "\n  $build"
			for repo in $repos; do echo "    $repo"; done
		done <<<"$mr_repos"
	elif [[ "${preliminaryStat,,}" = pass ]]; then
		echo -e "\tFixed.in.Build: $fixedBuild"
		if [[ "$fixedBuild" = null ]]; then
			echo -e $'\E[0;31m'"\t{Note} Fixed.in.Build is still null" $'\E[0m'>&2
		fi
	fi
	if [[ "${showSplit}" ]]; then
		splits=$(echo "$issueJson"|get-split-tasks)
		[[ -n "$splits" ]] && echo -e "\nSplit-to:\n$splits"
	fi
done
