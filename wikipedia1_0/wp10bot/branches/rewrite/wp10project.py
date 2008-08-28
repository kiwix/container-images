# -*- coding: utf-8  -*-

#
# (C) stanlekub, 2007-2008
#
# Distributed under the terms of the MIT license.
#
# $Id$

import re
import traceback
import sys

import wikipedia
import hal_funcs as hal
import halcatlib
import natural_sort

import wp10page
import wp10config
import wp10database as wp10db

site = wikipedia.getSite()
Rcolor = re.compile(ur'(?iLmsu)^#[\dabcdef]{6}$')

class ProjectParameter:
    def __init__ (self, name):
        self._name = name
        self._value = None

    def name(self):
        return self._name

    def _ptype(self):
        return wp10config.parameters_list[self._name]['type']

    def _mini(self):
        return wp10config.parameters_list[self._name]['mini']

    def _maxi(self):
        return wp10config.parameters_list[self._name]['maxi']

    def default(self):
        return wp10config.parameters_list[self._name]['default']

    def value(self):
        return self._value

    def validate(self, value):
        value = value.strip()
        if self._ptype() == 'integer':
            if value.isdigit() and int(value) >= self._mini() and \
                        int(value) <= self._maxi():
                self._value = int(value)
        elif self._ptype() == 'boolean':
            if value.lower() == 'oui':
                self._value = True
            elif value.lower() == 'non':
                self._value = False
        elif self._ptype() == 'color':
            match = Rcolor.search(value.lower())
            if match:
                self._value = value
        elif self._ptype() == 'image':
            self._value = value
        elif self._ptype() == 'list':
            self._value = value

    def isValid(self):
        return self._value != None


class Project:
    def __init__(self, top_category_title, cmdline_projects, logger):
        self._name = None
        self._log = logger
        self._is_subproject = False
        self._categories = {}
        self._parameters = None
        self._users = None
        self._eval_total_old = False
        self._cross_cat_totals = {}

        try:
            self._top_category = halcatlib.Category(site, top_category_title)
            evalpagename = None

            for template in self._top_category.templatesWithParams():
                if template[0] == wp10config.evalpage_tmpl:
                    evalpagename = template[1][0].strip()

            if evalpagename:
                match = re.search(wp10config.evalpage_regex, evalpagename)
                if match:
                    self._name = hal.upperFirst(match.group('project_name'))
                    if self._name == wp10config.subproject_tag:
                        self._name = \
                                hal.upperFirst(match.group('eval_page_title'))
                        self._is_subproject = True

                    # Inutile d'aller plus loin si seuls quelques projets
                    # doivent être mis à jour et que celui-ci n'y figure pas.
                    if len(cmdline_projects) > 0 and \
                                self._name not in cmdline_projects:
                        self._name = None
                        return

                    # Si la page d'évaluation (Projet:xxx/Évaluation) n'existe
                    # pas, on considère que le projet d'éval n'est pas valide
                    # => abandon.
                    evalpage = wp10page.Page(site, 'evalPage', self)
                    if not evalpage.exists():
                        self._log.add(u'# [[%s]] : {{Rouge|page inexistante}}.'
                                        % evalpage.title(), u'Projets')
                        self._name = None
                        return

                    # Récupération de la liste des catégories
                    # d'évaluation pour ce projet
                    for subcat in self._top_category.subcategoriesTitles():
                        result = eva.guessCategoryType(subcat)
                        if result:
                            self._categories[result] = subcat
                        else:
                            self._log.add(u"# [[:%s]] : Échec de l\'analyse "
                                            u"du titre de ''[[:%s|]]''."
                                            % (self._top_category.title(),
                                                subcat), u'Projets')

                    wikipedia.output(u'Analyse du projet « %s » '
                                        u'\03{lightgreen}OK\03{default}.'
                                        % self._name)
                else:
                    self._log.add(u'# [[:%s]] : {{Rouge|Impossible de trouver '
                                    u'la page d\'évaluation correspondant à '
                                    u'cette catégorie}}.'
                                    % self._top_category.title(), u'Projets')
            else:
                self._log.add(u'# [[:%s]] : {{Rouge|Impossible de trouver '
                                u'la page d\'évaluation correspondant à '
                                u'cette catégorie}}.'
                                % self._top_category.title(), u'Projets')
        except:
            # Fixme : Y'a probablement mieux à faire !
            self._log.add(u'# {{Rouge|Exception rencontrée lors de '
                            u'l\'initialisation du projet « %s ».}}'
                                % self._name, u'Debug')
            wikipedia.output(u'*** EXCEPTION ! ***')
            wikipedia.output(u'*** Initialisation du projet %s ***'
                                % self._name)
            traceback.print_tb(sys.exc_info()[2], file=sys.stdout)
            wikipedia.output(u'%s : %s' % (sys.exc_info()[0],
                                sys.exc_info()[1]))
            wikipedia.output(u'************\r\n')
            self._name = None

    def name(self):
        return self._name

    def isSubProject(self):
        return self._is_subproject

    def pageTitle(self, pageId):
        return wp10page.Page(site, pageId, project=self).title()

    def Page(self, pageId):
        return wp10page.Page(site, pageId, project=self)

    def Category(self, level_name):
        if self._categories.has_key(level_name):
            return self._categories[level_name]
        else:
            return None

    def Parameter(self, pcode):
        if not self._parameters:
            self._scanParameters()
        assert self._parameters.has_key(pcode), \
            'ERREUR INTERNE: "%s" n\'est pas un parametre reconnu !' % pcode
        return self._parameters[pcode]

    def users(self):
        if not self._users:
            self._scanUsersList()
        return self._users

    def crossCatTotal(self, importance=None, quality=None):
        s = u'%s-%s' % (importance or "all", quality or "all")
        if not self._cross_cat_totals.has_key(s):
            db = wp10db.Db()
            if importance and quality:
                db.read("SELECT titre, importance, quality FROM evaluations "
                        "WHERE (project=? and importance=? and quality=?)",
                            (self.name(), eva.weightFromCode(importance),
                                eva.weightFromCode(quality),))
                self._cross_cat_totals[s] = db.rowCountLast()
            elif importance and not quality:
                db.read("SELECT titre, importance FROM evaluations "
                        "WHERE (project=? and importance=?)",
                            (self.name(), eva.weightFromCode(importance),))
                self._cross_cat_totals[s] = db.rowCountLast()
            elif not importance and quality:
                db.read("SELECT titre, quality FROM evaluations "
                        "WHERE (project=? and quality=?)",
                            (self.name(), eva.weightFromCode(quality),))
                self._cross_cat_totals[s] = db.rowCountLast()
            else:
                db.read("SELECT titre, importance FROM evaluations "
                        "WHERE (project=? AND importance>0)",
                            (self.name(),))
                self._cross_cat_totals[s] = db.rowCountLast()
        return self._cross_cat_totals[s]

    def _scanUsersList(self):
        """ Tente de récupérer la liste des participants au projet
        """
        self._users = []
        users_page = None
        for title in wp10config.users_lists:
            page = hal.Page(site, self.pageTitle('projectPage') + title)
            if page.exists():
                users_page = page
                break

        if users_page:
            try:
                for user in users_page.linkedPages():
                    if user.namespace() == 2:
                        self._users.append(user.title())
            except:
                self._log.add(u'# Erreur lors de l\'analyse de [[%s]].'
                                % users_page.title(), u'Debug')

            if len(self._users) > 0:
                self._users = natural_sort.natsort(self._users)
            else:
                self._log.add(u'# {{Rouge|[[%s]] : page des participants '
                                u'trouvée mais la liste renvoyée est vide !}}'
                                % users_page.title(), u'Debug')
        else:
            self._log.add(u'# %s : Impossible de trouver la liste des '
                            u'participants au projet.'
                            % self.pageTitle('link'), u'Debug')


    def _scanParameters(self):
        """ Récupère les paramètres personnalisés sur le wiki
            si ils existent, sinon, renvoie les valeurs par défauts.
        """
        wikipedia.output(u'Récupération des paramètres personnalisés '
                          u'du projet « %s »...'
                            % self._name)
        self._parameters = {}
        page = self.Page('parametersPage')
        content = page.safeGet()
        for param_name in wp10config.parameters_list:
            param = ProjectParameter(param_name)
            pmatch = re.search(ur'^\s*?%s\s*?=\s*?(?P<value>.*?)\s*?$'
                                % param.name(), content, re.MULTILINE)
            if pmatch:
                param.validate(pmatch.group('value'))
                if param.isValid():
                    self._parameters[param.name()] = param.value()
                    self._log.add(u'* [[%s|%s]] : \'\'%s\'\' == %s'
                                % (page.title(), self.name(), param.name(),
                                param.value()), u'Paramétrages')
                else:
                    self._parameters[param.name()] = param.default()
                    self._log.add(u'* %s : Erreur lors de l\'analyse du '
                                    u'paramètre « %s » sur la page [[%s]].'
                                    % (self.pageTitle('link'), pmatch.group(0),
                                    page.title()), u'Paramétrages')
            else:
                self._parameters[param.name()] = param.default()

    def evalTotalOld(self):
        if not self._eval_total_old:
            page = self.Page('totalEvaluatedPage')
            if page.exists():
                content = page.safeGet()
                if content.isdigit():
                    self._eval_total_old = int(content)
                else:
                    match = re.search(ur'>(\d+?)<', content)
                    if match:
                        self._eval_total_old = int(match.group(1))
                    else:
                        self._log.add(u'# Erreur lors de l\'analyse du '
                                        u'contenu de la page [[%s]].'
                                        % page.title(), u'Debug')
                        self._eval_total_old = 0
            else:
                self._eval_total_old = 0
        return self._eval_total_old

