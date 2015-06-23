#!/bin/bash

pkg=tDOM-0.8.3.tgz

#wget http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved/$pkg
#wget https://github.com/downloads/tDOM/tdom/tDOM-0.8.3.tgz
curl -L -O https://github.com/downloads/tDOM/tdom/tDOM-0.8.3.tgz
[ -f "$pkg" ] || {
	echo "$pkg not exist!" >&2
	exit 1
}

cat <<Patch >fix.patch
diff -pNur tDOM-0.8.3/generic/tcldom.c tDOM-0.8.3.new/generic/tcldom.c
--- tDOM-0.8.3/generic/tcldom.c 2007-12-26 07:19:02.000000000 +0800
+++ tDOM-0.8.3.new/generic/tcldom.c     2015-06-12 17:59:28.074193235 +0800
@@ -5931,12 +5931,33 @@ int tcldom_EvalLocked (

     Tcl_AllowExceptions(interp);
     ret = Tcl_EvalObj(interp, objv[2]);
+
+#if 0
     if (ret == TCL_ERROR) {
         char msg[64 + TCL_INTEGER_SPACE];
         sprintf(msg, "\n    (\"%s %s\" body line %d)", Tcl_GetString(objv[0]),
                 Tcl_GetString(objv[1]), interp->errorLine);
         Tcl_AddErrorInfo(interp, msg);
     }
+#endif
+
+    if (ret == TCL_ERROR) {
+           char msg[64 + TCL_INTEGER_SPACE];
+           sprintf(msg, "\n    (\"%s %s\" body line %d)", Tcl_GetString(objv[0]),
+                   Tcl_GetString(objv[1]),
+
+#if defined(USE_INTERP_ERRORLINE)
+                   interp->errorLine
+#else
+#if (TCL_MAJOR_VERSION >= 8 && TCL_MINOR_VERSION >= 6)
+                   Tcl_GetErrorLine(interp)
+#else
+                   interp->errorLine
+#endif
+#endif
+                  );
+           Tcl_AddErrorInfo(interp, msg);
+    }

     domLocksUnlock(dl);

Patch

tar zxf $pkg
pushd tDOM-0.8.3
	patch -p1 < ../fix.patch && cd unix && {
		../configure --libdir=/usr/local/lib --with-tcl=/usr/lib64 &&
		make && make install
	}
popd
rm -rf ${pkg} tDOM-0.8.3 fix.patch
