	function showDetail(id) {
		var cell = document.getElementById(id);
		var testid = cell.getAttribute("id");
		var divid = "div" + testid;
		var div = document.getElementById(divid);
		div.style.zIndex="100";
		div.style.display="block";
	}
	function hideDetail(id) {
		var div = document.getElementById(id);
		div.style.zIndex=-1;
		div.style.display="none";
	}

	function checkall() {
		var chkall = document.getElementById("selectAll");
		var chkItem = document.querySelectorAll("input.selectTest, input.selectTestNil");
		for (var i=0; i < chkItem.length; i++) {
			if (chkall.checked == true) {
				chkItem[i].style.visibility="visible";
			} else {
				chkItem[i].style.visibility="hidden";
				chkItem[i].checked=false;
			}
		}
	}

	function selectCol(id) {
		var col = document.getElementsByClassName("checkCol")[id];
		var chkItem = document.querySelectorAll("input.selectTest");
		var chkItemNil = document.querySelectorAll("input.selectTestNil");

		for (var i=0; i < chkItem.length; i++) {
			var testid = chkItem[i].id.split(" ");
			if (testid[1] != col.id) {
				continue;
			}
			if (col.checked == true) {
				chkItem[i].style.visibility="visible";
				chkItem[i].checked=true;
			} else {
				chkItem[i].style.visibility="hidden";
				chkItem[i].checked=false;
			}
		}
		/*
		for (var i=0; i < chkItemNil.length; i++) {
			if (col.checked != true) {
				chkItemNil[i].checked=false;
			}
		} */
	}

	function post(path, params, method) {
		method = method || "post"; // Set method to post by default if not specified.

		// The rest of this code assumes you are not using a library.
		// It can be made less wordy if you use one.
		var form = document.createElement("form");
		form.setAttribute("method", method);
		form.setAttribute("action", path);
		form.setAttribute("id", "UpdateDB");

		for(var key in params) {
			if(params.hasOwnProperty(key)) {
				var hiddenField = document.createElement("input");
				hiddenField.setAttribute("type", "hidden");
				hiddenField.setAttribute("name", key);
				hiddenField.setAttribute("value", params[key]);

				form.appendChild(hiddenField);
			}
		}

		document.body.appendChild(form);
		form.submit();
		document.body.removeChild(form);
	}

	function reSubmit(testid, distroIdx) {
		//alert(distroArrayx[distroIdx] + ' ' + testid);
		//alert(document.URL);
		var path = document.URL;
		var path2 = path.replace(/index.tml/, "resubmit.tml");
		var path2 = path2.replace(/trms\/{1,}($|\?)/, "trms/resubmit.tml?");
		var r = confirm("Are you sure resubmit this test?\n"+testid+' '+distroArrayx[distroIdx]);
		if (r != true) {
			return 0;
		}
		post(path2, {resubmit: testid + ' ' + distroArrayx[distroIdx]});
	}

	function reSubmitList() {
		//alert(distroArrayx[distroIdx] + ' ' + testid);
		//alert(document.URL);
		var path = document.URL;
		var path2 = path.replace(/index.tml/, "resubmit-list.tml");
		var path2 = path2.replace(/trms\/{1,}($|\?)/, "trms/resubmit-list.tml?");

		var testlist = "";
		var chkItem = document.querySelectorAll("input.selectTest, input.selectTestNil");
		for (var i=0; i<chkItem.length; i++) {
			if (chkItem[i].checked == true) {
				var testobj = chkItem[i].id.split(" ");
				testid = testobj[0];
				j = testobj[1];
				testlist += testid + ' ' + distroArrayx[j] + ';';
			}
		}
		//var r = confirm(path2+"\nAre you sure resubmit these test?\n"+testlist);
		var r = confirm("Are you sure resubmit these test?\n"+testlist);
		if (r != true) {
			return 0;
		}
		post(path2, {testlist: testlist});
	}

	function cloneToNewRun() {
		//alert(distroArrayx[distroIdx] + ' ' + testid);
		//alert(document.URL);
		var path = document.URL;
		var path2 = path.replace(/index.tml/, "clone.tml");
		var path2 = path2.replace(/trms\/{1,}($|\?)/, "trms/clone.tml?");

		var testlist = "";
		var chkItem = document.querySelectorAll("input.selectTest, input.selectTestNil");
		for (var i=0; i<chkItem.length; i++) {
			if (chkItem[i].checked == true) {
				var testobj = chkItem[i].id.split(" ");
				testid = testobj[0];
				testlist += testid + ';';
			}
		}
		var name = prompt("Input the distro and params, e.g\nRHEL-7.2  kernel-3.10.0-282.el7 -dbgk -cc=k@r.com", "");
		if (!name) {
			return 0;
		}
		post(path2, {testlist: testlist, distro: name});
	}

	function delList() {
		//alert(distroArrayx[distroIdx] + ' ' + testid);
		//alert(document.URL);
		var path = document.URL;
		var path2 = path.replace(/index.tml/, "deltest.tml");
		var path2 = path2.replace(/trms\/{1,}($|\?)/, "trms/deltest.tml?");

		var testlist = ""
		var chkItem = document.querySelectorAll("input.selectTest, input.selectTestNil");
		for (var i=0; i<chkItem.length; i++) {
			if (chkItem[i].checked == true) {
				var testobj = chkItem[i].id.split(" ");
				testid = testobj[0];
				j = testobj[1];
				testlist += testid + ' ' + distroArrayx[j] + "&";
			}
		}
		//var r = confirm(path2+"\nAre you sure delete these test?\n"+testlist);
		var r = confirm("Are you sure delete these test?\n"+testlist);
		if (r != true) {
			return 0;
		}
		post(path2, {testlist: testlist});
	}

	function delTestCase() {
		//alert(document.URL);
		var path = document.URL;
		var path2 = path.replace(/index.tml/, "delTestCase.tml");
		var path2 = path2.replace(/trms\/{1,}($|\?)/, "trms/delTestCase.tml?");

		var testlist = ""
		var chkItem = document.getElementsByClassName('selectTestCase');
		for (var i=0; i<chkItem.length; i++) {
			if (chkItem[i].checked == true) {
				var testid = chkItem[i].id;
				testlist += testid + ';';
			}
		}
		if (testlist == "") {
			return 0;
		}
		//var r = confirm(path2+"\nAre you sure delete these test?\n"+testlist);
		var r = confirm("Are you sure delete these test cases?\n"+testlist);
		if (r != true || testlist == "") {
			return 0;
		}
		post(path2, {testlist: testlist});
	}

	var curPkg;
	function pkgQuery(pkg) {
		var obj = document.getElementById('Q-' + pkg);
		obj.style.zIndex="100";
		obj.style.display="block";
		if (curPkg != null) {
			curPkg.style.zIndex="-1";
			curPkg.style.display="none";
		}
		curPkg = obj;
	}

	function pkgSelectSwitch(pkg) {
		var obj = document.getElementById('Q-' + pkg);
		if (obj.style.display == "none" || obj.style.display != "block") {
			obj.style.zIndex="100";
			obj.style.display="block";
		} else {
			obj.style.zIndex="-1";
			obj.style.display="none";
		}
	}

	var cpanelTO;
	function controlPanelSwitch(on) {
		var obj = document.getElementById('cpanel')
		if (on == 1) {
			obj.style.zIndex="100";
			obj.style.display="block";
			clearTimeout(cpanelTO);
		} else {
			cpanelTO=setTimeout(function() {
				obj.style.zIndex="-1";
				obj.style.display="none";
			}, 2000)
		}
	}

	function getUrlParameter(a) {
		a = a.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]");
		a = RegExp("[\\?&]" + a + "=([^&#]*)").exec(location.search);
		return null === a ? "" : decodeURIComponent(a[1].replace(/\+/g, " "))
	} 

	window.onload = function qformload() {
		var objs = document.getElementsByName('pkg');
		var pkgObj = objs[0];

		var pkgvalue = getUrlParameter('pkg');
		if (pkgvalue != "") {
			for (var i=0; i<objs.length; i++) {
				if (objs[i].value == pkgvalue) {
					pkgObj = objs[i];
					break;
				}
			}
		}
		pkgObj.checked = "checked";
		//pkgQuery(pkgObj.value);
	}

