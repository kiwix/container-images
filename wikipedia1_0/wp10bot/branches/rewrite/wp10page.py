# -*- coding: utf-8  -*-

#
# (C) stanlekub, 2007-2008
#
# Distributed under the terms of the MIT license.
#
# $Id$

import re

import wikipedia
import hal_funcs as hal

import wp10config
import wp10funcs

Rexptitle = re.compile(ur'(@@(?P<id>.+?)@@)')
Rexpcontent = re.compile(ur'(##(?P<id>.+?)##)')

# Valeurs par défaut des différents paramètres disponibles.
pdic = {
    'hasBotSection':    True,
    'pageContent':      u'##content##',
    'botComment':       u'Bot: Mise à jour',
    'botForceSection':  True,
    'botNoNewLine':     False,
    'navTopLink':       u'@@mainPage@@',
    'navPrecLink':      u'',
    'navPrecName':      u'',
    'navNextLink':      u'',
    'navNextName':      u'',
    'navProjectLink':   u'',
    'navEntete':        u'',
    }


class Page(hal.Page):
    def __init__(self, site, pageId, project=None, page_number=0,
                    page_count=0):
        self._pageId = pageId
        self._project = project
        self._page_number = int(page_number)
        self._page_count = int(page_count)
        if self._project:
            if self._pageId == u'evalPage':
                if self._project.isSubProject():
                    self._pageId = 'evalPageSubProject'
                else:
                    self._pageId = 'evalPageMainProject'

        self._content = u''
        self._count = 0
        self._param = {}

        if not wp10config.page_definitions.has_key(self._pageId):
            raise ValueError("BUG: '%s' n'est pas un type de page connu !"
                                % self._pageId)

        ziptitle = wp10config.page_definitions[self._pageId]['title']
        hal.Page.__init__(self, site, self._expandPageTitle(ziptitle))
        self._scanParameters()

    def _expandPageTitle(self, ziptitle):
        match = True
        while match:
            match = Rexptitle.search(ziptitle)
            if match:
                if match.group('id') == u'name':
                    repl = self._project.name()
                elif match.group('id') == u'pageNumber':
                    repl = unicode(self._page_number)
                elif match.group('id') == u'prevPage':
                    repl = unicode(self._previousPageNumber())
                elif match.group('id') == u'nextPage':
                    repl = unicode(self._nextPageNumber())
                elif match.group('id') == u'evalPage':
                    if self._project.isSubProject():
                        repl = wp10config.page_definitions['evalPageSubProject']['title']
                    else:
                        repl = wp10config.page_definitions['evalPageMainProject']['title']
                else:
                    repl = wp10config.page_definitions[match.group('id')]['title']
                ziptitle = ziptitle.replace(match.group(0), repl)
        return ziptitle

    def _scanParameters(self):
        for param in pdic:
            if wp10config.page_definitions[self._pageId].has_key(param):
                self._param[param] = \
                            wp10config.page_definitions[self._pageId][param]
            else:
                self._param[param] = pdic[param]

    def _parameter(self, param):
        return self._param[param]

    def setParameter(self, param, value):
        self._param[param] = value

    def _previousPageNumber(self):
        if self._page_count <= 1:
            return self._page_number
        elif self._page_number == 1:
            return self._page_count
        else:
            return self._page_number - 1

    def _nextPageNumber(self):
        if self._page_count <= 1:
            return self._page_number
        elif self._page_number == self._page_count:
            return 1
        else:
            return self._page_number + 1

    def _expandStringContent(self, stringId):
        result = self._parameter(stringId)
        match = True
        while match:
            match = Rexpcontent.search(result)
            if match:
                if match.group('id') == 'content':
                    repl = self._content
                elif match.group('id') == 'datetimestr':
                    repl = wp10funcs.getUpdateDateTimeStr()
                elif match.group('id') == 'count':
                    repl = unicode(self._count)
                elif match.group('id') == 'navigator':
                    repl = self._genNavigatorText()
                elif match.group('id') == 'project':
                    repl = self._project.pageTitle('link')
                elif match.group('id') == u'prevPage':
                    repl = unicode(self._previousPageNumber())
                elif match.group('id') == u'nextPage':
                    repl = unicode(self._nextPageNumber())
                elif match.group('id') == u'login':
                    repl = u'[[Utilisateur:%s|%s]]' \
                        % (self.site().loggedInAs(), self.site().loggedInAs())
                result = result.replace(match.group(0), repl)
        return result

    def _genNavigatorText(self):
        output = u'{{%s' % wp10config.navigation_template
        if self._project:
            output += u'|lien_projet=%s' % self._project.pageTitle('link')
            output += u'|logo_projet=%s' % self._project.Parameter('wp10Logo')
        prev = self._expandPageTitle(self._parameter('navPrecLink'))
        if prev != self.title():
            output += u'|lien_prev=%s' % prev
            output += u'|nom_prev=%s' % self._parameter('navPrecName')
        else:
            output += u'|lien_prev='
            output += u'|nom_prev='
        output += u'|lien_haut=%s' \
                        % self._expandPageTitle(self._parameter('navTopLink'))
        next = self._expandPageTitle(self._parameter('navNextLink'))
        if next != self.title():
            output += u'|lien_suiv=%s' % next
            output += u'|nom_suiv=%s' % self._parameter('navNextName')
        else:
            output += u'|lien_suiv='
            output += u'|nom_suiv='
        if self._project:
            output += u'|couleur_fond=%s' \
                        % self._project.Parameter('wp10FondCadre')
        output += u'|entete=%s' % self._parameter('navEntete')
        output += u'}}'
        return output

    def setCount(self, count):
        self._count = int(count)

    def setContent(self, content):
        self._content = content

    def save(self, content=None, count=None, ask=True):
        if content:
            self.setContent(content)
        if count:
            self.setCount(count)

        comment = self._expandStringContent('botComment')
        content = self._expandStringContent('pageContent')
        content = self._expandPageTitle(content)

        if self._parameter('hasBotSection'):
            self.askPutBotSection(content, ask, comment=comment,
                        force=self._parameter('botForceSection'),
                        nonewline=self._parameter('botNoNewLine'))
        else:
            self.askPut(content, ask, comment=comment)
