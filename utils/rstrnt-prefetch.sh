#!/bin/bash

fetch_url() {
	local uri=$1
	[[ "$uri" = *gitlab ]] && uri=$(echo "$uri"|sed -r 's/(\?.*)?$//')
	if [[ -n "$uri" ]]; then
		echo "{debug} processing '$uri'" >&2
		local urifields=$(parseurl.sh "$uri")
		local host=$(awk '/^host:/{print $2}' <<<"$urifields")
		local path=$(awk '/^path:/{print $2}' <<<"$urifields")
		local fname=${path##*/}
		local rpath="$host/${path%/*}"
		local orig_rpath=$rpath
		local query=$(awk '/^query:/{print $2}' <<<"$urifields")
		local qpath=
		for kv in ${query//&/ }; do
			[[ "$kv" = path=* ]] && { qpath=${kv#path=}; }
		done
		[[ -n "$qpath" ]] && rpath+="/$qpath"

		local downloaddir="/var/cache/nrestraint/fetch-uri/$rpath"
		local extractdir="/mnt/tests/$orig_rpath"

		echo "{debug} downloading '$uri' to '$downloaddir'" >&2
		mkdir -p $downloaddir; rm -rf $downloaddir/$fname
		curl-download.sh $downloaddir "$uri" || rm $downloaddir/$fname

		echo "{debug} extracting to '$extractdir/$fname'" >&2
		extract.sh $downloaddir/$fname $extractdir $fname && touch $extractdir/$fname/fetch.done
	else
		echo "{warn} the invalid url: '$uri'" >&2
	fi
}

for url; do
	fetch_url "$url"
done
