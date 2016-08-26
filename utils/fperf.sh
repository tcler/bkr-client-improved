#!/bin/bash
# yin-jianhong@163.com

export LANG=C
f=$1
iotype=${2:-r}
ddargs=${3}

case $iotype in
r*|R*)
	#[[ -n "$f" && -f "$f" && -r "$f" ]] || {
	[[ -n "$f" && -r "$f" ]] || {
		echo "'$f' is not a regular file or no read permission" >&2
		exit 1
	}

	ddinfo=$(LANG=C dd if="$f"  of=/dev/null $ddargs 2>&1)
	read B _a _b _c _d S _y _z < <(echo "$ddinfo" | tail -n1)
	;;
*)
	[[ -n "$f" ]] || {
		echo "Usage: prog <file> r [ddargs]" >&2
		echo "Usage: prog <file> w [ddargs]" >&2
		exit 1
	}

	[[ -f "$f" ]] || rmflag=1
	[[ -z "$ddargs" ]] || ddargs="bs=1M count=500"

	ddinfo=$(LANG=C dd if=/dev/zero  of="$f" $ddargs 2>&1)
	read B _a _b _c _d S _y _z < <(echo "$ddinfo" | tail -n1)

	[[ "$rmflag" == 1 ]] && rm -f "$f"
	;;
esac

echo "$ddinfo" >&2
awk "BEGIN{print int($B/$S)}"

