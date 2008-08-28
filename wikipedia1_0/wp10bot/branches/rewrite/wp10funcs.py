# -*- coding: utf-8  -*-

#
# (C) stanlekub, 2007-2008
#
# Distributed under the terms of the MIT license.
#
# $Id$

import re
import time
import urllib

import wp10config
import wp10database as wp10db

month = {
    u'janvier':     1,
    u'février':     2,
    u'mars':        3,
    u'avril':       4,
    u'mai':         5,
    u'juin':        6,
    u'juillet':     7,
    u'août':        8,
    u'septembre':   9,
    u'octobre':     10,
    u'novembre':    11,
    u'décembre':    12,
    }

def timestampFromHistoryDate(hdate):
    d = re.compile(ur'(?iLmsu)^(?P<jour>\d+)\s(?P<mois>.+?)\s(?P<annee>\d+) à')
    result = d.search(hdate)
    if not result:
        return 0

    if month.has_key(result.group('mois')):
        mois = month[result.group('mois')]
    else:
        return 0

    timestamp = time.mktime((int(result.group('annee')), mois,
                                int(result.group('jour')), 0, 0, 0, 0, 0, -1))
    return timestamp

def getUpdateDateTimeStr():
    ts = wp10db.getSysValue('updateTimestamp')
    if ts:
        return time.strftime('%d %B %Y à %H:%M '
                                '([[Temps universel coordonné|UTC]])',
                                    time.gmtime(ts)).decode('utf-8')
    else:
        return u''

def levelsList(itype, reverse=False, value='code'):
    assert itype in ('q', 'i', 'a')
    if itype == 'q':
        l = wp10config.levels['quality']
    elif itype == 'i':
        l = wp10config.levels['importance']
    else:
        l = wp10config.levels['importance'] + wp10config.levels['quality']
    if reverse:
        l = reversed(l)
    for level in l:
        yield level[value]

def levelValue(code, value='code'):
    for t in wp10config.levels:
        for level in wp10config.levels[t]:
            if code == level['code']:
                return level[value]
    raise ValueError(u'ERREUR INTERNE: "%s" n\'est pas un code connu !' % code)

def levelCatName(code):
    for t in wp10config.levels:
        for level in wp10config.levels[t]:
            if code == level['code']:
                return level['cat_name']
    raise ValueError(u'ERREUR INTERNE: "%s" n\'est pas un code connu !' % code)

def weightFromCode(code):
    for t in wp10config.levels:
        w = 0
        for level in wp10config.levels[t]:
            if code == level['code']:
                return w
            w += 1
    raise ValueError(u'ERREUR INTERNE: "%s" n\'est pas un code connu !' % code)

def weightFromTemplate(template):
    for t in wp10config.levels:
        w = 0
        for level in wp10config.levels[t]:
            if template == level['template']:
                return w
            w += 1
    raise ValueError(u'ERREUR INTERNE: "%s" n\'est pas un code connu !'
                            % template)


class Evaluation:
    def __init__(self, title, project_name=None, quality=0, importance=0):
        self._title = title
        self._project_name = project_name
        self._quality = quality
        self._importance = importance

    def _transType(self, itype):
        if not itype in wp10config.levels:
            if itype.lower() == 'q':
                return 'quality'
            else:
                return 'importance'
        else:
            return itype

    def _chooseType(self, itype):
        if self._transType(itype) == 'quality':
            return self._quality
        else:
            return self._importance

    def _templateString(self, itype, size=0):
        if size == 0:
            sizestr = 'template'
        else:
            sizestr = 'minitemplate'
        return wp10config.levels[self._transType(itype)][self._chooseType(itype)][sizestr]

    def title(self):
        return self._title

    def projectName(self):
        return self._project_name

    def quality(self):
        return self._quality

    def importance(self):
        return self._importance

    def template(self, itype):
        return self._templateString(itype, 0)

    def miniTemplate(self, itype):
        return self._templateString(itype, 1)


def guessCategoryType(cat_title):
    if u'vancement' in cat_title:
        etype = 'quality'
    elif u'mportance' in cat_title:
        etype = 'importance'
    else:
        return None

    for level in wp10config.levels[etype]:
        match = re.search(ur'(?iLu) %s$' % level['cat_name'], cat_title)
        if match:
            return level['code']
    return None

def wikisenseLink(code):
    catname = levelValue(code, 'root')
    catname = catname.replace(u'Catégorie:', '').encode('utf-8')
    catname = urllib.quote(catname)
    link = u'http://tools.wikimedia.de/~daniel/WikiSense/' \
            u'CategoryIntersect.php?wikilang=fr&wikifam=.wikipedia.org' \
            u'&basecat=%s&basedeep=3&templates=&mode=al&go=Trouver' \
            u'&userlang=fr' % catname
    return link

def bayoIntercatLink(cat1, cat2):
    cat1_encoded = urllib.quote(cat1.replace(u'Catégorie:',
                                                        '').encode('utf-8'))
    cat2_encoded = urllib.quote(cat2.replace(u'Catégorie:',
                                                        '').encode('utf-8'))
    link = u'http://toolserver.org/~bayo/intercat.php?formCat1=%s&formCat2=%s'\
            % (cat1_encoded, cat2_encoded)
    return link
