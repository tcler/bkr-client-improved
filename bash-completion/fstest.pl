# fstest.pl(1) completion                                   -*- shell-script -*-

#prog=$(basename $BASH_SOURCE)
prog=fstest.pl

_fstest()
{
    local cur prev words cword
    local narg
    _init_completion || return

    local opts=$( _parse_help "$1" | sed 's/=//g')
    COMPREPLY=( $( compgen -W "$opts" -- "$cur" ) )

    case $prev in
    --tasktag)
        #fix me, hard code
        hosttags="tier1 tier2 tier3 xfs ext4 ext3 ext2 cifs nfs <others>"
        COMPREPLY=( $( compgen -W "$hosttags" -- "$cur" ) )
        ;;
    --taskdir)
        COMPREPLY=( $( compgen -o dirnames  -f -X '!*.txt' -- $cur ) )
        ;;
    --taskfile)
        COMPREPLY=( $( compgen -o filenames  -f  -- $cur ) )
        ;;
    *)
        :;
        ;;
    esac
} &&
complete -F _fstest $prog

#echo $prog
# ex: ts=4 sw=4 et filetype=sh
