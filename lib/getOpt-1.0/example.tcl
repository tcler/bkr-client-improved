#!/bin/sh
# Jianhong Yin <yin-jianhong@163.com>
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec tclsh "$0" ${1+"$@"}

lappend auto_path /usr/local/lib
package require getOpt 1.0
namespace import ::getOpt::*

# global var
array set Opt {}
array set InvalidOpt {}
set NotOptions [list]
set OptionList {
	f	{arg y	help {#Specify a test list file}}
	listf	{arg y	help {#Same as -f}	link f}
	cc	{arg m	help {#Notify additional e-mail address on job completion}}
	kcov	{arg n	help {#insert kcov task for do the kernel test coverage check}}
	kdump	{arg o	help {#insert kdump task for get core dump file if panic happen}}
}

# getUsage test
puts "Usage: $argv0 \[options\]"
puts "Option list:"
getUsage $OptionList

# _parse_ argument
getOptions $OptionList $::argv Opt InvalidOpt NotOptions
parray Opt
parray InvalidOpt
puts "NotOptions: $NotOptions"
