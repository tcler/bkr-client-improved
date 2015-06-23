#!/bin/bash
# Author: jiyin@redhat.com

TEMP=`getopt -o vt: --long target   -n 'example.bash' -- "$@"`
if [ $? != 0 ] ; then echo "getopt fail, terminating..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"
IDNT="    "

Usage() {
    echo "usage: $0 -t <rpcServUrl> <method> [ {<type:val> | <struct:B <name:type:value> ... struct:E>} ... ]"
    echo "  eg1: $0 -t http://www.abook.com/rpcserv search_book string:linux int:2009"
    echo "  eg2: $0 -t http://www.bbook.com/rpcserv search_dock string:dock  \"struct:B mem1:int:8 mem2:int:32 struct:E\""
    exit 1
}
simpleArg() {
    local arg="$1"
    local type=${arg%%:*} val=${arg#*:}
    local indent=$indent

    echo -e "${indent}<param><value><$type>$val</$type></value></param>"
}
structMember() {
    local arg="$1"
    local name=${arg%%:*} val=${arg#*:}
    local type=${val%%:*} val=${val#*:}
    local indent=$indent

    echo -e "${indent}<member>"
    echo -e "${indent}${IDNT}<name>$name</name>"
    echo -e "${indent}${IDNT}<value><$type>$val</$type></value>"
    echo -e "${indent}</member>"
}
structArg() {
    local args="$1"
    local deep=0

    local cindent="${indent}"
    local nindent="${cindent}${IDNT}"
    echo -e "${cindent}<param>\n${cindent}${IDNT}<value>"
    eval set -- $args
    for _arg; do
        shift
        case $_arg in
        struct:B*)
            ((deep > 0)) && echo -e "${nindent}<member>"
            local name=${_arg#struct:B}
            [ -n "$name" ] && echo -e "${nindent}${IDNT}<name>${name#:}</name>"
            echo -e "${nindent}${IDNT}<struct>"
            indent="${nindent}${IDNT}${IDNT}"
            nindent="${nindent}${IDNT}${IDNT}"
            ((deep++))
            ;;
        struct:E)
            indent=${indent%$IDNT$IDNT}
            nindent=${nindent%$IDNT$IDNT}
            echo -e "${nindent}${IDNT}</struct>"
            ((--deep > 0)) && echo -e "${nindent}</member>"
            ;;
        *)
            structMember "$_arg"
            ;;
        esac
    done
    echo -e "${cindent}${IDNT}</value>\n${cindent}</param>"
}

while true ; do
    case "$1" in
    -t|--target) servUrl=$2; shift 2;;
    -v) verbose=--verbose; shift;;
    --) shift; break;;
    *) echo "Internal error!"; exit 1;;
    esac
done
[ -z "$servUrl" ] && Usage
[ $# -lt 1 ] && Usage

#<method> <arg1> <arg2> ... <argx>
generateRequestXml() {
    method=$1; shift
    echo '<?xml version="1.0"?>'
    echo "<methodCall>"
    echo "    <methodName>$method</methodName>"
    echo "    <params>"

    indent="${IDNT}${IDNT}"
    for arg; do
        case $arg in
        struct:B*)  structArg "$arg";;
        *)          simpleArg "$arg";;
        esac
    done

    echo "    </params>"
    echo "</methodCall>"
}

rpcxml=rpc$$.xml
generateRequestXml "$@" > $rpcxml
[ "$verbose" = "--verbose" ] && cat "$rpcxml"
curl $verbose --data "@$rpcxml" "$servUrl" 2>/dev/null | xmllint --format -
\rm -f $rpcxml

# format
true <<COMM
        <param>
            <value>
                <struct>
                    <member>
                        <name>Channel</name>
                        <value><string>1ee246fc-e60d-2fd3-6242-f5fc! 5d19850f</string></value>
                    </member>
                    <member>
                        <name>IntValue</name>
                        <value><int>42</int></value>
                    </member>
                    <member>
                        <name>StringValue</name>
                        <value><string>Hello, world!</string></value>
                    </member>
                </struct>
            </value>
        </param>
COMM

