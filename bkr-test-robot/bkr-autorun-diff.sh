#!/bin/bash
# this is a prototype about diff two test run

dialogres=.$$.res
eval dialog --backtitle "Checklist" --checklist "Test" 30 120 28  $(bkr-autorun-stat -r|sed 's/.*/"&" "" 1/')  2>$dialogres
oIFS=$IFS; IFS=$'\n' runs=($(eval set -- $(< $dialogres); for v; do echo "$v"; done)); IFS=$oIFS
rm -f $dialogres

echo ${runs[0]}
echo ${runs[1]}

vimdiff <(eval bkr-autorun-stat --lsres ${runs[0]}) <(eval bkr-autorun-stat --lsres ${runs[1]})
