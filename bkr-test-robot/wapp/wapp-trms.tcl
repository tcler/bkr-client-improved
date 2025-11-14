#package require wapp
source /usr/local/lib/wapp.tcl

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
            z-Index: -1;
        }

        .pkg-select.show {
            width: 100%;
            z-Index: 110;
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
    </style>
</head>
<body>
    <div class="header">
        <div class="logo"><a style="color: white;" href="/">🎃bkr-test-robot🎃</a></div>
    </div>

    <div class="container">
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

        // 模拟测试结果数据
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

        // 初始化界面
        function initializeInterface() {
            // 创建组件/包的radio控件
            createRadioButtons();

            // 初始化测试结果数据
            initializeTestResults();

            // 渲染表格
            renderTable();
        }

        // 创建radio按钮
        function createRadioButtons() {
            const queryField = document.getElementById('queryFieldset');
            const radioGroup = document.getElementById('pkgRadioGroup');
            radioGroup.innerHTML = '';

            const userform = document.createElement('input');
            userform.name = "user";
            userform.type = 'hidden';
            userform.value = getParam('user');
            queryField.insertBefore(userform, radioGroup);

            testruninfo.components.forEach(pkg => {
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

        function showDetail(id) {
            var cell = document.getElementById(id);
            var testid = cell.getAttribute("id");
            var divid = "div" + testid;
            var div = document.getElementById(divid);
            div.style.zIndex="100";
            div.style.display="block";
        }

        // 初始化测试结果数据
        function initializeTestResults() {
            if (qresults.results.length > 0) {
                return;
            }
            // 生成随机测试结果
	    const nrow = 5;
            const ncol = qresults.qruns.length;
            for (let i = 0; i < nrow; i++) {
                const resobj = {
                    testid: "abcdefg12345",
                    test: "test case foo, param foo",
		}
                for (let j = 0; j < ncol; j++) {
                    resobj['res'+j] = "pass pass 19867391#task204745781 19867391#task204745782";
                    resobj['resd'+j] = "stepa: pass\nstepb: pass\nstepc: pass";
		}
                qresults.results[i] = resobj;
            }
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
                row.ondbclick = function() { showDetail(testId); };

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
                    const resd = resObj['resd'+k];
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
                                linkA.style.color = "dark";
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

        // after page loaded
        document.addEventListener('DOMContentLoaded', function() {
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
                    initializeInterface();
                })
                .catch(error => {
                    console.error('Error:', error);
                });

            // Query button event
            /*document.getElementById('queryForm').addEventListener('submit', function(e) {
                e.preventDefault();
                alert('queryForm has been clicked!!');
            });*/
        });
    </script>
</body>
</html>
  }
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
</html>
  }
}

wapp-start $argv
