# HK: I must admit that I find it much easier to write a pkgIndex.tcl by
# hand than to tweak my code such that it can be automatically generated. 
# $Revision: 1.0 $, $Date: 2014/12/12 10:57:22 $

## tclPkgUnknown, when running this script, makes sure that
## $dir is set to the directory of this very file
set VERSION 3.0
set VERDATE 2017-02-24

# Tidied code by Ed Suominen.

# Define the package names and sourced script files
set packageSetupList {
  getOpt
  {getOpt.tcl}
}

# Now setup the packages
foreach {pkg files} $packageSetupList {
  set script "package provide $pkg $VERSION\n"
  append script "namespace eval ::$pkg set VERSION $VERSION\n"
  foreach {file} $files {
    append script "source \[file join \"$dir\" $file\]\n"
  }
  package ifneeded $pkg $VERSION $script
}
