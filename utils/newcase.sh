#!/bin/bash
#
# Author: jiyin@redhat.com

Usage() {
cat <<END
Usage: $0 [other options] <casedir>
	<casedir>               #path/dir
	-m [ServNum,ClntNum]    #multihost machines number
	-l <0|1|2|...>          #Tier/level specify(default 1)
	-t <type1[,type2,...]>  #type: function/regression/stress
	--time <time>           #max run time(default 30m)
	--desc <desc>           #a description of the case
	-h|--help               #get this help info
END
}

# __main__
# argument process
_at=`getopt -o d:m::l:t:h \
	--long time: \
	--long desc: \
	--long help \
    -n 'newcase.sh' -- "$@"`
eval set -- "$_at"

while true; do
	case "$1" in
	-m)             multihost=${2:-1,1}; shift 2;;
	-l)		level=$2; shift 2;;
	-t)		type="${2//,/ }"; shift 2;;
	--time)		time="$2"; shift 2;;
	--desc)		desc="$2"; shift 2;;
	-h|--help)      Usage; shift 1; exit 0;;
	--) shift; break;;
	esac
done

level=${level:-1}
casedir="$*"
test -z "$casedir" && { Usage >&2; exit 1; }
test -n "$multihost" && read ServNum ClntNum nil <<<"${multihost//[.,]/ }"

#create the case dir
dir=$(dirname "$casedir")
base=$(basename "$casedir")
basedir=$(echo "$base"|sed 's/[^_a-zA-Z0-9]/-/g')
test -z "$type" && {
	type=regression
	[[ "$dir" =~ [Ff]unction ]] && type=function
	[[ "$dir" =~ [Ss]tress ]] && type=stress
}

#create the case dir, and cd ..
echo "create case dir: $dir/$basedir"
mkdir -p "$dir/$basedir"
pushd "$dir/$basedir" &>/dev/null
#-------------------------------------------------------------------------------

#get the user.name and user.email info
name=`git config user.name`
mail=`git config user.email`

gen_makefile() {
echo "create $dir/$basedir/Makefile"
cat >Makefile <<EOF
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Description: ${desc:-test for: $base}
#   Author: $name <$mail>
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) $(date +%Y) Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#Generate and export TEST= PACKAGE=
TENV=_env
ifeq (\$(PKG_TOP_DIR),)
    export PKG_TOP_DIR := \$(shell p=\$\$PWD; while :; do \\
        [ -e \$\$p/env.mk -o -z "\$\$p" ] && { echo \$\$p; break; }; p=\$\${p%/*}; done)
    export _TOP_DIR := \$(shell p=\$\$PWD; while :; do \\
        [ -d \$\$p/.git -o -z "\$\$p" ] && { echo \$\$p; break; }; p=\$\${p%/*}; done)
    -include \$(PKG_TOP_DIR)/env.mk
endif
include \$(TENV)
ifeq (\$(_TOP_DIR),)
    _TOP_DIR=/mnt/tests/\$(TOPLEVEL_NAMESPACE)
endif
#===============================================================================
export TESTVERSION=1.0

BUILT_FILES=
FILES=\$(TENV) \$(METADATA) runtest.sh Makefile PURPOSE

.PHONY: all install download clean

run: \$(FILES) build
	( set +o posix; . /usr/bin/rhts-environment.sh || exit 1; \\
. /usr/share/beakerlib/beakerlib.sh || exit 1; \\
. runtest.sh )

build: \$(BUILT_FILES)
	test -x runtest.sh || chmod a+x runtest.sh

clean:
	rm -f *~ \$(BUILT_FILES)

include /usr/share/rhts/lib/rhts-make.include

\$(METADATA): Makefile
	@echo "Owner:           $name <$mail>" > \$(METADATA)
	@echo "Name:            \$(TEST)" >> \$(METADATA)
	@echo "TestVersion:     \$(TESTVERSION)" >> \$(METADATA)
	@echo "Path:            \$(TEST_DIR)" >> \$(METADATA)
	@echo "Description:     ${desc:-test for: $base}" >> \$(METADATA)
	@echo "Type:            ${type}" >> \$(METADATA)
	@echo "Type:            \$(PACKAGE)-level-tier${level/[Tt]ier/}" >> \$(METADATA)
	@echo "TestTime:        ${time:-30m}" >> \$(METADATA)
	@echo "RunFor:          \$(PACKAGE)" >> \$(METADATA)
	@echo "Requires:        \$(PACKAGE)" >> \$(METADATA)
	@echo "Priority:        Normal" >> \$(METADATA)
	@echo "License:         GPLv2" >> \$(METADATA)
	@echo "Requires:	library(kernel/base)" >> \$(METADATA)
	@echo "Requires:	nfs-utils autofs" >> \$(METADATA)
	@echo "Requires:	wireshark tcpdump net-tools" >> \$(METADATA)
	@echo "Requires:	procmail sssd sssd-client" >> \$(METADATA)
	@echo "RhtsRequires:	library(kernel/base)" >> \$(METADATA)
	rhts-lint \$(METADATA)
EOF
}

gen_runtest() {
echo "create $dir/$basedir/runtest.sh"
cat >runtest.sh <<EOF
#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Description: ${desc:-test for: $base}
#   Author: $name <$mail>
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) $(date +%Y) Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Load beakerlib you needed
rlImport kernel/base
envinfo
#disable_avc_check$(test -n "$multihost" && {
  echo -e "\n"
  echo '##define for multiHost'
  echo 'echo -e "\n"s{$SERVERS} c{$CLIENTS}'
  echo "ServerNeed=$ServNum  ClientNeed=$ClntNum"
  echo
  clist=$(for i in $(seq 1 $ClntNum); do [[ $i = 1 ]] && i=;echo CLIENT$i; done)
  slist=$(for i in $(seq 1 $ServNum); do [[ $i = 1 ]] && i=;echo SERVER$i; done)
  eval echo read $clist "'nil  <<<\${CLIENTS}'"
  eval echo read $slist "'nil  <<<\${SERVERS}'"
  echo 'role=server; echo "$CLIENTS" | grep -q "$HOSTNAME" && role=client'
  echo '#-----------------------------------------------------------------------'
  echo '#set_ssh_without_passwd'
})
#===============================================================================

#signal trap
trap "cleanup" SIGINT SIGTERM SIGHUP SIGQUIT  #fix me: add more signal name
cleanup() {  #fix me: add more cleanup action
	rlFileRestore   #restore changed file/dir
	rm -rf \$expdir \$nfsmp   #remove added dir/file
}

#global var define
$(if [ -n "$multihost" ]; then
    echo 'BZ=bugid  #suffix to show distinction with other cases'
  else
    echo 'BZ=bugid-$RANDOM  #suffix to show distinction with other cases'
  fi
)
expdir=/exportdir-\$BZ #fix me:
nfsmp=/mnt/nfsmp-\$BZ  #fix me:

$(if test -z "$multihost"; then
  echo 'rlJournalStart
    rlPhaseStartSetup do-Setup-
	rlFileBackup /etc/exports /etc/sysconfig/nfs
	rlFileBackup /etc/auto.master /etc/sysconfig/autofs
    rlPhaseEnd

    rlPhaseStartTest do-Test-
    rlPhaseEnd

    rlPhaseStartCleanup do-Cleanup-
	rlFileRestore
    rlPhaseEnd
rlJournalEnd'
else
  flist=$(for i in $(seq 1 $ServNum); do [[ $i = 1 ]] && i=;echo Server$i; done
          for i in $(seq 1 $ClntNum); do [[ $i = 1 ]] && i=;echo Client$i; done)
  for f in $flist; do
    #[[ "$f" =~ (Server|Client)$ ]] && continue
    echo "$f() {"
    echo '    rlPhaseStartSetup do-$role-Setup-
	rlFileBackup /etc/exports /etc/sysconfig/nfs
	rlFileBackup /etc/auto.master /etc/sysconfig/autofs
    rlPhaseEnd

    rlPhaseStartTest do-$role-Test-
	run "rhts-sync-set -s <eventName>" #fix me:
	run "rhts-sync-block -s <eventName> <hostname ...>" #fix me:
    rlPhaseEnd

    rlPhaseStartCleanup do-$role-Cleanup-
	rlFileRestore
    rlPhaseEnd'
    echo "}"
  done
  echo 'rlJournalStart'
  echo 'case "$HOSTNAME" in'
  hlist=$(for i in $(seq 1 $ServNum); do [[ $i = 1 ]] && i=;echo \$SERVER$i; done
          for i in $(seq 1 $ClntNum); do [[ $i = 1 ]] && i=;echo \$CLIENT$i; done)
  for h in $hlist; do
    #[[ "$h" =~ (SERVER|CLIENT)$ ]] && continue
    echo "	$h) $(echo ${h}|sed -e s/.SERVER/Server/ -e s/.CLIENT/Client/);;"
  done
  echo '	*) :;; esac'
  echo 'rlJournalEnd'
fi
)
#rlJournalPrintText
#enable_avc_check
EOF
}

gen_purpose() {
echo "create $dir/$basedir/PURPOSE"
cat >PURPOSE <<EOF
# nothing
EOF
}

gen_makefile
gen_runtest
gen_purpose
make testinfo.desc
