#!/usr/bin/env python3
#auther: <jiyin@redhat.com>
#function: get the fetch-url corresponding to taskname
#require: fetch-url database. default: /etc/beaker/fetch-url.ini, /etc/fetch-url.ini

import configparser
import io,os,sys,re

usage = f"Usage: {sys.argv[0]} <taskname> [[/path/to/config|url]..] [-h] [-repo=rname@url] [-task=task@uri] [-skiprepo] [-d|-debug]"
task, _task = None, None
conf = None
debug = 0
repodict = {}
taskdict = {}
skiprepo = "no"
conf_str = ""
confUrl = "http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved/conf/fetch-url.ini"
defaultConfList = ["/etc/beaker/fetch-url.ini", "/etc/fetch-url.ini"]
confList = []
for arg in sys.argv[1:]:
    if (arg[0] != '-'):
        if (task == None):
            task = arg
            if not re.match("^/", task):
                task=f"/{task}"
            _task = re.sub("^(/?CoreOS)?/", "", task)
            _task = re.sub("/$", "", re.sub("/+", "/", _task))
            if re.match(".+/", _task):
                repo, rpath = _task.split("/", 1)
                _rpath = f"#{rpath}"
            else:
                repo, _rpath = _task, ""
        elif (conf == None):
            confList.append(arg)
    else:
        if (arg[:2] == "-h"):
            print(usage); exit(0)
        elif (arg[:2] == "-d"):
            debug += arg.count('d')
        elif (arg[:6] == "-repo="):
            if not re.search(r'[@,]', arg):
                arg = f"{arg}@"
            rname, url = re.split("[,@]", arg[6:])
            rname = re.sub("^/+", "", rname)
            repodict[rname] = url
        elif (arg[:6] == "-task="):
            if not re.search(r'[@,]', arg):
                arg = f"{arg}@"
            tname, uri = re.split("[,@]", arg[6:])
            tname = re.sub('^/+/', '/', tname)
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

def get_uri(uri, task):
    _uri = re.sub(r'#( |$)', r'\1', uri, 1)
    _tname = re.sub('^/+', '', task)
    _tname = re.sub("^(/?CoreOS)?/", "", _tname)
    if not re.search(r'#', _uri):
        _rpath = f"{re.sub('^/*[^/]+/', '', _tname)}"
        if not re.search(r' ', _uri):
            _uri += f"#{_rpath}"
        else:
            _uri = f"{re.sub(' ', f'#{_rpath} ', _uri, 1)}"
    if re.search(r'#\.\.( |$)', _uri):
        _uri = re.sub('#\.\.', f'#{_tname}', _uri, 1)
    return _uri

if task in taskdict.keys():
    print(get_uri(taskdict[task], task))
elif _task in taskdict.keys():
    print(get_uri(taskdict[_task], _task))
elif config.has_option('task-url', task):
    print(get_uri(config['task-url'][task], task))
elif skiprepo == "yes":
    exit(0)
elif config.has_option('repo-url', repo):
    if config['repo-url'][repo]:
        print(f"{config['repo-url'][repo]}{_rpath}")
else:
    print(f'''{config['repo-url']['__pkg__'].replace("__pkg__", repo)}{_rpath}''')
