#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations
import os, sys
from jira import JIRA

jira = JIRA(server='https://issues.redhat.com', token_auth=os.environ.get('JIRA_API_TOKEN'))
allfields=jira.fields()
nameMap = {field['name']:field['id'] for field in allfields}
if len(sys.argv) < 3:
    if sys.argv[1]:
        issue = jira.issue(sys.argv[1])

    print(f"Usage: <{sys.argv[0]}> <issue-id> <field-name [field-name ...]> vvv")
    if issue:
        for key, value in nameMap.items():
            if value in issue.raw['fields']: print(f"  {key:<40}\t{value}")
    else:
        for key, value in nameMap.items(): print(f"  {key:<40}\t{value}")
    print(f"Usage: <{sys.argv[0]}> <issue-id> <field-name [field-name ...]> ^^^\nExamples:")
    print(f"  python {sys.argv[0]} RHEL-24133 'Testable Builds'")
    print(f"  python {sys.argv[0]} RHEL-24133 fixVersions 'Preliminary Testing'")
    exit(1)

issueid = sys.argv[1]
issue = jira.issue(issueid)

def printIssueField(issue, fieldname):
    attrname = fieldname
    if fieldname in nameMap:
        attrname = nameMap[fieldname]
    print(f'{{ === BEGIN {fieldname}:')
    print(getattr(issue.fields, attrname))
    print(f'}} --- END {fieldname}:\n')

for field in sys.argv[2:]:
    printIssueField(issue, field)
