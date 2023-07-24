#!/usr/bin/env python3
#auther: <jiyin@redhat.com>
#function: get the fetch-url corresponding to taskname
#require: fetch-url database. default: /etc/beaker/fetch-url.ini

import configparser
import io,os,sys,re

usage = f"Usage: {sys.argv[0]} <taskname> [/path/to/config|url] [-h] [-repo=rname,url] [-task=task,uri] [-skiprepo] [-d|-debug]"
task = None
conf = None
debug = 0
repodict = {}
taskdict = {}
skiprepo = "no"
defaultConf = "/etc/beaker/fetch-url.ini"
confUrl = "http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved/conf/fetch-url.ini"
for arg in sys.argv[1:]:
    if (arg[0] != '-'):
        if (task == None):
            task = arg
            if not re.match("^/", task):
                task=f"/{task}"
            _task = re.sub("^(/?CoreOS)?/", "", task)
            repo = _task.split("/")[0]
            path = _task.replace(f"{repo}/", "")
        elif (conf == None):
            conf = arg
    else:
        if (arg[:2] == "-h"):
            print(usage); exit(0)
        elif (arg[:2] == "-d"):
            debug += arg.count('d')
        elif (arg[:6] == "-repo="):
            rname, url = arg[6:].split(",")
            repodict[rname] = url
        elif (arg[:6] == "-task="):
            tname, uri = arg[6:].split(",")
            taskdict[tname] = uri
        elif (arg[:5] == "-skip"):
            skiprepo = "yes"
if (_task == None):
    print(usage, file=sys.stderr); exit(1)

if (conf == None):
    conf = defaultConf
if re.match("^(ftp|https?)://", conf):
    confUrl = conf

config = configparser.ConfigParser()
if not os.path.isfile(conf):
    import pycurl
    from io import BytesIO
    curl = pycurl.Curl()
    bio = BytesIO()
    curl.setopt(curl.URL, confUrl)
    curl.setopt(pycurl.FOLLOWLOCATION, 1)
    curl.setopt(curl.WRITEDATA, bio)
    curl.perform()
    curl.close()
    conf_str = bio.getvalue().decode('utf8')
    #buf = io.StringIO(conf_str)
    #config.read_file(buf)
    config.read_string(conf_str)
else:
    config.read(conf)

if (debug > 0):
    print(f"[DEBUG] {config.sections()}")

if config.has_section('repo-url'):
    for r in repodict:
        config['repo-url'][r] = repodict[r]
else:
    print(f"[ERROR] 'repo-url' section not found, please check config file: {conf}")
    exit()

if task in taskdict.keys():
    print(taskdict[task])
elif _task in taskdict.keys():
    print(taskdict[_task])
elif config.has_option('task-url', task):
    print(config['task-url'][task])
elif skiprepo == "yes":
    exit(0)
elif config.has_option('repo-url', repo):
    print(f"{config['repo-url'][repo]}#{path}")
else:
    print(f'''{config['repo-url']['__pkg__'].replace("__pkg__", repo)}#{path}''')
