#!/usr/bin/python

import os
import re
import sys
import shutil
from datetime import date, timedelta

MAX_AGE = 30
DIRS = ['/var/www/download.kiwix.org/src/nightly',
        '/var/www/download.kiwix.org/bin/nightly']

# use argv[1] as max_age if provided
if len(sys.argv) > 1:
    try:
        MAX_AGE = int(sys.argv[1])
    except:
        pass

today = date.today()

for target in DIRS:

    print(u"Cleaning up %s" % target)

    for folder in os.listdir(target):

        print(folder)

        # if folder is not a date, skip it
        if not re.match(r'\d{4}\-\d{2}\-\d{2}', folder):
            continue

        try:
            folder_date = date(*[int(i) for i in folder.split('-')])
        except:
            # skip if we can't cast to a date
            continue

        if folder_date > (today - timedelta(MAX_AGE)):
            # skip if not older than MAX_AGE
            continue

        # now we know we must delete it.
        print(u"removing: %s" % os.path.join(target, folder))
        shutil.rmtree(os.path.join(target, folder))
        
