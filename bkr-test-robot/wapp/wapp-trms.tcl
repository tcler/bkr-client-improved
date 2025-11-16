#!/usr/bin/env tclsh
#package require wapp
lappend ::auto_path $::env(HOME)/lib /usr/local/lib /usr/lib64 /usr/lib
package require sqlite3
package require runtestlib 1.1
namespace import ::runtestlib::*

source /usr/local/lib/wapp.tcl

proc common-footer {{user ""}} {
  wapp {<footer>}
  if {$user == {}} {
    wapp {<br>}
  } else {
    wapp-subst {
    <div id="hostUsage" style="
      background: #f0f8ff;
      font-family: monospace;
      text-align: center;">
    </div>

    <script>
    function updateHostUsage() {
        const username = "%unsafe($user)";
        const url = `${window.location.origin}/host-usage?user=${username}`;

        fetch(url)
            .then(response => response.json())
            .then(data => {
                const hostUsage = data.hostusage || 'N/A';
                const servAddr = data.servaddr || 'N/A';
                const clntIp = data.clntip || 'N/A';
                const displayText = `{RecipeUse(${hostUsage}) - clnt(${clntIp}) serv(${servAddr})}`;
                document.getElementById('hostUsage').textContent = displayText;
            })
            .catch(error => {
                document.getElementById('hostUsage').textContent = 
                    'get host-usage fail:' + error.message;
            });
    }

    updateHostUsage();

    //update every 5m
    setInterval(updateHostUsage, 5 * 60 * 1000);
    </script>
    }
  }
  wapp-trim {
      <div style="text-align: center;">
        <strong>
          Powered by <a href="https://github.com/tcler/bkr-client-improved">bkr-client-improved</a> and
          <a href="https://wapp.tcl-lang.org">wapp</a>
        </strong>
        |
        <a href="mailto:yin-jianhong@163.com">@JianhongYin</a>
        <a href="mailto:nzjachen@gmail.com">@ZhenjieChen</a>
      </div>
      </footer>
      </html>
  }
}

proc wapp-default {} {
  wapp-allow-xorigin-params
  wapp-content-security-policy {
    default-src 'self';
    style-src 'self' 'unsafe-inline';
    script-src 'self' 'unsafe-inline';
  }

  set user [lindex [wapp-param user] end]
  if {$user == {}} {
    wapp-redirect main
  } elseif {![file exists /home/${user}/.testrundb/testrun.db]} {
    wapp-redirect [wapp-param BASE_URL]/main?user=${user}&notexist=1
  }
  wapp {<!-- vim: set sw=4 ts=4 et: -->
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
    <title>🎃▦bkr-test-robot▦🎃</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
            height: 92vh;
            overflow: hidden; /* 防止整个页面滚动 */
        }

        .header {
            background-color: #2c3e50;
            padding: 10px 10px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .logo {
            font-size: 20px;
            font-weight: bold;
            color: white;
        }

        div.controlPanelCall {
            position: fixed;
            z-index: 99;
            top: 144pt;
            left: 0pt;
            background-color: #454;
            background-color: #CD7F32;
            filter:alpha(Opacity=80); -moz-opacity:0.8; opacity: 0.8;
            border: solid 3px;
            border-color: #D9D919;
            border-color: #cd7f32;
        }
        div.controlPanel {
            position: fixed;
            z-index: -1;
            display: none;
            top: 144pt;
            left: 0pt;
            background-color: #454;
            background-color: #CD7F32;
            filter:alpha(Opacity=96); -moz-opacity:0.96; opacity: 0.96;
            border: solid 3px;
            border-color: #D9D919;
            border-color: #cd7f32;
        }

        .container {
            padding: 5px;
            width: 99%;
            margin: 0 auto;
            height: calc(92vh - 70px); /* 减去header高度 */
            display: flex;
            flex-direction: column;
        }

        .controls {
            background-color: white;
            padding: 0px;
            border-radius: 5px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 5px;
        }

        .fieldset {
            width: 100%;
            border-style:none;
            border-left-width:1px;
        }

        .radio-group {
            display: inline;
            flex-wrap: wrap;
            gap: 1px;
            margin-bottom: 1px;
            border-right-width:15px;
        }

        .radio-item {
            display: inline; /* 保证控件都居中, inline-flex 会导致向上对齐 */
	    gap: 5px;
        }

        .query-form {
            display: inline-flex;
            align-items: center;
            gap: 2px;
        }

        .pkg-select {
            display: none;
            z-index: -1;
        }

        .pkg-select.show {
            width: 100%;
            z-index: 110;
            display: block;
        }

        .table-container {
            overflow: auto;
            flex: 1; /* 占据剩余空间 */
            width: 100%;
            border: 1px solid #ddd;
            border-radius: 0px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            position: relative;
        }

        .detail-div {
            position: absolute;
            top: 88px;
            left: 10px;
            width: 96%;
            flex: 1; /* 占据剩余空间 */
            background-color: #f3e5ab; /* 温暖的米色 */
            color: #2c2c2c;
            padding: 10px;
            border: 2px solid #ff6b6b;
            max-height: 80vh; /* 限制最大高度 */
            min-height: 60vh; /* 限制最大高度 */
            overflow: auto; /* 启用滚动 */
        }

        table {
            border-collapse: collapse;
            width: 99%;
            min-width: 800px;
        }

        th, td {
            border: 1px solid #ddd;
            padding: 10px;
            text-align: left;
            white-space: nowrap;
        }

        th {
            background-color: #3498db;
            color: white;
            position: sticky;
            top: 0;
            z-index: 20; /* 增加z-index确保表头在最上层 */
            box-shadow: 0 2px 2px -1px rgba(0, 0, 0, 0.4); /* 添加阴影增强层次感 */
        }

        .first-column {
            font-family: monospace;
            position: sticky;
            left: 0;
            z-index: 5;
            background-color: #ecf0f1;
        }

        .first-head-column {
            position: sticky;
            left: 0;
            z-index: 30; /* 确保第一列的表头在最上层 */
            font-size: 20px;
            font-weight: bold;
            background-color: #fcf0f1;
            color: gray;
            box-shadow: 2px 0 2px -1px rgba(0, 0, 0, 0.4); /* 添加阴影增强层次感 */
        }

        .tooltip {
            position: absolute;
            background-color: #333;
            color: white;
            padding: 8px 12px;
            border-radius: 4px;
            font-size: 14px;
            z-index: 1000;
            pointer-events: none;
            opacity: 0;
            transition: opacity 0.3s;
            max-width: 400px;
            word-wrap: break-word;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
        }

        .tooltip.show {
            opacity: 1;
        }

        .truncate {
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            max-width: 64px;
        }

        .header-cell {
            position: relative;
        }

        .header-cell:hover {
            opacity: 1;
        }

        .scroll-header {
            position: sticky;
            top: 0;
            z-index: 15;
        }

        .scroll-first-column {
            position: sticky;
            left: 0;
            z-index: 5;
        }

        /* 添加加载提示样式 */
        .loading-message {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 18px;
            color: #666;
            text-align: center;
            z-index: 10;
        }

        .loading-spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #3498db;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 2s linear infinite;
            margin: 0 auto 10px;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="logo"><a style="color: white;" href="/">🎃bkr-test-robot🎃</a></div>
    </div>

    <div class="container">
        <div class="controlPanelCall" onmouseover="controlPanelSwitch(1);">
            V<br>V<br>V
        </div>
        <div class="controlPanel" id="cpanel" onmouseover="controlPanelSwitch(1);" onmouseout="controlPanelSwitch(0);">
            <span style="font-weight:bold; color: #bfb;"> TRMS Control Pannel </span>
            <br/>
            <input type="button" value="Delete" onclick="delList();"/>
            <input type="button" value="[Re]Run" onclick="reSubmitList();"/>
            <input type="button" value="Clone" onclick="cloneToNewRun();"/>
            <br>
            <input type="button" value="Delete Test Cases" onclick="delTestCase();"/>
        </div>

        <div class="controls">
            <form class="query-form" id="queryForm">
            <fieldset class="fieldset" id="queryFieldset">
                <div class="radio-group" id="pkgRadioGroup">
                    <!-- Radio buttons will be generated here -->
                </div>
                <input type="submit" value="Query" id="queryButton">
            </fieldset>
            </form>
        </div>

        <div class="table-container">
            <!-- 添加加载提示 -->
            <div class="loading-message" id="loadingMessage">
                <div class="loading-spinner"></div>
                <div>loading data test result ...</div>
            </div>
            <table id="resultsTable">
                <thead id="tableHeader">
                    <!-- Table header will be generated here -->
                </thead>
                <tbody id="tableBody">
                    <!-- Table body will be generated here -->
                </tbody>
            </table>
        </div>
    </div>

    <script>
        // 全局变量
        let testruninfo = {
            "components": ["nfs", "cifs"],
            "test-run": {
                "nfs": [
                    "rhel8.10 NFS run for performance testing",
                    "rhel9.8 NFS run for compatibility testing",
                    "rhel10.2 NFS run for security testing"
                ],
                "cifs": [
                    "rhel-8.10 CIFS run for file sharing",
                    "rhel-9.8 CIFS run for authentication",
                    "rhel-10.2 CIFS run for encryption",
                    "rhel-9.7.z CIFS run for network stability x86_64 hahaha, abcd, efg, hijk, xyz"
                ]
            },
            "qresults": {
                "qruns": [
                    "Test Run 1 - 2023-06-01 fake data for demo tests",
                    "Test Run 2 - 2023-06-05",
                    "Test Run 3 - 2023-06-10",
                    "Test Run 4 - 2023-06-15",
                    "Test Run 5 - 2023-06-20",
                ],
                "results": []
            }
        };

        let qresults = testruninfo.qresults;

        const getParam = (name) => new URLSearchParams(window.location.search).get(name);
        function car(sequence) {
            if (Array.isArray(sequence)) return sequence[0];
            if (typeof sequence === 'string') return sequence.split(' ')[0];
            return undefined;
        }

        function cdr(sequence) {
            if (Array.isArray(sequence)) return sequence.slice(1);
            if (typeof sequence === 'string') return sequence.split(' ').slice(1).join(' ');
            return undefined;
        }

        function selectCol(id) {
            var col = document.getElementsByClassName("checkCol")[id];
            var chkRuns = document.querySelectorAll("input.selectTestRun");
    
            for (var i=0; i < chkRuns.length; i++) {
                var testid = chkRuns[i].id.split(" ");
                if (testid[1] != col.id) {
                    continue;
                }
                if (col.checked == true) {
                    //chkRuns[i].style.visibility="visible";
                    chkRuns[i].checked=true;
                } else {
                    //chkRuns[i].style.visibility="hidden";
                    chkRuns[i].checked=false;
                }
            }
        }

        function showDetail(id) {
            const divid = `div${id}`;
            const div = document.getElementById(divid);
            div.style.zIndex = "500";
            div.style.display = "block";
        }

        function hideDetail(id) {
            const div = document.getElementById(id);
            div.style.zIndex = "-1";
            div.style.display = "none";
        }

	var cpanelTO;
	function controlPanelSwitch(on) {
		var obj = document.getElementById('cpanel')
		if (on == 1) {
			obj.style.zIndex = "100";
			obj.style.display = "block";
			clearTimeout(cpanelTO);
		} else {
			cpanelTO = setTimeout(function() {
				obj.style.zIndex = "-1";
				obj.style.display = "none";
			}, 2000)
		}
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

	function delList() {
		const nurl = new URL(window.location.href);
		nurl.pathname = "deltest";

		var testlist = ""
		var chkItem = document.querySelectorAll("input.selectTestRun, input.selectTestNil");
		for (var i=0; i<chkItem.length; i++) {
			if (chkItem[i].checked == true) {
				var testobj = chkItem[i].id.split(" ");
				testid = testobj[0];
				j = testobj[1];
				testlist += `${testid} ${qresults.qruns[j]}&`;
			}
		}
		var r = confirm("Are you sure delete these test?\n"+testlist);
		if (r != true) {
			return 0;
		}
		post(nurl.toString(), {testlist: testlist});
	}

	function reSubmitList() {
		const nurl = new URL(window.location.href);
		nurl.pathname = "resubmit-list";

		var testlist = "";
		var chkItem = document.querySelectorAll("input.selectTestRun, input.selectTestNil");
		for (var i=0; i<chkItem.length; i++) {
			if (chkItem[i].checked == true) {
				var testobj = chkItem[i].id.split(" ");
				testid = testobj[0];
				j = testobj[1];
				testlist += `${testid} ${qresults.qruns[j]}\n`;
			}
		}
		var r = confirm(`Are you sure resubmit these test?\n${testlist}`);
		if (r != true) {
			return 0;
		}
		post(nurl.toString(), {testlist: testlist});
	}

	function cloneToNewRun() {
		const nurl = new URL(window.location.href);
		nurl.pathname = "clone";

		var testlist = "";
		var chkItem = document.querySelectorAll("input.selectTestRun, input.selectTestNil");
		for (var i=0; i<chkItem.length; i++) {
			if (chkItem[i].checked == true) {
				var testobj = chkItem[i].id.split(" ");
				testid = testobj[0];
				testlist += testid + ';';
			}
		}
		var name = prompt("============> Input the distro and params, e.g <============\nRHEL-7.2  kernel-3.10.0-282.el7 -dbgk -cc=k@r.com\nRHEL-7.6 -alone -random -kdump=  info:kernel,nfs-utils", "");
		if (!name) {
			return 0;
		}
		post(nurl.toString(), {testlist: testlist, distro: name});
	}

	function delTestCase() {
		const nurl = new URL(window.location.href);
		nurl.pathname = "delTestCase";

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
		var r = confirm("Are you sure delete these test cases?\n"+testlist);
		if (r != true || testlist == "") {
			return 0;
		}
		post(nurl.toString(), {testlist: testlist});
	}

        // 初始化界面
        function initializeInterface() {
            // 创建组件/包的radio控件
            createRadioButtons();

            // 渲染表格
            renderTable();

            createResultDetailDivs();
        }

        // 创建radio按钮
        function createRadioButtons() {
            const queryField = document.getElementById('queryFieldset');
            const radioGroup = document.getElementById('pkgRadioGroup');

            radioGroup.innerHTML = '';
            const allSelects = queryField.querySelectorAll('.pkg-select');
            if (allSelects) {
                allSelects.forEach(select => { select.remove(); });
            }

            const userform = document.createElement('input');
            userform.name = "user";
            userform.type = 'hidden';
            userform.value = getParam('user');
            queryField.insertBefore(userform, radioGroup);

            testruninfo.components.forEach(pkg => {
                if (!(pkg in testruninfo['test-run'])) { return; }
                const radioItem = document.createElement('div');
                radioItem.className = 'radio-item';

                const radio = document.createElement('input');
                radio.type = 'radio';
                radio.id = `pkg-${pkg}`;
                radio.name = 'pkg';
                radio.value = pkg;
                if (getParam('pkg') == pkg) {
                    radio.checked = 'checked';
                }
                radio.onclick = function() { pkgSelectSwitch(pkg); };

                const label = document.createElement('label');
                label.htmlFor = `pkg-${pkg}`;
                label.textContent = pkg;

                radioItem.appendChild(radio);
                radioItem.appendChild(label);

                // 创建select控件
                const select = document.createElement('select');
                select.id = `run-${pkg}`;
                select.name = `run-${pkg}`;
                select.multiple = true;
                select.size = 5;
                select.className = 'pkg-select';

                // 添加选项
                testruninfo['test-run'][pkg].forEach(testrun => {
                    const option = document.createElement('option');
                    option.value = testrun;
                    option.textContent = testrun;
                    select.appendChild(option);
                });

                queryField.appendChild(select);
                radioGroup.appendChild(radioItem);
            });
        }

        // hide all .pkg-select
        function hideAllPkgSelects() {
            const selects = document.querySelectorAll('.pkg-select');
            selects.forEach(select => {
                select.classList.remove('show');
            });
        }

        // Radio切换时显示对应的select
        function pkgSelectSwitch(pkg) {
            const selects = document.querySelectorAll('.pkg-select');
            selects.forEach(select => {
                if (select.id === `run-${pkg}`) {
                    select.classList.toggle('show');
                } else {
                    select.classList.remove('show');
                }
            });
        }

        // Truncate string to max length with ellipsis
        function truncateString(str, maxLength = 36) {
            if (str.length <= maxLength) {
                return str;
            }
            return str.substring(0, maxLength - 3) + '...';
        }

	keepLastTwo = (path) => path.replace(/^\/+|\/+$/g, '').split('/').slice(-2).join('/');

        // Create tooltip element
        function createTooltip() {
            const tooltip = document.createElement('div');
            tooltip.className = 'tooltip';
            document.body.appendChild(tooltip);
            return tooltip;
        }

        // 渲染表格
        function renderTable() {
            // 渲染表头
            const tableHeader = document.getElementById('tableHeader');
            tableHeader.innerHTML = '';

            const headerRow = document.createElement('tr');
            const emptyHeader = document.createElement('th');
            emptyHeader.className = 'first-head-column';
            emptyHeader.textContent = ' Test  \\  TestRun ';
            headerRow.appendChild(emptyHeader);

            const maxHeader = 40;
            const tooltip = createTooltip();
            qresults.qruns.forEach((run, index) => {
                const th = document.createElement('th');
                th.textContent = run;
                th.title = run; // Default browser tooltip
                // 如果长度超过maxHeader，截断并添加tooltip
                if (run.length > maxHeader) {
                    th.textContent = truncateString(run, maxHeader);

                    // Create custom tooltip
                    th.addEventListener('mouseenter', function(e) {
                        tooltip.textContent = run;
                        tooltip.style.left = (e.pageX + 10) + 'px';
                        tooltip.style.top = (e.pageY - 10) + 'px';
                        tooltip.classList.add('show');
                    });

                    th.addEventListener('mousemove', function(e) {
                        tooltip.style.left = (e.pageX + 10) + 'px';
                        tooltip.style.top = (e.pageY - 10) + 'px';
                    });

                    th.addEventListener('mouseleave', function() {
                        tooltip.classList.remove('show');
                    });
                }

                //add selectCol checkbox to thead <th>
                const colChkbox = document.createElement('input');
                colChkbox.type = "checkbox";
                colChkbox.className = "checkCol";
                colChkbox.id = index;
                colChkbox.onclick = function() { selectCol(index); };
                th.prepend(colChkbox);

                headerRow.appendChild(th);
            });

            tableHeader.appendChild(headerRow);

            // 渲染表格主体
            const tableBody = document.getElementById('tableBody');
            const maxTestcase = 40;
            tableBody.innerHTML = '';

            qresults.results.forEach((resObj, rowIdx) => {
                const row = document.createElement('tr');

                // 第一列 - 测试用例
                const testId = resObj.testid;
                const testName = keepLastTwo(resObj.test);
                row.id = testId;
                row.ondblclick = function() { showDetail(testId); };

                const testCell = document.createElement('td');
                testCell.textContent = `${rowIdx}. ${testName}`;
                testCell.className = 'first-column';

                // 如果长度超过maxTestCase，截断并添加tooltip
                if (testName.length > maxTestcase) {
                    testCell.textContent = truncateString(testCell.textContent, maxTestcase);

                    // Create custom tooltip
                    testCell.addEventListener('mouseenter', function(e) {
                        tooltip.textContent = testName;
                        tooltip.style.left = (e.pageX + 10) + 'px';
                        tooltip.style.top = (e.pageY - 10) + 'px';
                        tooltip.classList.add('show');
                    });

                    testCell.addEventListener('mousemove', function(e) {
                        tooltip.style.left = (e.pageX + 10) + 'px';
                        tooltip.style.top = (e.pageY - 10) + 'px';
                    });

                    testCell.addEventListener('mouseleave', function() {
                        tooltip.classList.remove('show');
                    });
                }

                //add selectTest checkbox to test <td>
                const testChkbox = document.createElement('input');
                testChkbox.type = "checkbox";
                testChkbox.className = "selectTestCase";
                testChkbox.id = testId;
                testCell.appendChild(testChkbox);
                row.appendChild(testCell);

                // 其他列 - 测试结果
                var nrun = qresults.qruns.length;
                for (let k = 0; k < nrun; k++) {
                    var res = resObj['res'+k];
                    const cell = document.createElement('td');
                    cell.id = `${testId} ${k}`;

                    var runChkbox = document.createElement('input');
                    runChkbox.type = 'checkbox';
                    runChkbox.id = `${testId} ${k}`;
                    if (!res) { res = ''; } else { res = res.trim(); }
                    runChkbox.className = 'selectTestRun';
                    if (res == '') {
                        runChkbox.className = 'selectTestNil';
                    }
                    cell.appendChild(runChkbox);

                    if (['-', 'o', ''].includes(res)) {
                        const resSpan = document.createElement('span');
                        resSpan.textContent = res;
                        cell.appendChild(resSpan);
                    } else {
                        const resarr = res.split(" ");
                        const nrecipe = resarr.length/2;
                        for (var i = 0; i < nrecipe; i++) {
                            const recipeStat = resarr[i];
			    const recipeId = resarr[i+nrecipe]
                            const statSpan = document.createElement('span');
                            const linkA = document.createElement('a');
                            if (recipeStat === "Pass") {
                                linkA.style.color = "skyblue";
                            } else if (recipeStat === "Fail") {
                                linkA.style.color = "red";
                            } else if (recipeStat === "Warn") {
                                linkA.style.color = "green";
                            } else if (recipeStat === "Panic") {
                                linkA.style.color = "darkcyan";
                            } else {
                                linkA.style.color = "gray";
                            }
                            linkA.href = `https://beaker.engineering.redhat.com/recipes/${recipeId}`;
                            linkA.textContent = recipeStat + " ";
                            statSpan.appendChild(linkA);
                            cell.appendChild(statSpan);
                        }
                    }
                    row.appendChild(cell);
                }

                tableBody.appendChild(row);
            });
        }

        function createResultDetailDivs() {
            const nheaderRow = document.createElement('tr');
            const maxHeader = 40;
            qresults.qruns.forEach((run, index) => {
                const td = document.createElement('td');
                td.textContent = truncateString(run, maxHeader);
                td.title = run;
                nheaderRow.appendChild(td);
            });
            qresults.results.forEach((resObj, rowIdx) => {
                const resdDiv = document.createElement('div');
                resdDiv.className = 'detail-div';
                resdDiv.id = `div${resObj.testid}`;

                const resdSpan = document.createElement('span');
		resdSpan.textContent = ' - [Close me]';
                const resdXBtn = document.createElement('button');
                resdXBtn.textContent = 'X';
                resdXBtn.addEventListener('click', function(e) {
                    hideDetail(resdDiv.id);
                });
                resdDiv.prepend(resdXBtn);
		resdDiv.appendChild(resdSpan);

                const br = document.createElement('br');
                const p = document.createElement('p');
                p.textContent = resObj.test;
                resdDiv.appendChild(br);
                resdDiv.appendChild(p);

                const resdTable = document.createElement('table');
                resdTable.appendChild(nheaderRow.cloneNode(true));

                const resdRow = document.createElement('tr');
                var nrun = qresults.qruns.length;
                for (let k = 0; k < nrun; k++) {
                    const cell = document.createElement('td');
                    var resd = resObj['resd'+k];
		    if (!resd) { resd = ''; }
		    cell.innerHTML = resd.replace(/\n/g, '<br>');
		    resdRow.appendChild(cell);
                }
                resdTable.appendChild(resdRow);
		resdDiv.appendChild(resdTable);
                resdDiv.style.zIndex = "-1";
                resdDiv.style.display = "none";
                document.body.appendChild(resdDiv);
            });
        }

        function handleQuerySubmit(e) {
            hideAllPkgSelects();
            e.preventDefault();

            // 显示加载提示
            document.getElementById('loadingMessage').style.display = 'block';

            // 收集表单数据
            const formData = new FormData(document.getElementById('queryForm'));
            const params = new URLSearchParams(formData);

            // 构建查询URL
            const cururl = new URL(window.location.href);
            cururl.pathname += "resjson";
            cururl.search = params.toString();

            // 发送请求获取新数据
            fetch(cururl.toString())
                .then(response => {
                    if (!response.ok) {
                        throw new Error('Network response was not ok');
                    }
                    return response.json();
                })
                .then(data => {
                    // 更新全局数据
                    testruninfo = data;
                    qresults = testruninfo.qresults;

                    // 隐藏加载提示
                    document.getElementById('loadingMessage').style.display = 'none';

                    // 重新渲染界面
                    initializeInterface();
                })
                .catch(error => {
                    console.error('Error:', error);
                    document.getElementById('loadingMessage').style.display = 'none';
                    document.getElementById('loadingMessage').innerHTML = '<div style="color: red;">Query fail, please try again.</div>';
                });
        }

        // after page loaded
        document.addEventListener('DOMContentLoaded', function() {
            document.getElementById('loadingMessage').style.display = 'block';

            const cururl = new URL(window.location.href);
            cururl.pathname += "resjson";
            var resurl = cururl.toString();
            fetch(resurl)
                .then(response => {
                    return response.json()
                })
                .then(data => {
                    testruninfo = data;
                    qresults = testruninfo.qresults;
                    document.getElementById('loadingMessage').style.display = 'none';
                    initializeInterface();
                })
                .catch(error => {
                    console.error('Error:', error);
                    // 如果加载失败，也隐藏加载提示
                    document.getElementById('loadingMessage').style.display = 'none';
                    document.getElementById('loadingMessage').innerHTML = '<div style="color: red;">loading data fail, please refresh the page and try again.</div>';
                });

            // Query button event
	    document.getElementById('queryForm').addEventListener('submit', handleQuerySubmit);
        });
    </script>
</body>
  }
  common-footer $user
}

proc wapp-page-resjson {} {
  wapp-allow-xorigin-params
  wapp-mimetype application/json
  set user [lindex [wapp-param user] 0]
  set qpkg [lindex [wapp-param pkg] 0]
  set runList [wapp-param run-$qpkg]
  set resgenfile "/usr/local/libexec/wapp-trms-resjson.tcl"
  set json [exec expect $resgenfile $user $qpkg $runList]
  wapp $json; return
  wapp {{
      "components": ["nfs", "cifs"],
      "test-run": {
          "nfs": [
              "rhel-8.10 NFS run for performance testing",
              "rhel-9.8 NFS run for compatibility testing",
              "rhel-10.2 NFS run for security testing",
              "rhel-10.2 ONTAP run for security tls testing"
          ],
          "cifs": [
              "RHEL-8 CIFS run for file sharing",
              "RHEL-9 CIFS run for authentication",
              "RHEL-10 CIFS run for encryption",
              "RHEL-10 Win2k22 run for network stability x86_64, abcd, efg, hijk, xyz",
              "RHEL-10 ONTAP run for network stability x86_64, abcd, uvw, hello, world"
          ]
      },
      "qresults": {
          "qruns": [
              "Test Run 1 - 2025-06-01 from wapp-page-resjon demo data",
              "Test Run 2 - 2025-06-05",
              "Test Run 3 - 2025-06-10",
              "Test Run 4 - 2025-06-15",
              "Test Run 5 - 2025-06-20",
              "Test Run 6 - 2025-06-25",
              "Test Run 7 - 2025-06-30",
              "Test Run 8 - 2025-07-05",
              "Test Run 9 - 2025-07-10",
              "Test Run 10 - 2025-07-15"
          ],
          "results": []
      }
  }}
}

proc wapp-page-main {} {
  wapp-allow-xorigin-params
  wapp-content-security-policy {
    style-src 'self' 'unsafe-inline';
  }

  set uri [wapp-param BASE_URL]
  wapp {<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>🎃▦bkr-test-robot▦🎃</title>
  <style>
    #p2 {
      text-indent: 2em;
    }
    .warn {
      color: red;
    }
    .header {
      background-color: #2c3e50;
      padding: 10px 10px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .logo {
      font-size: 20px;
      font-weight: bold;
      color: white;
    }
  </style>
</head>
<body>
    <div class="header">
        <div class="logo"><a style="color: white;" href="/">🎃bkr-test-robot🎃</a></div>
    </div>
  }
  set user [lindex [wapp-param user] end]
  wapp-subst {query.param.user = %html($user) </p>}
  set users [exec bash -c {ls /home/*/.testrundb/testrun.db 2>/dev/null|awk -F/ '{print $3}'}]
  wapp {<font size="+1">}
  if {[llength $users] > 0} {
    wapp {<p id="p2">Now available test run robot instance[s]:<br></p>}
    foreach u $users {
      wapp-subst {<p id="p2"><B>&emsp;<a href="%url($uri?user=$u)">%html(${u})'s test robot instance</a></B>}
      exec -ignorestderr bash -c "crontab -l -u $u || echo | crontab -u $u -"
      set robotinfo [exec bash -c "crontab -l -u $u | sed -n '/^\[\[:space:]]*\[^#].*bkr-autorun-monitor/{p}'; :"]
      if {$robotinfo == ""} {set robotinfo "{warn} robot instance has been disabled"}
      wapp-subst {&emsp;&emsp;-> %html($robotinfo) </p>}
      set krb5stat [exec bash -c "su - $u -c 'klist -s' &>/dev/null && echo valid || echo expired"]
      if {$krb5stat == "expired"} {
        set krb5auth [exec bash -c "c=/home/$u/.beaker_client/config; test -f \$c && awk -F= '/^(USERNAME|KRB_PRINCIPAL)/{print \$2}' \$c|xargs; :"]
        if {$krb5auth != ""} {
          wapp-subst {<p>&emsp;&emsp;&emsp;&emsp; krb5 ticket: %html($krb5stat; krb5 auth: $krb5auth)</p>}
        } else {
          wapp-subst {<p class="warn">&emsp;&emsp;&emsp;&emsp; krb5 ticket: %html($krb5stat);</p>}
        }
      } else {
        set krb5u [exec bash -c "su - $u -c 'klist -l|awk \"NR==3{print \\\$1}\"' 2>/dev/null | tail -1"]
        wapp-subst {<p>&emsp;&emsp;&emsp;&emsp; krb5 ticket: %html($krb5stat ($krb5u))</p>}
      }
    }
  } else {
    wapp-subst {<p id="p2">There is not any test run created by any user, please create test run from command line by using:<br></p>
      <p id="p2"><B>&emsp;bkr-autorun-create $distro $testlist_file {--pkg pkgname} [other bkr-runtest options]</B> <br></p>
      <p id="p2">please see <a href="https://github.com/tcler/bkr-client-improved">bkr-client-improved</a> for more information <br><br><br></p>
    }
  }
  wapp {<br><br><br><br>
    </font>
<body>
  }
  common-footer
}

proc wapp-page-resubmit-list {} {
  wapp-allow-xorigin-params
  set permission yes

  set user [lindex [wapp-param user] end]
  set dbfile [dbroot $user]/testrun.db
  if {[string match {localhost:*} [wapp-param HTTP_HOST]]} { ""; }

  wapp {<html>}
  set testList [wapp-param testlist]
  if {$permission != yes} {
	wapp {<span style="font-size:400%;">You have no permission to do this!<br></span>}
  } elseif {![file exists $dbfile]} {
	wapp {<span style="font-size:400%;">There is not dbfile, something is wrong!<br></span>}
  } elseif {$testList != ""} {
	sqlite3 db $dbfile
	db timeout 6000
	db transaction {
		foreach test [split $testList "\n"] {
			if {$test == ""} continue
			set testid_ [lindex $test 0]
			set distro_gset_ [lrange $test 1 end]
			set sql {
				UPDATE OR IGNORE testrun
					set jobid='', testStat='', res='o', rstat='', taskuri='', abortedCnt=0, resdetail=''
					WHERE testid = $testid_ and distro_rgset = $distro_gset_;
				INSERT OR IGNORE INTO testrun (testid, distro_rgset, abortedCnt, res, testStat)
					VALUES($testid_, $distro_gset_, 0, '-', '')
			}
			db eval $sql
		}
	}
	wapp {<span style="font-size:400%;">Update ... Done!<br></span>}
  }

  set defaultUrl "[wapp-param BASE_URL]?[wapp-param QUERY_STRING]"
  wapp-subst {return to %unsafe($defaultUrl)}
  wapp-subst {
	<head>
	<META HTTP-EQUIV="Refresh" CONTENT="1; URL=%unsafe($defaultUrl)">
	</head>
	<body></body>
	</html>
  }
}

proc wapp-page-deltest {} {
  wapp-allow-xorigin-params
  set permission yes

  set user [lindex [wapp-param user] end]
  set dbfile [dbroot $user]/testrun.db
  if {[string match {localhost:*} [wapp-param HTTP_HOST]]} { ""; }

  wapp {<html>}
  set testList [wapp-param testlist]
  if {$permission != yes} {
	wapp {<span style="font-size:400%;">You have no permission to do this!<br></span>}
  } elseif {![file exists $dbfile]} {
	wapp {<span style="font-size:400%;">There is not dbfile, something is wrong!<br></span>}
  } elseif {$testList != ""} {
	sqlite3 db $dbfile
	db timeout 6000
	db transaction {
		foreach test [split $testList "&"] {
			if {$test == ""} continue
			set testid_ [lindex $test 0]
			set distro_gset_ [lrange $test 1 end]

			db eval "DELETE FROM testrun WHERE testid = '$testid_' and distro_rgset = '$distro_gset_'"
		}
	}
	wapp {<span style="font-size:400%;">Update ... Done!<br></span>}
  }

  set defaultUrl "[wapp-param BASE_URL]?[wapp-param QUERY_STRING]"
  wapp-subst {return to %unsafe($defaultUrl)}
  wapp-subst {
	<head>
	<META HTTP-EQUIV="Refresh" CONTENT="1; URL=%unsafe($defaultUrl)">
	</head>
	<body></body>
	</html>
  }
}

proc wapp-page-clone {} {
  wapp-allow-xorigin-params
  set permission yes

  set user [lindex [wapp-param user] end]
  set dbfile [dbroot $user]/testrun.db
  if {[string match {localhost:*} [wapp-param HTTP_HOST]]} { ""; }

  wapp {<html>}
  set testList [lindex [wapp-param testlist] 0]
  set distro_gset [wapp-param distro]
  if {$permission != yes} {
	wapp {<span style="font-size:400%;">You have no permission to do this!<br></span>}
  } elseif {![file exists $dbfile]} {
	wapp {<span style="font-size:400%;">There is not dbfile, something is wrong!<br></span>}
  } elseif {$testList != "" && $distro_gset != ""} {
	set distro [lindex $distro_gset 0]
	set gset {}
	set infohead {info:}

	if {[lsearch -regexp $distro_gset ^$infohead] == -1} {
		lappend distro_gset info:kernel
	}

	foreach v [lrange $distro_gset 1 end] {
		if [regexp -- {^-} $v] {
			lappend gset $v
			continue
		} elseif [regexp -- "^$infohead" $v] {
			set infoheadlen [string length $infohead]
			set pkglist [split [string range $v $infoheadlen end] ,]
			if {[lsearch -regexp $pkglist ^kernel$] == -1} {
				set pkglist [linsert $pkglist 0 kernel]
			}
			set info {}
			if [regexp -- "family" $distro] {
				set info [clock format [clock second] -format %Y-%m-%d]
			} else {
				foreach pkg $pkglist {
					append info "[exec bash -c "distro-compose -p ^$pkg-\[0-9] -d ^$distro$|sed -n 2p"],"
				}
			}
			lappend gset -info=$info
		} else {
			if {[regexp -- {^kernel-} $v]} {
				lappend gset -nvr=$v
			} else {
				lappend gset -install=$v
			}
		}
	}
	set distro_gset_ [concat $distro $gset]

	sqlite3 db $dbfile
	db timeout 6000
	db transaction {
		foreach testid_ [split $testList ";"] {
			if {$testid_ == ""} continue
			set sql {
				UPDATE OR IGNORE testrun
				    set jobid='', testStat='', res='o', rstat='', taskuri='', abortedCnt=0, resdetail=''
				    WHERE testid = $testid_ and distro_rgset = $distro_gset_;
				INSERT OR IGNORE INTO testrun (testid, distro_rgset, abortedCnt, res, testStat)
				    VALUES($testid_, $distro_gset_, 0, '-', '')
			}
			db eval $sql
		}
	}
	wapp {<span style="font-size:400%;">Update ... Done!<br></span>}
  }

  set newRunQuery "run-[wapp-param pkg]=[string map {= %3D { } +} $distro_gset_]"
  set ourl "[wapp-param BASE_URL]?[wapp-param QUERY_STRING]"
  set nurl "$ourl&$newRunQuery"
  wapp-subst {return to %unsafe($nurl)}
  wapp-subst {
	<head>
	<META HTTP-EQUIV="Refresh" CONTENT="1; URL=%unsafe($nurl)">
	</head>
	<body></body>
	</html>
  }
}

proc wapp-page-delTestCase {} {
  wapp-allow-xorigin-params
  set permission yes

  set user [lindex [wapp-param user] end]
  set dbfile [dbroot $user]/testrun.db
  if {[string match {localhost:*} [wapp-param HTTP_HOST]]} { ""; }

  wapp {<html>}
  set testList [wapp-param testlist]
  if {$permission != yes} {
	wapp {<span style="font-size:400%;">You have no permission to do this!<br></span>}
  } elseif {![file exists $dbfile]} {
	wapp {<span style="font-size:400%;">There is not dbfile, something is wrong!<br></span>}
  } elseif {$testList != ""} {
	sqlite3 db $dbfile
	db timeout 6000
	db transaction {
		foreach testid [split $testList ";"] {
			if {$testid == ""} continue
			db eval "DELETE FROM testrun WHERE testid = '$testid'"
		}
	}
	wapp {<span style="font-size:400%;">Update ... Done!<br></span>}
  }

  set defaultUrl "[wapp-param BASE_URL]?[wapp-param QUERY_STRING]"
  wapp-subst {return to %unsafe($defaultUrl)}
  wapp-subst {
	<head>
	<META HTTP-EQUIV="Refresh" CONTENT="1; URL=%unsafe($defaultUrl)">
	</head>
	<body></body>
	</html>
  }
}

proc wapp-page-host-usage {} {
  wapp-allow-xorigin-params
  set user [lindex [wapp-param user] end]
  set hostinfo [::runtestlib::hostUsed $user]
  set serveraddr [wapp-param HTTP_HOST]
  set clientip [wapp-param REMOTE_ADDR]
  wapp-subst {{
    "hostusage": "%unsafe($hostinfo)",
    "servaddr": "%unsafe($serveraddr)",
    "clntip": "%unsafe($clientip)"
  }}
}

wapp-start $argv
