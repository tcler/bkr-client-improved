#!/bin/bash

issue-view-plain() { local id=$1; jira issue view "$id" --plain; }
#get-split-tasks() { sed -rn '/SPLIT.TO/,/----/p' | sed -e '1d;/^ *$/d;$d' -e 's/ *\n*$//'; }

issue-view-json() { local id=$1; jira issue view "$id" --raw|jq; }
get-split-tasks() { jq -r '.fields.issuelinks[].outwardIssue | [.key, .fields.summary] | join(" ")'; }
get-summary() { jq -r '.fields.summary'; }
get-component() { jq -r '.fields.components[0].name'; }
declare -A labelPrefix=(
	[dev_task]="DEV Task"
	[root_cause_analysis_task]="Root Cause Analysis Task"
	[patch_review_task]="Patch Review Task"
	[upstream_task]="Upstream"
	[preliminary_testing_task]="Preliminary Testing Task"
	[integration_testing_task]="Integration Testing Task"
)

label2Prefix() {
	local label=$1
	case $label in
	dev*) label=dev_task;;
	roo*) label=root_cause_analysis_task;;
	pat*) label=patch_review_task;;
	up*)  label=upstream_task;;
	pre*) label=preliminary_testing_task;;
	int*) label=integration_testing_task;;
	esac
	echo $label "[${labelPrefix[$label]}]:"
}

issue-split2() {
	local fromid=$1
	local label=$2
	local sp=${3:-3}
	local me prefix issueJson splits summary component

	read label prefix < <(label2Prefix $label)
	me=$(jira me)
	issueJson=$(issue-view-json $fromid) || return 2
	splits=$(echo "$issueJson"|get-split-tasks) || return 3
	summary=$(echo "$issueJson"|get-summary) || return 3
	component=$(echo "$issueJson"|get-component) || return 3

	if ! grep -iF "$prefix" <<<"$splits"; then
		local std=$(jira issue create -tTask -s"$prefix $summary" --no-input \
		  -a"$me" -C"$component" -l"$label" -yNormal \
		  --custom assignedteam=rhel-fs-net --custom story-points=${sp} |&
			tee /dev/tty)
		local issuelink=$(echo "$std"|tail -1)
		jira issue link "$fromid" "${issuelink##*/}" "Issue split"
	else
		echo "{warn} there has been split issue '$prefix *', skip this op" >&2
	fi
}

Usage() {
	cat <<-EOF
	Usage: $0 <issue-id> <label> [story-point]
	Available label:
	EOF
	for K in "${!labelPrefix[@]}"; do echo "  $K"; done
}

[[ $# < 2 ]] && { Usage >&2; exit 1; }
issue-split2 "$@"
