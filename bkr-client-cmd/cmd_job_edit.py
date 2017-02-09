# -*- coding: utf-8 -*-

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

"""
bkr job-edit: Clone existing Beaker jobs
=========================================

.. program:: bkr job-edit

Synopsis
--------

| :program:`bkr job-edit` <taskspec>...

Description
-----------

Specify one or more <taskspec> arguments to be edited.

This specific job's xml will be downloaded and promt to you with vim
editor, you can edit this xml file then save and exit. The xml file
you edited will be printed to standard output and submitted via
bkr job-submit.

The <taskspec> arguments follow the same format as in other :program:`bkr`
subcommands (for example, ``J:1234``). See :ref:`Specifying tasks <taskspec>`
in :manpage:`bkr(1)`.

Only jobs and recipe sets may be edited.

Common :program:`bkr` options are described in the :ref:`Options
<common-options>` section of :manpage:`bkr(1)`.

Exit status
-----------

Non-zero on error, otherwise zero.
A failure in cloning *any* of the arguments is considered to be an error, and
the exit status will be 1.

Examples
--------

Edit job 1234:

    bkr job-edit J:1234

See also
--------

:manpage:`bkr(1)`
"""

import sys
import os
from bkr.client import BeakerCommand
from optparse import OptionValueError
from bkr.client.task_watcher import *
from xml.dom.minidom import parseString

class Job_Edit(BeakerCommand):
    """Clone Jobs/RecipeSets"""
    enabled = True

    def options(self):
        self.parser.usage = "%%prog %s [--dry-run] <taskspec>..." % self.normalized_name
        self.parser.add_option(
            "--dryrun",
            default=False,
            action="store_true",
            help="Test the likely output of job-edit without cloning anything",
        )

    def run(self, *args, **kwargs):
        self.check_taskspec_args(args, permitted_types=['J', 'RS'])

        dryrun = kwargs.pop("dryrun", None)

        submitted_jobs = []
        failed = False
        clone = True
        self.set_hub(**kwargs)
        for task in args:
            try:
                task_type, task_id = task.split(":")
                if task_type.upper() == 'RS':
                    from_job = False
                else:
                    from_job = True
                jobxml = self.hub.taskactions.to_xml(task, clone, from_job)
                # XML is really bytes, the fact that the server is sending the bytes as an
                # XML-RPC Unicode string is just a mistake in Beaker's API
                jobxml = jobxml.encode('utf8')

                xmlfstr = '/tmp/' + task_id + '.xml'
                cmdstr = 'rm -f ' + xmlfstr
                os.system(cmdstr)
                of = open(xmlfstr, "w", 0)
                of.write(parseString(jobxml).toprettyxml(encoding='utf8'))
                of.close()
                cmdstr = 'vim ' + xmlfstr
                os.system(cmdstr)
                of = open(xmlfstr, "r", 0)
                jobxml = of.read()
                of.close()
                print "==============="
                print jobxml

                if not dryrun:
                    submitted_jobs.append(self.hub.jobs.upload(jobxml))
            except Exception, ex:
                failed = True
                raise
                print >>sys.stderr, ex
        if not dryrun:
            print "Submitted: %s" % submitted_jobs
        if failed:
            sys.exit(1)
