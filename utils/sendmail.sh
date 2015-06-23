#!/bin/sh
#       filename: msmtp_send
#       Copyright 2010 wkt <weikting@gmail.com>
# modified by yinjianhong, used for send review request mail.
# modified by jiali, add option for cc|to
# modified by yinjianhong, add comment. and if patch is empty not send.

Usage() {
	echo Usage:
	echo -e "\t${0##*/}" '[-t $to@x.com] [-c $cc@x.com] [-p "Prefix"] [-H] <patch|-|+> [subject]'
	exit ${1:-1}
}

TEMP=`getopt -o "::c:t:f:p:H" --long html   -n 'sendmail.sh' -- "$@"`
if [ $? != 0 ] ; then Usage >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"
#===============================================================================
# parse the argument
OPTIND=1
while true ; do
	case $1 in
	-t)		to="$2 $to"; shift 2;;
	-c)		cc="$2 $cc"; shift 2;;
	-f)		from="$2"; shift 2;;
	-p)		prefix="$2"; shift 2;;
	-H|--html)	ctype=html; shift 1;;
	--)		shift; break;;
	*) 		echo "Internal error!"; exit 1;;
	esac
done
[ $# -lt 1 ] && Usage

fpatch=$1
shift
disc=$@

#===============================================================================
mode=$(git remote -v 2>/dev/null|awk '$3=="(fetch)"{print gensub(".*/","",1,$2)}')
# you should need custmize the follow default value:
#to=${to:-fs-qe-dev@redhat.com}
test -z "$prefix" && {
    prefix="[code review] $mode:"
}
test -z "$from" && from=`git config user.email 2>/dev/null`

#===============================================================================
# the config file of smtp
smtp_server=smtp.corp.redhat.com
rc=$(mktemp /tmp/.mailrc.XXXXXXXX)
cat <<___eof_ > ${rc}
defaults
#keepbcc on

###QQ邮箱不支持tls,使用QQ邮箱需要关闭tls_starttls
#tls_starttls off
#tls on

###网易免费企业邮箱的ssl证书通不过验证,所以使用 网易免费企业邮箱 时,只能关闭tls证书验证
#tls_certcheck off

#使用 网易免费企业邮箱 时,需要注释掉tls_trust_file
#tls_trust_file /usr/lib/ssl/certs/ca-certificates.crt

##可以在这里填写邮箱密码,当然这样不是很安全
#password my_password

#auth on
tls_certcheck off
syslog on

account rh
host $smtp_server
from $from
user $from

#设置默认msmtp使用的账号信息
account default : rh
___eof_

#更改配置文件权限,权限不对mstp拒绝干活
chmod og-rwx $rc

#===============================================================================
# proccess the mail file and send.
tm=$(mktemp /tmp/.mail.XXXXXXXX)
[ "$fpatch" = ? ] && Usage 0

[ "$fpatch" = - ] && {
	while read -r l; do echo "$l"; done >$tm
	fpatch=$tm
}
[ "$fpatch" = + ] && {
	[ -z "$cc" ] && {
		echo -n "input the 'to' addr list: "
		read to; }
	[ -z "$to" ] && {
		echo -n "input the 'cc' addr list: "
		read cc; }
	disc="${disc#nfs-utils: }"
	prefix=''

	fpatch=$tm
	vim $fpatch
}
grep -q '[^ \t]' $fpatch || {
	echo "warn: empty mail file. exit no send.";
	exit 1;
}

send() {
	echo "sending ..."
	cat <<__mail_ |msmtp -C $rc $to -t
MIME-Version: 1.0
Content-Type: text/${ctype:-plain}
TO:$to
FROM:$from
CC:$cc
SUBJECT: $prefix${disc}

$(cat $fpatch)


__mail_
}

send
rm -f ${rc} ${tm}

