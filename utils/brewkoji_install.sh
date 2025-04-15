#!/bin/bash
#author jiyin@redhat.com

switchroot() {
	local P=$0 SH=; [[ $0 = /* ]] && P=${0##*/}; [[ -e $P && ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;4m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}
switchroot "$@"

installBrew2() {
	#https://mojo.redhat.com/docs/DOC-1024827
	#https://docs.engineering.redhat.com/display/RCMDOC/RCM+Tools+Release+Guide
	urls="
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-7-server.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-7-client.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-7-workstation.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-8-baseos.repo
	curl -L -O https://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-9-baseos.repo
	curl -L -O https://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-10-baseos.repo
	curl -L -O https://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-fedora.repo
	"

	local verx=$(rpm -E %rhel)

	pushd /etc/yum.repos.d
	baseUrl=http://download.devel.redhat.com/rel-eng
	curl -L $baseUrl -s | grep -q 404 && baseUrl=http://download.eng.pek2.redhat.com/rel-eng
	if [[ $(rpm -E %rhel) != %rhel ]]; then
		case $verx in
		# https://docs.engineering.redhat.com/pages/viewpage.action?spaceKey=RCMDOC&title=RCM+Tools+Release+Guide
		[7])
			type=Workstation
			pkglist='koji brewkoji'
			;;
		8|9|10)
			type=BaseOS
			pkglist='python3-brewkoji brewkoji python3-pycurl'
			;;
		esac
		repourl=$baseUrl/RCMTOOLS/latest-RCMTOOLS-2-RHEL-$verx/compose/$type/$(uname -m)/os
		cat <<-EOF >/etc/yum.repos.d/rcm-tools-2.repo
		[rcm-tools]
		name=RCM TOOLS 2
		baseurl=$repourl
		enabled=1
		skip_if_unavailable=1
		gpgcheck=0
		EOF
		# python3.12dist, python3-requests-gssapi need by other repo
		if [[ $verx == 10 ]]; then
			local disanblerepo=''
		else
			local disanblerepo='--disablerepo=*'
		fi
		if ! yum install --setopt=sslverify=0 ${disanblerepo} --enablerepo=rcm-tools -y $pkglist ;then
			rm rcm-tools-*.repo
			#fixme: remove this if branch after rhel-10/rcmtools is available
			if [[ "$verx" = 10 ]]; then
				urlpath=${baseUrl/rhel-10/rhel-9}/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-RHEL-9/compose/BaseOS/x86_64/os/Packages
				yum install -y python3-requests
				rpm -ivh --force --nodeps \
					${urlpath}/{python3-brewkoji-1.31-1.el9.noarch.rpm,brewkoji-1.31-1.el9.noarch.rpm}
			fi

			#install kojo
			[[ $verx -ge 8 ]] && {
				_verx=$verx
				#fixme: remove this line after rhel-10/rcmtools is available
				[[ "$verx" = 10 ]] && _verx=9
				urlpath=https://kojipkgs.fedoraproject.org/packages/koji/1.34.0/3.el${_verx}/noarch
				rpm -ivh --force --nodeps \
					${urlpath}/{koji-1.34.0-3.el${_verx}.noarch.rpm,python3-koji-1.34.0-3.el${_verx}.noarch.rpm}
			}

			#fixme: remove this line after rhel-10/rcmtools is available
			[[ "$verx" = 10 ]] && cp -rf /usr/lib/python3.9/site-packages/* /usr/lib/python3.12/site-packages/.
		fi
	elif [[ $(rpm -E %fedora) != %fedora ]]; then
		curl -L -O https://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-fedora.repo
		yum install --setopt=sslverify=0 -y koji brewkoji || rm rcm-tools-*.repo
	fi
	popd

	which brew &>/dev/null
}

# fix ssl certificate verify failed
# https://certs.corp.redhat.com/ https://docs.google.com/spreadsheets/d/1g0FN13NPnC38GsyWG0aAJ0v8FljNDlqTTa35ap7N46w/edit#gid=0
(cd /etc/pki/ca-trust/source/anchors && curl -Ls --remote-name-all https://certs.corp.redhat.com/{2022-IT-Root-CA.pem,2015-IT-Root-CA.pem,ipa.crt,mtls-ca-validators.crt,RH-IT-Root-CA.crt,ipa-ca-chain-2022.crt} && update-ca-trust)

# install koji & brew
which brew &>/dev/null || {
	OSV=$(rpm -E %rhel)
	if ! grep -E -q '^!?epel' < <(yum repolist 2>/dev/null); then
		[[ "$OSV" != "%rhel" ]] && yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSV}.noarch.rpm 2>/dev/null
		[[ -f /etc/yum.repos.d/epel.repo ]] && sed -i -e '/^\s*skip_if_unavailable\s*=/d' -e '/^\s*enabled\s*=\s*1\s*$/a skip_if_unavailable=1'  /etc/yum.repos.d/epel.repo
		[[ -f /etc/yum.repos.d/epel-testing.repo ]] && sed -i -e '/^\s*skip_if_unavailable\s*=/d' -e '/^\s*enabled\s*=\s*1\s*$/a skip_if_unavailable=1'  /etc/yum.repos.d/epel-testing.repo
	fi
	yum --setopt=strict=0 --setopt=sslverify=0 install -y koji python3-koji python3-pycurl brewkoji coreutils
}
which brew &>/dev/null || installBrew2
which brew &>/dev/null || yum install --setopt=sslverify=0 -y bash-completion-brew

which brew || echo "install brew failed!!!"
rm -rf /etc/yum.repos.d/rcm-tools-*.repo
