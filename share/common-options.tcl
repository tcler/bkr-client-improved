
set CommonOptionList {

  "\n  Options for job configuration:" {
	harness			{arg y	help {specify alternative harness, available value: beah|restraint; default: restraint}}
	{fetch-url}		{arg m	help {specify restraint fetch url. e.g:
				--fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2
				--fetch-url kernel@https://github.com/User/Repo/archive/refs/heads/master.tar.gz
				--fetch-url kernel@git://freetest.org/linux-nfs/public_git/tests.git?master
				--fetch-url nfs-utils@https://pkgs.devel.rh.com/cgit/tests/nfs-utils/?master

				--fetch-url no      #means disable fetch-url
				--fetch-url rname@  #means disable fetch-url for all task like: /rname/relative/path
				}}
	task-fetch-url		{arg m	help {accept a fetch url for a special task. e.g:
				--task-fetch-url /distribution/kernelinstall@https://gitlab.com/redhat/centos-stream/tests/kernel/kernel-tests/-/archive/main/kernel-tests-main.tar.gz#distribution/kernelinstall
				--task-fetch-url /distribution/kernelinstall@https://gitlab.com/redhat/centos-stream/tests/kernel/kernel-tests/-/archive/main/kernel-tests-main.tar.gz#..   #Same effect as above. here '..' means use the full-path of /task/name instead relative-path
				--task-fetch-url /kernel/fs/nfs/base@http://fs-qe.usersys.redhat.com/ftp/pub/jiyin/kernel-test.tgz   #the '#relative path' could be omitted
				--task-fetch-url /distribution/kernelinstall@   #means disable fetch-url for this task
				}}
	keepchanges		{arg n	help {see: https://restraint.readthedocs.io/en/latest/jobs.html#keeping-your-task-changes-intact}}
	fetch-opts		{arg y	help {task fetch options, e.g: "retry=8 timeo=32 abort-fetch-fail"}}
	nrestraint		{arg n	help {use restraint devel build}}
	nrestraint-repo		{arg y	help {restraint repo relace default value}}
	restraint-repo		{arg y	link {nrestraint-repo}  hide y}
	autopath		{arg n	link {auto generate ?path= param to fetch url; Please ensure that dependencies are installed in advance.}}
	norun			{arg n	help {only download task without running it}}
	cc			{arg m	help {Notify additional e-mail address on job completion}}
	job-owner		{arg y	help {Submit job on behalf of USERNAME (submitting user must be a submission delegate for job owner)}}
	{wb whiteboard}		{arg y	help {Set the whiteboard for this job}}
	repo			{arg m	help {Configure repo at <URL> in the kickstart for installation}}
	repo-post		{arg m	help {Configure repo at <URL> as part of kickstart %post execution}}
	recipe			{arg n	help {Just generate recipeSet node, internal use for runtest -merge}}
	rwb			{arg y	help {Set the whiteboard for the recipe}}
	{info flag}             {arg y	help {do nothinig, just used by caller} hide yes}
	retention-tag           {arg y  help {e.g: scratch, 60days, 120days, active, active+1, audit}}
	product                 {arg y  help {e.g: cpe:/o:redhat:enterprise_linux:$x:$y}}
	packages                {arg y	help {e.g: --packages=gcc,screen,wget. or use '/' instead ','}}
  }

  "\n  Options for selecting distro tree(s):" {
	{dr distrorequire}	{arg m	help {distrorequire --dr=key="value"}}
	{DR}			{arg m	help {distroRequires for multi-host test. e.g:
				--DR="distro_arch=x86_64"
				}}
	family			{arg m	help {Use latest distro of this FAMILY for job, eg. "RedHatEnterpriseLinux6",
                                same as --dr=distro_family=\$FAMILY}}
	tag			{arg m	help {Use latest distro tagged with TAG(default: RTT_ACCEPTED),
				same as --dr=distro_tag=\$TAG
				Commonly used labels for test looks like:
				 RTT_ACCEPTED,RTT_ACCEPTED_PRIMARY,RTT_PASSED,RTT_PASSED_PRIMARY
				 DevelPhaseExit-1.0,Alpha-1.0,Beta-1.0,Snapshot-1.0,RC-1.0,RELEASED ...
}}
	distro			{arg y	help {Use named distro for job, same as --dr=distro_name=\$DISTRO}}
	distrot			{arg y	help {define distro template for multihost test, eg: --distrot=6,6,%D)}}
	{variant v}		{arg m	help {Specify the distro variant, same as --dr=distro_variant=\$VARIANT}}
	arch			{arg y	help {Specify the distroRequire.disro_arch and hostRequire.arch, same as: --dr=distro_arch=\$ARCH --hr=arch=\$ARCH}}
  }

  "\n  Options for selecting system(s):" {
	{topo}			{arg y	help {Include NUMBER server and client hosts for multi-host test. eg --topo=multiHost.1.1}}
	{servers s}		{arg y	help {Include NUMBER server hosts for multi-host test}}
	{clients c}		{arg y	help {Include NUMBER client hosts for multi-host test}}
	{hr hostrequire}	{arg m	help {Additional <hostRequires><and/> for job, example:
				--hr group=fs-qe
				--hr pool=fs-qe
				--hr cpu_count>=4
				--hr memory>=4096
				--hr labcontroller=lab-01.rhts.eng.pek2.redhat.com
				--hr cpu.flags~%avx2%
				--hr kv-CPUFLAGS=avx2
				--hr kv-CPUMODEL=%Broadwell%
				--hr device:type=STORAGE,driver=nvme
				--hr disk.phys_sector_size=4096,unit=bytes
				--hr key_value:key=CPUVENDOR,op==,value=\$Vendor  #same as --kv CPUVENDOR=\$Vendor
				--hr 'kv-DISKSPACE>=60000'      #same as --kv 'DISKSPACE>=60000'
				--hr kv-CPUVENDOR~%AMD%         #~%AMD%  =AuthenticAMD
				--hr 'system.numanodes>=4'      #same as --sr 'numanodes>=4'
				--hr top:system_type=Machine    #same as --systype=Machine
				--hr or:tag=value
				--hr not:kv-CPUVENDOR~%Intel%   #~%Intel%  =GenuineIntel
				}}
	lab			{arg m	help {alias of --hostrequire=or:labcontroller=value, e.g: --lab=pek2,bos}}
	{HR}			{arg m	help {hostRequires for multi-host test. e.g:
				--HR= --HR="memory>4096 key_value:key=DISK,op=>,value=80000"
				#means no requires for 1st host, and 2nd need more than 4096M ram and more than 80G disk size
				}}
	p9			{arg n  hide y}
	{kv keyvalue}		{arg m	help {Require system with matching legacy key-value, same as '--hr=key_value:key=K,op=Op,value=Val' example: --kv NETWORK=e1000}}
	{sr sysrequire}		{arg m	help {Additional <hostRequires><and><system/> for job, same as '--hr=system.key=value' example: --sr numanodes=4}}
	{opt-alias hr-alias}		{arg y	help {alias of long and changeable options combination}}
	{opt-alias-file hr-alias-file}		{arg y	help {opt-alias will search alias in this file}}
	machine			{arg m	help {Require the machine for job, set comma-separated values for multi-host, example: --machine=SERVER1,CLIENT1}}
	systype			{arg m	help {Require system of TYPE for job (Machine, Prototype, Laptop, ..) default: Machine}}
	ormachine		{arg m	help {Use comma-separated values to set a machine pool, example: --ormachine=HOST1,HOST2,HOST3}}
	random                  {arg n  help {autopick type}}
	hrxml                   {arg y  help {deprecated, see --hr option}}
  }

  "\n  Options for selecting special system(s) of networ-qe:" {
	nay-driver		{link netqe-nic-driver	hide y}
	nic-num			{link netqe-nic-num	hide y}
	nay-nic-driver		{link netqe-nic-driver	hide y}
	nay-nic-num		{link netqe-nic-num	hide y}
	nay-nic-model		{link netqe-nic-model	hide y}
	nay-nic-speed		{link netqe-nic-speed	hide y}
	nay-nic-match		{link netqe-nic-match	hide y}
	nay-nic-unmatch		{link netqe-nic-unmatch hide y}
	netqe-nic-pciid		{arg o help ""}
	netqe-nic-driver	{arg o help ""}
	netqe-nic-num		{arg o help ""}
	netqe-nic-model		{arg o help ""}
	netqe-nic-speed		{arg o help ""}
	netqe-nic-match		{arg o help ""}
	netqe-nic-unmatch	{arg o help {These options together generate the machine pool which match required NIC num/driver/model/speed
				- Refer `parse_netqe_nic_info.sh -h`, which is the engine for the translating.
				  Example: --netqe-nic-driver=e1000e --netqe-nic-num=2
				- Use comma-separated values for different machine pool of multihost
				  Example: --netqe-nic-driver=e1000e,any --netqe-nic-num=2 --netqe-nic-speed=1g }}
  }

  "\n  Options for setting tasks:" {
	task			{arg m	help {Include named task in job, can use multiple times:
				e.g: --task /path/to/case1 --task "/path/to/case2 param1=val1 {param2=val2 with space}"}}
	insert-task		{arg m	help {Insert named task before task list, can use multiple times:
				e.g: --insert-task /path/to/caseA --insert-task "/path/to/caseB param1=val1 {param2=val2 with space}"}}
	append-task		{arg m	help {Append named task after task list, can use multiple times:
				e.g: --append-task /path/to/caseX --append-task "/path/to/caseY param1=val1 {param2=val2 with space}"}}
	taskn			{arg y	help {repeat task 'N' times}}
	reboot			{arg y	help {add reboot after each task}}
	{param taskparam}	{arg m	help {Set task params, can use multiple times.
				Use "mh-" prefix to set different value for multihost, example: --param=mh-key=val1,val2}}
	tasksdesc		{arg y	help {common tasks description, will append to task-name in job xml}}
	maxtime			{arg y	help {alias of --param=KILLTIMEOVERRIDE=<maxtime>}}
	noavc			{arg n	help {alias of --param=AVC_ERROR=+no_avc_check}}
	nvr			{arg m	help {Specify the kernel(Name-Version-Release) to be installed}}
	install			{arg m	help {Install PACKAGE using /distribution/pkginstall, can use multiple times}}
	upstream		{arg o	help {Specify the kernel src git addr to be installed. --upstream=[git://a.b.c/d[#branch[@tag]]]
				e.g: --upstream
				e.g: --upstream=#v4.18-rc1
				e.g: --upstream=git://git.linux-nfs.org/projects/bfields/linux.git#jbf-test-1
				e.g: --upstream=git://git.linux-nfs.org/projects/bfields/linux.git@$commit_id}}
	upstream-use-clone	{arg o	help {use git-clone instead default git-archive, in case some repo doesn't support git-archive
				- the optional option param is additional option/param of git-clone
				e.g: --upstream-use-clone=--depth=1}}
	upstream-patch		{arg y	help {apply specified patch[es] before compile upstream kernel}}
	upstream-kernel-kasan   {arg n  help {Flag to enable upstream kernel kasan support}}
	kpatch			{arg y	help {apply specified patch[es] and install kernel; ref: /distribution/kpatchinstall
				e.g: --kpatch=kernel-5.14.0-284.18.1.el9_2,kpatch-patch-5_14_0-284_18_1-1-6.el9_2
				e.g: --kpatch=kernel-5.14.0-284.18.1.el9_2,kpatch-patch-5_14_0-284_18_1-1-6.el9_2,$kpatch_url}}
	{Brew B Scratch}	{arg m  help {Install brew built or 3rd party pkg[s] by using /distribution/brew-build-install, can use multiple times
				e.g: --Brew=\$brew_scratch_build_id              #install according brew scratch build id
				e.g: --Brew=\$brew_build_name                    #install according brew build name
				e.g: --Brew=nfs:\$nfsserver:/path/to/rpms/a.rpm  #install specified rpm from nfs
				e.g: --Brew=nfs:\$nfsserver:/path/to/rpms/       #install all rpms in nfs share
				e.g: --Brew=repo:\$reponame,baseurl              #install all rpms in yum repo \$reponame
				e.g: --Brew=https://host/path/to/rpms/b.rpm      #install specified rpm from https/http/ftp
				e.g: --Brew=https://host/path/to/rpms/           #install all rpms in web path https/http/ftp
				e.g: --Brew=lstdtk             #install latest brew dt kernel
				e.g: --Brew=lstk               #install latest brew release kernel
				e.g: --Brew=upk                #install latest brew upstream kernel
				e.g: --Brew=$build -debugk     #install debug kernel if it's a kernel build
				e.g: --Brew=-debugk            #install debug kernel of the default kernel}}
	{brew b scratch}	{arg m  help {same as Brew, but every specified just apply one host, if in multihost mode}}
	dbgk			{arg n	help {Use the debug kernel}}
	gcov			{arg y	help {Enable gcov for coverage data collection, use arg to specify Package, example: --gcov="nfs-utils"}}
	kcov			{arg o	help {Enable kcov for coverage data collection, use arg to specify KDIR, example: --kcov="fs, drivers/net"}}
	kdump			{arg o	help {Enable kdump using /kernel/kdump/setup-nfsdump}}
	crashsize               {arg y  help {specify/custom kdump crashsize}}
	nokdump			{arg n	help {disable kdump, some tests can not work with kdump}}
	cmd			{arg m	help {Add /distribution/command before test task}}
	cmd-and-reboot		{arg m	help {Add /distribution/command before test task, and reboot}}
	cmdb			{arg m	help {Add /distribution/command before install kernel}}
	cmd-end			{arg m	help {Add /distribution/command in the end of the recipe}}
	leap-second		{arg n	help {Add leap-second task}}
	reserve-if-fail		{arg o	help {Reserve the machine if test fail, specify RESERVETIME with s/m/h/d unit, max amount is 99h}}
	reserve			{arg o	help {Reserve system at the end of the recipe}}
	fips                    {arg o  help {enable fips}}
	abrt                    {arg n  help {enable abrt(insert /distribution/crashes/enable-abrt)}}
	watchdog-panic          {arg y  help {set <watchdog panic="{reboot|ignore|None}"/>}}
	ignore-panic            {arg n  help {Do not abort job if panic message appears on serial console}}
  }

  "\n  Options for installation:" {
	{part partition}	{arg m	help {Additional <partitions/> for job, example: --part='fs=xfs name=/mnt/xfs size=10 type=part'}}
	method			{arg y	help {Installation source method (nfs, http, ftp)}}
	ks-meta			{arg m  help {Pass kickstart metadata OPTIONS when generating kickstart}}
	ks-append		{arg m	help {append additional fragment to the base kickstart file}}
	ks			{link ks-append hide y}
	ks-pkgs			{arg m	help {append additional packages to %packages section in base kickstart file}}
	ks-post			{arg m	help {append additional commands to %post section in the base kickstart file}}
	ks-pre			{arg m	help {append additional commands to %pre section in the base kickstart file}}
	ksf			{arg y	help {Similar to --ks-append, but pass the content of a specified file}}
	{k-opts kernel-options}	{arg m	help {Pass OPTIONS to kernel during installation}}
	{k-opts-post kernel-options-post}	{arg m	help {Pass OPTIONS to kernel after installation}}
  }
}

