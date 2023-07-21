#!/usr/bin/env python3
#auther: <jiyin@redhat.com>
#function: get the fetch-url corresponding to taskname
#require: fetch-url database. default: /etc/beaker/fetch-url.ini

import configparser
import io,os,sys,re

usage = f"Usage: {sys.argv[0]} <taskname> [/path/to/config] [-h] [-d|-debug] [-repo=rname,url] [-skiprepo]"
task = None
conf = None
defaultConf = "/etc/beaker/fetch-url.ini"
debug = 0
repodict = {}
skiprepo = "no"
for arg in sys.argv[1:]:
    if (arg[0] != '-'):
        if (task == None):
            task = arg
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
        elif (arg[:5] == "-skip"):
            skiprepo = "yes"
if (conf == None):
    conf = defaultConf

config = configparser.ConfigParser()
config.read(conf)
if (debug > 0):
    print(f"[DEBUG] {config.sections()}")

if config.has_section('repo-url'):
    for r in repodict:
        config['repo-url'][r] = repodict[r]
else:
    print(f"[ERROR] 'repo-url' section not found, please check config file: {conf}")
    exit()

if config.has_option('task-url', task):
    print(config['task-url'][task])
elif skiprepo == "yes":
    exit(0)
elif config.has_option('repo-url', repo):
    print(f"{config['repo-url'][repo]}#{path}")
else:
    print(f'''{config['repo-url']['__pkg__'].replace("__pkg__", repo)}#{path}''')
