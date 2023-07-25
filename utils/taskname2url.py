#!/usr/bin/env python3
#auther: <jiyin@redhat.com>
#function: get the fetch-url corresponding to taskname
#require: fetch-url database. default: /etc/beaker/fetch-url.ini

import configparser
import io,os,sys,re

usage = f"Usage: {sys.argv[0]} <taskname> [[/path/to/config|url]..] [-h] [-repo=rname,url] [-task=task,uri] [-skiprepo] [-d|-debug]"
task = None
conf = None
debug = 0
repodict = {}
taskdict = {}
skiprepo = "no"
conf_str = ""
confUrl = "http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved/conf/fetch-url.ini"
defaultConfList = ["/etc/fetch-url.ini", "/etc/beaker/fetch-url.ini"]
confList = []
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
            confList.append(arg)
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
    print(usage, file=sys.stderr)
    exit(1)

def curl2str(url):
    httpcode = 0
    ret = ""
    if 'pycurl' not in sys.modules:
        import pycurl
    if 'BytesIO' not in sys.modules:
        from io import BytesIO
    buf = BytesIO()
    curl = pycurl.Curl()
    curl.setopt(curl.URL, url)
    curl.setopt(pycurl.FOLLOWLOCATION, 1)
    curl.setopt(curl.WRITEDATA, buf)
    try:
        curl.perform()
        if 200 == curl.getinfo(pycurl.HTTP_CODE):
            ret = buf.getvalue().decode('utf8')
    except pycurl.error as e:
        message = e
        if (debug > 0):
            print(f"[ERROR] curl.perform error: {e}", file=sys.stderr)
        pass
        buf.seek(0)
        buf.truncate()
    if (debug > 0):
        print(f"[ERROR] httpcode: {curl.getinfo(pycurl.HTTP_CODE)}, url: {url}", file=sys.stderr)
    curl.close()
    return ret

for file in defaultConfList:
    if os.path.isfile(file):
        with open(file, 'r', errors='ignore') as fobj:
            conf_str += fobj.read()

if (not conf_str.strip()):
    conf_str += curl2str(confUrl)

for conf in confList:
    if re.match("^(ftp|https?)://", conf):
        conf_str += curl2str(conf)
    elif os.path.isfile(conf):
        with open(file, 'r', errors = 'ignore') as fobj:
            conf_str += fobj.read()

if (not conf_str.strip()):
    print(f"[ERROR] all config files or urls are not available!", file=sys.stderr)
    exit(1)

config = configparser.ConfigParser(strict=False)
config.read_string(conf_str)

if (debug > 0):
    print(f"[DEBUG] {config.sections()}", file=sys.stderr)

if config.has_section('repo-url'):
    for r in repodict:
        config['repo-url'][r] = repodict[r]
else:
    print(f"[ERROR] 'repo-url' section not found, please check config files/urls", file=sys.stderr)
    exit(1)

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
