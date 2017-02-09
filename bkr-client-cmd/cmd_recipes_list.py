
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

"""
bkr recipes-list: List Beaker recipes
==============================

.. program:: bkr recipes-list

Synopsis
--------

| :program:`bkr recipes-list`

Description
-----------

Prints to stdout a partial status of user's comsuming recipes

Exit status
-----------

Non-zero on error, otherwise zero.

Examples
--------

     bkr recipes-list

"""

from bkr.client import BeakerCommand
import bkr.client.json_compat as json
from optparse import OptionValueError

class Recipes_List(BeakerCommand):
    """List partial Beaker recipes of mine"""
    enabled = True
    requires_login = False

    def ppcnt(self, cnt, msg):
	if cnt > 0:
		print repr(cnt) + msg,

    def run(self, *args, **kwargs):

        self.set_hub(**kwargs)
        self.hub._login()
        jobs = self.hub.recipes.mine().encode('utf-8')

	ncnt = jobs.count('statusNew')
	pcnt = jobs.count('statusProcessed')
	qcnt = jobs.count('statusQueue')
	scnt = jobs.count('statusScheduled')
	wcnt = jobs.count('statusWaiting')
	icnt = jobs.count('statusInstalling')
	rcnt = jobs.count('statusRunning')

	print "{0}".format(ncnt+pcnt+rcnt+qcnt+scnt+wcnt+icnt)
	self.ppcnt(ncnt, " New ")
	self.ppcnt(pcnt, " Processed ")
	self.ppcnt(qcnt, " Queue ")
	self.ppcnt(scnt, " Scheduled ")
	self.ppcnt(wcnt, " Waiting ")
	self.ppcnt(icnt, " Installing ")
	self.ppcnt(rcnt, " Running ")
	print "on the first page"
	if ncnt+pcnt+rcnt+qcnt+scnt+wcnt+icnt == 50:
		print "There are more recipes"
