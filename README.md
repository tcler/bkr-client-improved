# bkr-client-improved

Unofficial tools for [beaker-project](https://beaker-project.org/) with improved features and customized options.

![High-level design](https://raw.githubusercontent.com/tcler/bkr-client-improved/master/img/hld-bkr-test-robot.png)
![bkr test robot](https://raw.githubusercontent.com/tcler/bkr-client-improved/master/img/demo.gif)
![bkr test diff](https://raw.githubusercontent.com/tcler/bkr-client-improved/master/img/bkr-autorun-diff.png)
![bkr test diff1](https://raw.githubusercontent.com/tcler/bkr-client-improved/master/img/bkr-autorun-diff1.png)

## Features

- Implement `newcase.sh` to replace `beaker-wizard`, which works better for multi-level directory and mutli-host.
- Implement `gen_job_xml` to support complicated options setting for each role or recipeset.
- Add `subtest.yml` to define each test's attribution/parameter/requirement. User don't need to read the code to study how to run it, and easy to extend one test case to multiple test items.
- Implement `lstest/bkr-runtest` to submit test jobs to beaker from git dir, the action is convenient, fast, grouped and hardware resources saving. User don't need maintain tedious job XML and parameters.
- Implement `bkr-autorun-*` to submit test jobs, monitor job status, report test results, and save results in database for easy querying and comparing.
- Supply some useful scripts for QE.

## Install

```bash
git clone https://github.com/tcler/bkr-client-improved
cd bkr-client-improved
sudo make install  # or "sudo make install_all" to install the beaker-test-robot tools
```

Notes:

1. The tools depends on official [beaker-client](https://beaker-project.org/docs/user-guide/bkr-client.html), please make sure you have it installed.
2. The installation script just support Fedora/RHEL

## Usage

*   ***lstest*** - List Test items from test case dir

    ```
	Usage: lstest [--raw | -e[~/.bkr-client-improved/bkr.recipe.matrix.conf] | -t <maxtime>] [$dir ...]
	Example: lstest /kernel/filesystems/nfs/regression

	```

*   ***gen_job_xml*** - Generate Beaker job XML file, like `bkr workflow-simple`, but have many improvements and unofficial options support

    ```
	Usage: gen_job_xml --distro=<DISTRO> [options]
	Example: gen_job_xml --distro RHEL-6.6 --task=/distribution/reservesys --arch=x86_64
	Example: gen_job_xml --family RedHatEnterpriseLinux7 -F test.list --nvr=kernel-x.y.z-abc.el7 --dbgk

	```
	(Use `gen_job_xml -h` to check all available options)

*   ***bkr-runtest*** - Genarate job XML files from test items (by `lstest` and `gen_job_xml`), then group them (by hardware requirement) and submit to beaker

	```
	Usage0: runtest [options] <distro[,distro,...]> [-|testfile...] [gen_job_xml options] 
	Usage1: runtest [options] <family[,family,...]> [-|testfile...] [gen_job_xml options]

	Example 1: runtest RHEL-7.3 nfs.list
	Example 2: lstest /some/path/case | runtest RHEL-6.6 --netqe-nic-driver=tg3 --netqe-nic-num=2
	Example 3: lstest ./pnfs/blklayout | runtest runtest Fedora-22,RHEL-7.2,RHEL-7.2 
	Example 4: runtest RHEL-7.4 --arch=x86_64 --kdump --nvr=upstream # reserve a host with upstream kernel
	```
	(Use `bkr-runtest -h` to get more helps)

*   ***bkr-autorun-**** - Utils to automatically submit test jobs, monitor test status, save and report test results

    1. To create/delete test items for the monitor: `bkr-autorun-create/bkr-autorun-del`
    2. To monitor test items' status and save results: `bkr-autorun-monitor` (It will automatically be triggered by crontab)
    3. To check the stat and result of the test-run (by CLI): `bkr-autorun-stat`
    4. To check the stat and result of the test-run (by Web page): `sudo trms-service.sh start` then check `http://$url:$port?user=$user`. (use `trms-service.sh stat|grep url:` get the $url info)
    5. To compare/diff two test-runs: `bkr-autorun-diff.sh`

      (Use `-h` option to study each tool's usage)

*   ***Utils***
    - `newcase.sh`: create a new test case template
	- `vershow`: show the version of the package in special distro
	- `getLatestRHEL`: get the latest distro name which can install in beaker
	- `searchBrewBuild/downloadBrewBuild/installBrewPkg`: search/download/install package build from brew
	- `parse_netqe_nic_info.sh`: Get network-qe special machines by NIC driver/model/num/...

      (Check utils dir to get more)

## Reference

* https://github.com/beaker-project
* https://beaker-project.org/
* https://beaker-project.org/docs/user-guide/bkr-client.html
