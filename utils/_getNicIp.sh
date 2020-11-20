#!/bin/bash
# author jiyin@redhat.com

P=${0##*/}
#===============================================================================
# get ip addr
getIp() {
  local ret
  local nic=$1
  local ver=$2
  local sc=${3}
  local ipaddr=`ip addr show $nic`;
  [ -z "$sc" ] && {
      sc=global;
      echo "$ipaddr"|grep -q 'inet6.*global' || sc=link;
  }
  local flg='(global|host lo)'

  case $ver in
  6|6nfs)
      ret=`echo "$ipaddr" |
          awk '/inet6.*'$sc'/{match($0,"inet6 ([0-9a-f:]+)",M); print M[1]}'`
      [ -n "$ret" -a $ver = 6nfs ] && ret=$ret%$nic;;
  4|*)
      ret=`echo "$ipaddr" |
          awk '/inet .*'"$flg"'/{match($0,"inet ([0-9.]+)",M); print M[1]}'`;;
  esac

  echo "$ret"
  [ -z "$ret" ] && return 1 || return 0
}

getDefaultNic() {
  local ifs=$(ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1];}')
  for iface in $ifs; do
    [[ -z "$(ip -d link show  dev $iface|sed -n 3p)" ]] && {
      break
    }
  done
  echo $iface
}

getDefaultIp() {
  local nic=`getDefaultNic`
  [ -z "$nic" ] && return 1

  getIp "$nic" "$@"
}

case ${P} in
getIp)
	${P} "$@"
;;
getDefaultNic)
	${P} "$@"
;;
getDefaultIp)
	${P} "$@"
;;
esac

