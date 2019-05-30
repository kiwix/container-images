#!/usr/bin/python3
#
# Description : update a wiki page from a file
#
# Usage : ./updateWikiPage.py <wikiURL> <user> <password> <pageName> <wikiFile> <modifComment>
#
# Author : Florent Kaisser
#

from mwclient import Site
import sys

if(len(sys.argv) < 7):
  print("bad args")
  print("usage ./updateMWPage <wikiURL> <user> <password> <pageName> <wikiFile> <modifComment>")
else:
  wikiURL = sys.argv[1]
  user = sys.argv[2]
  password = sys.argv[3]
  pageName = sys.argv[4]
  wikiFile = sys.argv[5]
  modifComment = sys.argv[6]

  site = Site(wikiURL)
  site.login(user,password)
  page = site.pages[pageName]
  
  with open(wikiFile) as f:
    page.text = f.read()
    page.save(modifComment)
    print("%s is updated !" % (pageName))
  f.closed

