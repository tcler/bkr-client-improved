########################################################################
#
#  xmlgen -- generate XML by writing Tcl code
#
# (C) 2002 Harald Kirsch
#
# $Revision: 1.9 $, $Date: 2002/09/21 14:55:55 $
########################################################################
namespace eval ::xmlgen {

  namespace export buffer channel declaretag esc put doTag \
      setTagformat declaretags
  
  ## will be elongated and trimmed back by (recursive) calls to doTag,
  ## i.e. by tag-procs. However, it is only used by makeTagAndBody.
  variable indent ""

  ## a regular expression used by makeTagAndBody to identify
  ## tag-arguments which are attribute-value pairs as well as to
  ## dissect them into these two parts. The attribute name must match
  ## the definition of 'Name' found in the XML spec:
  ##    http://www.w3c.org/TR/2000/REC-xml-20001006#NT-Name
  ## 'CombiningChar' and 'Extender' are not yet considered.
  variable attrre {^ *([A-Za-z_:][a-zA-Z0-9_.:-]*)=(.*)}

  ## A pattern used with [string match] to check if the first body
  ## argument of a markup proc is a control character which describes
  ## how to handle the body.
  ## jiyin@redhat.com add '_<cC' controlchar 2014-12-13
  set controlchars {[-_!<cC+.]}

  ## The following array specifies how to format the output. For every
  ## control character listed above it tells us what to put in front
  ## of the open and close tags --- typically a newline and some
  ## indentation. Note that the respective strings are ran through
  ## [subst] in order to expand references to $indent. Consequently
  ## you must be careful to put other Tcl special characters into the
  ## string.
  array set tagformat {
    -o {\n$indent$tag}        -c {$tag}
    _o {\n$indent<!--$tag}    _c {$tag-->}

    !o {\n$indent$tag}        !c {\n$indent$tag}
    co {\n$indent<!--$tag-->} cc {\n$indent<!--$tag-->}
    Co {\n$indent<!--$tag}    Cc {\n$indent$tag-->}
    <o {}                     <c {}

    +o {\n$indent$tag}        +c {\n$indent$tag}
    .o {$tag}                 .c {$tag}
  }

  ## Output normally goes just to stdout, but proc buffer may be used
  ## to generate a context in which output is appended to this
  ## variable. 
  ## NOTE: this is not thread-save if two threads operate in the same
  ## interpreter. 
  variable buffer ""

  ## We want to replace the original puts by our own implementations
  ## depending on context. However, we need of course the original
  ## somewhere, so we keep it as tclputs. Then, initially, we make the
  ## "normal" ::puts an alias for the saved proc.

  ## EAS: This is very confusing and didn't work on my system
  ## Left the original TCL puts alone and called our proc "putx" instead
  # rename ::puts ::xmlgen::tclputs
  # HK: no put, use just [put] for redirectable and channelable output.
  #interp alias {} ::putx   {}  ::xmlgen::putx

  ## The main output-generating function is [put]. In contrast to puts
  ## it takes several arguments which are simply [join]ed and no
  ## newline is automatically appended. When called in the context of
  ## [buffer] or [channel], the output is redirected either to a
  ## variable or another output channel than stdout respectively. The
  ## default is output to stdout.
  interp alias {} ::xmlgen::put   {} ::xmlgen::putStream stdout
}

proc ::xmlgen::putx-no-longer-needed-use-just-put {args} {
    set i 0
    if { "-nonewline" == [lindex $args $i] } {
        set nl ""
        incr i
    } else {
        set nl \n
    }

    ## If there are still two args, the first is supposed to be an
    ## explicit output channel and we leave it to the original puts to
    ## handle that.
    if { [llength $args]-$i != 1 } {
        eval puts $args
        return
    }
    variable buffer
    append buffer [lindex $args $i] $nl

    return
}
  
## A version of [put] used when collecting output in a buffer.
proc ::xmlgen::putBuf {args} {
  variable buffer
  
  append buffer [join $args]
  return
}

## A version of [put] used when printing to a channel.
proc ::xmlgen::putStream {channel args} {
  puts -nonewline $channel [join $args]
  return
}

## Arranges for further output to be appended to variable bufname
## instead of being sent automatically to stdout
proc ::xmlgen::buffer {bufname body} {
  ## save the current buffer locally
  variable buffer
  set keptBuffer $buffer
  set buffer {}

  ## stack the current redirection
  set keptPut [interp alias {} ::xmlgen::put]

  ## redirect [put]
  ## FIXME: Is it really necessary to work with the namespace-variable
  ## buffer to collect the output or could we do something like 
  ##    interp .... {} xmlgen::putBuf $bufname
  ## Probably not, because then $bufname could not refer to a local
  ## variable of the calling function.
  interp alias {} ::xmlgen::put  {} ::xmlgen::putBuf

  ## run the body safely
  set err [catch {uplevel 1 $body}]
  
  ## Restore [put]
  eval interp alias {{}} ::xmlgen::put  {{}} $keptPut

  ## copy the collected buffer to the requested var and restore the
  ## previous buffer
  upvar $bufname b
  set b $buffer
  set buffer $keptBuffer
  if {$err} {
    return -code error -errorinfo $::errorInfo
  }
  
  return
}

proc ::xmlgen::channel {chan body} {
  ## stack the current redirection
  set keptPut [interp alias {} ::xmlgen::put]

  ## redirect [put]
  interp alias {} ::xmlgen::put  {} ::xmlgen::putStream $chan

  ## run the body safely
  set err [catch {uplevel 1 $body}]
  
  ## Restore [put]
  eval interp alias {{}} ::xmlgen::put  {{}} $keptPut

  if {$err} {
    return -code error -errorinfo $::errorInfo
  }
  
  return
}

## See manual page for description of this function.
proc ::xmlgen::makeTagAndBody {tagname l {specialAttributes {}} } {
  variable attrre
  variable indent
  variable controlchars

  ## If specialAttributes is set, we put those attributes into the
  ## array instead of assembling them into the tag.
  if {"$specialAttributes"==""} {
    array set sAttr {}
  } else {
    upvar $specialAttributes sAttr
  }
  
  ## Collect arguments as long as they look like attribute-value
  ## pairs, i.e. as long as they match $attrre.
  ## As a convenience, an argument which is the empty string is simply
  ## ignored. This allows optional, auto-generated attributes to be
  ## empty and skipped like in 
  ##    if {...} {set align ""} else {set align "align=center"}
  ##    p $align - {Some text, sometimes centered}
  ## If $align=="", it will not stop attribute processing.
  ##
  set opentag "<$tagname"
  set L [llength $l]
  for {set i 0} {$i<$L} {incr i} {
    set arg [lindex $l $i]
    if {""=="$arg"} continue
    if {![regexp $attrre $arg -> attr value]} break
    if {[info exists sAttr($attr)] || ""=="$tagname"} {
      set sAttr($attr) $value
    } else {
      append opentag " $attr=\"[esc $value]\""
    }
  }
  
  ## If there is at least one element left in $l, the first element of
  ## $l is already stored in arg. It could be the argument controlling
  ## how to handle the body.
  set haveControl 0;			# see safety belt below
  set control .
  if {$i<$L} {
    if {[string match $controlchars $arg]} {
      set control $arg
      incr i
      set haveControl 1
    } elseif {[string length $arg]==1} {
      append emsg \
	  " starting the body with a single character is not allowed " \
	  "in order to guard against bugs"
      return -code error $emsg
    }
  }
  
  ## If there are elements left in $l they are joined into the
  ## body. Otherwise the body is empty and opentag and closetag need
  ## special handling.
  if {$i<$L} {
    set body [lrange $l $i end]
    if 0 {
      ## If the body is a one-element list, we unpack one list
      ## level. Otherwise we are most likely on a continued line like
      ## table ! tr ! td bla
      ## where the body of e.g. table has already several elements
      if {[llength $body]==1} {set body [lindex $body 0]}
    } else {
      set body [join $body]
    }
    append opentag ">"
    set closetag "</$tagname>"

    ## Do some indenting.
    set opentag [formatTag ${control}o $indent $opentag]
    set closetag [formatTag ${control}c $indent $closetag]
        
  } else {
    ## Leave a space in front of "/>" for being able to use XHTML
    ## with most HTML-browsers
    set body {}
    ## added by jiyin@redhat.com
      set opentag [formatTag ${control}o $indent $opentag]
    append opentag " />"
    set closetag ""
  }
  
  ## Put on the safety belt. If we did not have a control character
  ## and the body starts with a blank line, the author most probably
  ## just forgot the control character.
  if {!$haveControl && [regexp "^\[\t \]*\n" $body]} {
    append msg \
	"body starts with newline but no control " \
	"character was given:"
    set b [split $body \n]
    if {[llength $b]>3} {
      append msg [join [lrange $b 0 3] \n] "  ..."
    } else {
      append msg $body
    }
    return -code error $msg
  }
  
  return [list $opentag $control $body $closetag]
}
########################################################################
## With the help of variable tagformat we put some indentation in
## front of a tag to make the output look nicer.
proc ::xmlgen::formatTag {which indent tag} {
  variable tagformat
  return [subst $tagformat($which)]
}
########################################################################
##
## Sets an element of variable tagformat in a controlled way, i.e. we
## test if the array index 'which' makes sense.
##
proc ::xmlgen::setTagformat {which format} {
  variable tagformat
  variable controlchars
  if {![regexp "$controlchars\[oc\]" $which]} {
    return -code error \
	"the string `$which' is not a valid target to format"
  }
  set tagformat($which) $format
}
########################################################################
## Evaluate, substitute and print or just return the body
## enclosed in the given opentag and closetag.
proc ::xmlgen::runbody {opentag control body closetag} {

  switch -exact -- $control {
    "<" {
      uplevel 1 $body
    }
    "C" -
    "c" -
    "!" {
      variable indent
      set ind $indent
      append indent {    }
      uplevel 1 [list ::xmlgen::put $opentag]
      uplevel 1 $body
      uplevel 1 [list ::xmlgen::put $closetag]
      set indent $ind
    }
    "+" {
      set body [string trim $body "\n \t"]
      uplevel 1 [list ::xmlgen::put $opentag]
      uplevel 1 "::xmlgen::put \[subst {$body}\]"
      uplevel 1 [list ::xmlgen::put $closetag]
    }
    "_" -
    "-" {
      set body [string trim $body "\n \t"]
      uplevel 1 [list ::xmlgen::put $opentag]
      uplevel 1 [list ::xmlgen::put $body]
      uplevel 1 [list ::xmlgen::put $closetag]
    }
    "." {
      return "$opentag$body$closetag"
    }
    default {
      return -code error "unknown control string `$control'"
    }
  }
  
  return
}
########################################################################
  

## Generic function to handle a tag-proc and its arguments.
proc ::xmlgen::doTag {tagname args} {
  variable tagAndBodyProc
  
  foreach {opentag control body closetag} \
      [makeTagAndBody $tagname $args] break
  
  set result [uplevel 1 [list ::xmlgen::runbody $opentag \
			     $control $body $closetag]]

  return $result
}

## Makes a tagname into a tag-proc by making it into an alias for
## doTag.
proc ::xmlgen::declaretag {funcname {tagname {}}} {
  if {"$tagname"==""} {
    set tagname $funcname
  }
  set ns [string trimright [uplevel 1 "namespace current"] :]
  interp alias {} [set ns]::$funcname   {} ::xmlgen::doTag $tagname
  
  return
}
# added by jiyin@redhat.com
proc ::xmlgen::declaretags {args} {
  foreach tagname $args {
    set ns [string trimright [uplevel 1 "namespace current"] :]
    set funcname $tagname
    interp alias {} [set ns]::$funcname   {} ::xmlgen::doTag $tagname
  }
 
  return
}

## Convert text so that it is safe to use it as an attribute value
## surrouned by double quotes as well as character data. See the
## definition of AttValue and CharData:
## http://www.w3c.org/TR/2000/REC-xml-20001006#NT-AttValue
## http://www.w3c.org/TR/2000/REC-xml-20001006#NT-CharData
proc ::xmlgen::esc {args} {
  regsub -all "&" [eval concat $args] "\\&amp;" args
  regsub -all "<" $args "\\&lt;" args
  regsub -all ">" $args "\\&gt;" args
  regsub -all "\"" $args "\\&\#34;" args
  regsub -all "]" $args "\\&\#93;" args
  
  return $args
}

########################################################################
