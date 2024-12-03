#!/bin/sh

url='https://auth.RH.com/auth/realms/EmployeeIDP/protocol/saml/clients/gitlab-groups-RH'
echo ${url//RH/redhat}
