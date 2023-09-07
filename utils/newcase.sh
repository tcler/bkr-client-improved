#!/bin/bash
#
# Author: jiyin@redhat.com

Usage() {
cat <<END
Usage: $0 [other options] <casedir>
	<casedir>               #path/dir
	-c <component>          #component
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
_at=`getopt -o c:d:m::l:t:h \
	--long time: \
	--long desc: \
	--long help \
    -n 'newcase.sh' -- "$@"`
eval set -- "$_at"

while true; do
	case "$1" in
	-c)		component=${2}; shift 2;;
	-m)		multihost=${2:-1,1}; shift 2;;
	-l)		level=$2; shift 2;;
	-t)		type="${2//,/ }"; shift 2;;
	--time)		time="$2"; shift 2;;
	-d|--desc)	desc="$2"; shift 2;;
	-h|--help)	Usage; shift 1; exit 0;;
	--) shift; break;;
	esac
done

level=${level:-tier1}
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

gitroot() { local d=$(readlink -f ${1:-.}); while :; do d=${d%/*}; test -d $d/.git && { echo $d; break; } done; }

#create the case dir, and cd ..
echo "create case dir: $dir/$basedir"
mkdir -p "$dir/$basedir"
pushd "$dir/$basedir" &>/dev/null
#-------------------------------------------------------------------------------

#get the user.name and user.email info
name=`git config user.name`
mail=`git config user.email`
owner="$name <$mail>"
reporoot=$(gitroot)
reponame=${reporoot##*/}
rpath=${PWD/${reporoot//\//?}?/}
taskname=/${reponame%.git}/$rpath

gen_metadata() {
echo "create $dir/$basedir/metadata"
cat >metadata <<EOF
[General]
name=$taskname
component=${component:-${reponame%.git}}
owner=$owner
description=${desc:-test for: $base}
priority=${level}
license=GPL v2
topo=${topo:-singleHost}
confidential=no
destructive=no

entry_point=bash runtest.sh
softDependencies=vim;tmux
repoRequires=Library/base
max_time=${time:-16m}
no_localwatchdog=true
EOF
}

gen_runtest() {
echo "create $dir/$basedir/runtest.sh"
cat >runtest.sh <<EOF
#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Description: ${desc:-test for: $base}
#   Author: $owner
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
rlImport kernel/base &> >(grep INFO)
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
#Specify the exit code if you need
trap "cleanup; exit" EXIT
cleanup() {  #fix me: add more cleanup action
	#rlFileRestore   #restore changed file/dir
	: #rm -rf \$expdir \$nfsmp   #remove added dir/file
}

#global var define
$(
if [ -n "$multihost" ]; then
	echo 'BZ=bugid  #suffix to show distinction with other cases'
else
	echo 'BZ=bugid-$RANDOM  #suffix to show distinction with other cases

#standard env variable from $ENV_FILE or case parameters
#MOUNT_TARGET
#MOUNT_OPTS
#VERS_LIST
if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
	source "$ENV_FILE"
else
	MOUNT_TARGET=${MOUNT_TARGET:-$HOSTNAME:$expdir}
fi'

fi
)

$(if test -z "$multihost"; then
  echo 'rlJournalStart
rlPhaseStartSetup do-Setup-
	expdir=/exportdir-$BZ #fix me:
	nfsmp=/mnt/nfsmp-$BZ  #fix me:
	run "mkdir -p $expdir $nfsmp"
	run '"'echo \"\$expdir *(rw,no_root_squash)\" >/etc/exports'"'
	run '"'service_nfs restart'"'
	nfsvers=$NFS_VERS
	[ -z "$nfsvers" ] && nfsvers=$(ls_nfsvers)
rlPhaseEnd

for V in ${VERS_LIST:-$nfsvers}; do
rlPhaseStartTest do-Test-
	run '"'mount \$MOUNT_OPTS -overs=\$V \$MOUNT_TARGET \$nfsmp'"'
rlPhaseEnd
done

rlPhaseStartCleanup do-Cleanup-
	rlFileRestore
rlPhaseEnd
rlJournalEnd'

else

  sflist=$(for i in $(seq 1 $ServNum); do [[ $i = 1 ]] && i=;echo Server$i; done)
  cflist=$(for i in $(seq 1 $ClntNum); do [[ $i = 1 ]] && i=;echo Client$i; done)
  for f in $sflist; do
    #[[ "$f" =~ (Server|Client)$ ]] && continue
    echo "$f() {"
    echo 'rlPhaseStartSetup do-$role-Setup-
	expdir=/exportdir-$BZ #fix me:
	run "mkdir -p $expdir"
	run '"'echo \"\$expdir *(rw,no_root_squash)\" >/etc/exports'"'
	run '"'service_nfs restart'"'
rlPhaseEnd

rlPhaseStartTest do-$role-Test-
	run '"'rhts-sync-set -s servReady'"'
	run '"'rhts-sync-block -s testDone \$CLIENT'"'  #fix me
rlPhaseEnd

rlPhaseStartCleanup do-$role-Cleanup-
	rlFileRestore
rlPhaseEnd'
    echo "}"
  done
  echo
  for f in $cflist; do
    #[[ "$f" =~ (Server|Client)$ ]] && continue
    echo "$f() {"
    echo 'rlPhaseStartSetup do-$role-Setup-
	nfsmp=/mnt/nfsmp-$BZ  #fix me:
	run "mkdir -p $nfsmp"
	nfsvers=$NFS_VERS
	[[ -n "$SERVER" ]] && {
		run '"'rhts-sync-block -s servReady \$SERVER'"'  #fix me
		nfsvers=$(ls_nfsvers $SERVER)
	}
	run "test -n '"'\$nfsvers'"'"
	MOUNT_TARGET=$SERVER:$expdir
rlPhaseEnd

for V in ${VERS_LIST:-$nfsvers}; do
rlPhaseStartTest do-$role-Test-
	run '"'mount \$MOUNT_OPTS -overs=\$V \$MOUNT_TARGET \$nfsmp'"'
rlPhaseEnd
done

rlPhaseStartCleanup do-$role-Cleanup-
	[[ -n "$SERVER" ]] && run '"'rhts-sync-set -s testDone'"'  #fix me
	rlFileRestore
rlPhaseEnd'
    echo "}"
  done
  echo
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

gen_metadata
gen_runtest
gen_purpose
