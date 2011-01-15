#!/usr/bin/python
# -*- coding: utf-8 -*-

# Licensed under the GPL v3
# Written by Alex Mandel
# Version 0.1 Dec, 2010

#Script to compile the download statistics from Launchpad ppa for qgis
#Based on ticket https://bugs.launchpad.net/soyuz/+bug/139855
from launchpadlib.launchpad import Launchpad
import csv, datetime
cachedir = "/home/kelson/.launchpadlib/cache/"

#Connect to launchpad as the ppastats user, using the edge development server since the main server does not have the count stats yet
#API docs
launchpad = Launchpad.login_with('ppastats', 'edge', cachedir, version='devel')
team = launchpad.people['kiwixteam']
#Todo: Create a class for the launchpad connections

def getData(team):
    try:
        #Todo: Create loop to look at all 3 ppas stable, testing and unstable
        getppa = team.getPPAByName(name='ppa')

        #If you wanted to filter more here's where you do it, you can do exact package names, distro and even arch
        #desired_dist_and_arch = "https://api.edge.launchpad.net/devel/ubuntu/lucid/amd64"
        binaries = getppa.getPublishedBinaries()
        result = getStats(binaries)
        return
    except:
        print "error"
        
def getStats(ppafiles):
    try:
        #A list for holding the statistics
        stats = []
        for package in ppafiles:
            #Note: Does not currently return the real value as launchpad has not completed scanning all the web logs and compiling the information.
            stack = [package.binary_package_name,package.binary_package_version,str(package.getDownloadCount())]
            stats.append(stack)
            #print package.binary_package_name +"\t"+ package.binary_package_version + "\t" + str(package.getDownloadCount())
        writeout(stats)
        return
    except:
        print "error getting stats"
        
def writeout(data):
    try:
        #write the stats out to a csv for import into something more analytic(database,R)?
        d = datetime.datetime.today()
        datestring = d.strftime("%Y-%m-%d")
        filename = "kiwix-ppastats"+datestring+".csv"
        w=csv.writer(file(filename,'wb'))
        w.writerows(data)
        return

    except csv.Error, e:
        sys.exit('file %s, line %d: %s' % (filename, reader.line_num, e))

       

if __name__ == "__main__":
    getData(team)
    print "Done"
