# -*- coding: utf-8  -*-

#
# (C) stanlekub, 2007-2008
#
# Distributed under the terms of the MIT license.
#
# $Id$

import os
import sys
import re
import urllib
import time
import traceback

os.chdir(os.path.dirname(sys.argv[0]))
import wikipedia
import pagegenerators
import hal_funcs as hal
import halcatlib
import natural_sort

import wp10config
import wp10page
import wp10project
import wp10database as wp10db
import wp10funcs

site = wikipedia.getSite()
log = hal.Log(site, wp10page.Page(site, 'botLog').title())
tot = hal.calcTime()

opt = {
    'ask':                  False,
    'update_projects_list': False,
    'update_summary':       False,
    'update_total_eval':    False,
    'update_detail':        False,
    'update_global':        False,
    'sel05':                False,
    'sel05table':           False,
    'update_autonominations_list': False,
    'update_index':         False,
    'update_history':       False,
    'one_by_one':           False,
    'mostwanted':           False,
    'mostwanted2':          False,
    'discordances':         False,
    'log':                  True,
    'update':               True,
    }



###############################################################################
############### Récupération des évaluations depuis le wiki ###################
###############################################################################

def getEvaluations():
    selection = True
    log.setMeterDescription('evalcats', u'Catégories d\'évaluation lues')
    if opt['update_global'] or opt['update_autonominations_list'] or \
                opt['sel05table']:
        selection = False

    wp10db.evaluationsInit()
    db = wp10db.Db()
    for project in projectsList.projectGenerator(only_selected=selection):
        result = {}

        for level_code in wp10funcs.levelsList('a'):
            cat_title = project.Category(level_code)
            if not cat_title:
                continue
            cat = halcatlib.Category(site, cat_title)
            retry = hal.Retry()
            while True:
                try:
                    result[level_code] = list(cat.articles(namespace=[0, 1]))
                except:
                    wikipedia.output(u'\03{lightred}Une erreur s\'est '
                                        u'produite, nouvelle tentative dans '
                                        u'%s...\03{default}'
                                        % retry.delayStr())
                    retry.pause_and_incr()
                    continue
                break
            log.meter('evalcats')

        commit_list = []
        values = {}
        for level_code in result:
            for article in result[level_code]:
                if not article.namespace() == 1:
                    log.add(u'# [[%s]] : article d\'un mauvais espace de nom '
                                u'listé dans les catégories d\'évaluation.'
                                    % article.title(), u'Articles')
                    continue
                titre = article.toggleTalkPage().title()
                if not values.has_key(titre):
                    values[titre] = [0, 0]
                if level_code in wp10funcs.levelsList('q'):
                    values[titre][1] = wp10funcs.weightFromCode(level_code)
                else:
                    values[titre][0] = wp10funcs.weightFromCode(level_code)
        for article in values:
            commit_list.append((article+project.name(), article,
                       project.name(), values[article][0], values[article][1]))

        db.writemany("INSERT INTO evaluations "
                        "(cle, titre, project, importance, quality) "
                        "VALUES (?, ?, ?, ?, ?)",
                        commit_list)
    db.close()
    wp10db.evaluationsFinalize()


def get05Selection():
    db = wp10db.Db()
    values = []
    cat = halcatlib.Category(site, wp10config.selection05category)
    for article in cat.articles():
        if article.namespace() == 1:
            values.append((article.toggleTalkPage().title(), ))
    db.writemany("UPDATE evaluations SET selection05=1 WHERE titre=?", values)
    db.close()


def getOldEvaluations():
    wp10db.oldEvaluationsInit()
    log.setMeterDescription('indexpage', u'Pages d\'index lues')
    for project in projectsList.projectGenerator(only_selected=True):
        db = wp10db.Db()
        indexpage = project.Page('indexTopPage')
        commit_list = []
        try:
            plist = list(indexpage.linkedPages())
            plist.append(wikipedia.Page(site, indexpage.title() + u'/1'))
            plist = set(plist)
            for page in plist:
                if page.title().startswith(indexpage.title()):
                    wikipedia.output(u'WP1: récupération de [[%s]]...'
                                        % page.title())
                    for template in page.templatesWithParams():
                        if hal.upperFirst(template[0]) == \
                                                wp10config.oldeval_template:
                            article = u''
                            diff_str = u''
                            date_str = u''
                            imp = 0
                            qual = 0
                            for param in template[1]:
                                txt = param.strip()
                                if txt.startswith(u'titre='):
                                    article = txt[6:]
                                elif txt.startswith(u'diff='):
                                    diff_str = txt[5:]
                                elif txt.startswith(u'date='):
                                    date_str = txt[5:]
                                elif txt.startswith(u'importance='):
                                    imp = wp10funcs.weightFromTemplate(txt[11:])
                                elif txt.startswith(u'avancement='):
                                    qual = wp10funcs.weightFromTemplate(txt[11:])
                            if article != u'':
                                commit_list.append((u'%s%s' % (article.replace(u'&#61;', u'='), project.name()), \
                                        article.replace(u'&#61;', u'='), project.name(), imp, qual, date_str, diff_str,))
                    log.meter('indexpage')
        except wikipedia.NoPage:
                    continue
        if len(commit_list) > 0:
            db.writemany("INSERT INTO old_evaluations "
                    "(cle, titre, project, importance, quality, date, diff) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?)",
                    commit_list)
        db.close()
    wp10db.oldEvaluationsFinalize()



###############################################################################
################ Mise à jour des statistiques sur le wiki ####################
###############################################################################
def updateStatsGlobal():
    db = wp10db.Db()
    page = wp10page.Page(site, 'globalStats')
    wikipedia.output(u'WP1: Mise à jour du tableau de statistiques globales...')
    output = u'{| class="wikitable" style="text-align: center; ' \
                u'font-size:90%%"\r\n|-\r\n! Tous<br />projets ' \
                u'!! colspan="%s" | Importance\r\n|-\r\n! Avancement !' \
                    % str(len(list(wp10funcs.levelsList('i')))+1)

    for imp in wp10funcs.levelsList('i', reverse=True):
        output += '! %s !' % wp10funcs.levelValue(imp, 'template')

    output += '! \'\'\'Total\'\'\' \r\n|-\r\n'

    for qual in wp10funcs.levelsList('q', reverse=True):
        output += u'! %s\r\n' % wp10funcs.levelValue(qual, 'template')
        for imp in wp10funcs.levelsList('i', reverse=True):
            if wp10funcs.weightFromCode(imp) != 0:
                db.read("SELECT titre, MAX(importance) AS maximp, "
                        "MIN(quality) AS minqual FROM evaluations "
                        "WHERE importance>0 GROUP BY titre "
                        "HAVING (minqual=? and maximp=?)",
                        (wp10funcs.weightFromCode(qual),
                        wp10funcs.weightFromCode(imp),))
            else:
                db.read("SELECT titre, MAX(importance) AS maximp, "
                        "MIN(quality) AS minqual FROM evaluations "
                        "GROUP BY titre HAVING (minqual=? and maximp=?)",
                        (wp10funcs.weightFromCode(qual),
                        wp10funcs.weightFromCode(imp),))
            count = db.rowCountLast()
            if count > 0:
                output += u'| style="background-color:%s" | ' \
                            u'{{formatnum:%i}} |' \
                                % (wp10config.cell_colors[qual][imp], count)
            else:
                output += u'| style="background-color:%s" | |' \
                                % wp10config.cell_colors[qual][imp]

        db.read("SELECT titre, MAX(importance) AS maximp, "
                "MIN(quality) AS minqual FROM evaluations "
                "GROUP BY titre HAVING (minqual=?)",
                    (wp10funcs.weightFromCode(qual),))
        count = db.rowCountLast()
        if count > 0:
            count = str(count)
        else:
            count = u''
        if not wp10funcs.weightFromCode(qual) == 0:
            output += u"| '''[[:%s|{{formatnum:%s}}]]'''" \
                        u"<span class=\"plainlinks\" " \
                        u"style=\"font-weight:bold;font-size:small;\">" \
                        u"[%s {{exp|+}}]</span>\r\n|-\r\n" \
                        % (wp10funcs.levelValue(qual, 'root'), count,
                            wp10funcs.wikisenseLink(qual))
        else:
            output += u'| [[:%s|{{gris|{{formatnum:%s}}}}]]\r\n|-\r\n'  \
                                % (wp10funcs.levelValue(qual, 'root'), count)

    output += u"! '''Total'''\r\n"
    for imp in wp10funcs.levelsList('i', reverse=True):
        db.read("SELECT titre, MAX(importance) AS maximp, "
                "MIN(quality) AS minqual FROM evaluations "
                "GROUP BY titre HAVING (maximp=?)",
                (wp10funcs.weightFromCode(imp),))
        count = db.rowCountLast()
        if count >0 :
            count = str(count)
        else:
            coutn = u''
        if not wp10funcs.weightFromCode(imp) == 0:
            output += u"| '''[[:%s|{{formatnum:%s}}]]'''" \
                        u"<span class=\"plainlinks\" " \
                        u"style=\"font-weight:bold;font-size:small;\">" \
                        u"[%s {{exp|+}}]</span> |" \
                        % (wp10funcs.levelValue(imp, 'root'), count,
                            wp10funcs.wikisenseLink(imp))
        else:
            output += u'| [[:%s|{{gris|{{formatnum:%s}}}}]] |' \
                        % (wp10funcs.levelValue(imp, 'root'), count)

    db.read("SELECT titre, MAX(importance) AS maximp FROM evaluations "
            "GROUP BY titre HAVING (maximp>0)", )
    count = db.rowCountLast()
    output += u"| '''{{formatnum:%i}}'''" \
                u"<span style=\"cursor:help;font-weight:bold;font-size:small;color:grey\" " \
                u"title=\"Ce total n\'inclut pas les articles d\'importance « inconnue ».\">" \
                u"{{exp|(?)}}</span>\r\n|-\r\n" % count

    output += u'| colspan="8" | <small>Dernière mise à jour : %s par ' \
                u'[[Utilisateur:%s|%s]].</small><br />' \
                u'{{Tnavbar|%s|modèle=non}}\r\n|-\r\n' \
                    % (wp10funcs.getUpdateDateTimeStr(), site.loggedInAs(),
                    site.loggedInAs(), page.title())
    output += u'|}'

    page.save(content=output, count=count, ask=opt['ask'])
    db.close()


    # Mise à jour du total d'articles évalués
    page = wp10page.Page(site, 'globalTotal')
    page.save(count=count, ask=opt['ask'])


def updateNpovStatus():
    # Récupère la liste des articles comportant un bandeau de
    # désaccord de neutralité.
    db = wp10db.Db()
    liste = []
    db.write("UPDATE evaluations SET npov=0 WHERE npov=1")
    for template in wp10config.npov_templates:
        page = wikipedia.Page(site, template)
        for article in page.getReferences(onlyTemplateInclusion=True):
            if (article.namespace() == 0):
                liste.append((article.title(), ))
    db.writemany("UPDATE evaluations SET npov=1 WHERE titre=?", liste)
    db.close()


def articleProjectsList(title, exclude=[]):
    db = wp10db.Db()
    output = u'\r\n'
    db.read("SELECT project, importance, quality FROM evaluations "
            "WHERE titre=? ORDER BY project", (title,))
    for row in db.fetchall():
        if row['project'] not in exclude:
            e = wp10funcs.Evaluation(title, project_name=row['project'],
                            importance=row['importance'],
                            quality=row['quality'])
            try:
                p = projectsList.projectFromName(e.projectName())
                link = p.pageTitle('evalPage')
            except ValueError:
                link = e.projectName()
            output += u'* [[%s|%s]]&nbsp;%s%s\r\n' \
                        % (link, e.projectName(), e.miniTemplate('i'),
                                e.miniTemplate('q'))
    db.close()
    return output


def updateAutoNominationsList():
    db = wp10db.Db()
    old_list = []     # Ancienne liste des articles nominés (liste de titres)
    subpages_list = [] # Liste des sous-pages de nominations automatiques

    page = wp10page.Page(site, 'autoNominations')

    # Récupère l'ancienne liste d'articles nominés
    prefix = page.titleWithoutNamespace()
    ns = page.namespace()
    for item in pagegenerators.PrefixingPageGenerator(prefix, ns):
        if item.title()[-1].isdigit():
            wikipedia.output(u'WP1: récupération de [[%s]]...' % item.title())
            subpages_list.append(item.title())
            gen = pagegenerators.LinkedPageGenerator(item)
            gen = pagegenerators.NamespaceFilterPageGenerator(gen, [0,])
            for article in gen:
                old_list.append(article.title())

    # Mise à jour de la liste des articles nominés automatiquement
    # (sous-pages + page principale)
    #-------------------------------------------------------------------------
    nom_list = []
    offset = 0
    page_number = 1
    db.read("SELECT titre, MAX(importance) AS maximp, "
            "MIN(quality) AS minqual, selection05 FROM evaluations "
            "WHERE importance>0 and npov<>1 GROUP BY titre "
            "HAVING (maximp>=? AND minqual>=?) ORDER BY titre collate natsort",
            (wp10config.auto_nom_importance, wp10config.auto_nom_quality))
    count = db.rowCountLast()
    nb_pages, r = divmod(count, wp10config.auto_nom_index_articles)
    if r > 0:
        nb_pages += 1

    toppage_content = u''
    i = 0
    for page_number in range(1, nb_pages+1):
        nb = 0
        first = u''
        last = u''
        subpage = wp10page.Page(site, 'autoNominationsSubPage',
                            page_number=page_number, page_count=nb_pages)
        if subpage.title() in subpages_list:
            subpages_list.remove(subpage.title())
        content = u''
        content += u'{| class="wikitable"\r\n'
        content += u'! Article !! Importance !! Avancement !! Projets évaluateurs\r\n|-\r\n'
        for row in db.fetchsome(i, i+wp10config.auto_nom_index_articles):
            i += 1
            nb += 1
            if nb == 1:
                first = row['titre']
            last = row['titre']
            projectslist = articleProjectsList(row['titre'])
            e = wp10funcs.Evaluation(row['titre'], quality=row['minqual'],
                                importance=row['maximp'])
            if row['selection05'] == 1:
                # Si l'article est présent dans la sélection 0.5,
                # affichage de la cellule sur fond vert.
                content += u'| style="background:lightgreen;" | [[%s]] || %s || %s || %s|-\r\n' \
                                % (e.title(), e.template('i'),
                                    e.template('q'), projectslist)
            else:
                content += u'| [[%s]] || %s || %s || %s|-\r\n' \
                            % (e.title(), e.template('i'), e.template('q'), \
                                projectslist)
        content += u'|}'
        toppage_content += u"# [[%s|%s &mdash; %s]] <small>''(%s articles)''</small>\r\n" \
                                % (subpage.title(), first, last, nb)

        subpage.save(content=content, ask=opt['ask'])
    if len(subpages_list) > 0:
        for title in subpages_list:
            log.add(u"# [[%s]] : page devenu inutile..." \
                        % title, u"Nettoyage")
    page.save(content=toppage_content, count=count, ask=opt['ask'])


def updateTotalEvaluatedProject(project):
    page = project.Page('totalEvaluatedPage')
    count = project.crossCatTotal()
    page.save(count=count, ask=opt['ask'])


def updateDetailedStatsProject(project):
    page = project.Page('statsDetailPage')
    back_color = project.Parameter('wp10FondEntete')
    font_color = project.Parameter('wp10PoliceEntete')
    i = 1

    output = u'{{%s\r\n' % wp10config.detailstats_template
    output += u'| projet = %s\r\n' % project.name()
    for qual in wp10funcs.levelsList('q', reverse=True):
        for imp in wp10funcs.levelsList('i', reverse=True):
            r = project.crossCatTotal(imp, qual)
            if r > 0:
                output += u'| %i = <span class="plainlinks">[%s ' \
                            u'{{formatnum:%i}}]</span>\r\n' \
                            % (i,
                            wp10funcs.bayoIntercatLink(project.Category(qual),
                            project.Category(imp)), r)
            else:
                output += u'| %i = \r\n' % i
            i += 1
        r = project.crossCatTotal(None, qual)
        output += u'| %i = [[:%s|{{formatnum:%i}}]]\r\n' \
                    % (i, project.Category(qual), r)
        i += 1
    for imp in wp10funcs.levelsList('i', reverse=True):
        r = project.crossCatTotal(imp, None)
        output += u'| %i = [[:%s|{{formatnum:%i}}]]\r\n' \
                    % (i, project.Category(imp), r)
        i += 1
    r = project.crossCatTotal()
    output += u'| %i = {{formatnum:%i}}\r\n' % (i, r)
    output += u'}}'
    page.save(content=output, count=r, ask=opt['ask'])


def updateProjects():
    for project in projectsList.projectGenerator(only_selected=False):
        if opt['update_detail']:
            updateDetailedStatsProject(project=project)
        if opt['update_total_eval']:
            updateTotalEvaluatedProject(project=project)



###############################################################################
############################## Initialisation #################################
###############################################################################
class participatingProjects:
    def __init__(self):
        self._cmdline_projects = []
        self._projects_list = []
        self._old_projects_list = []
        self._updated = False

    def update(self, cmdline_projects):
        self._cmdline_projects = cmdline_projects
        t = hal.calcTime()
        self._retrieve()
        self._oldListUpdate()
        if len(self._projects_list) == 0:
            wikipedia.output(u'\03{lightred}Aucun projet trouvé !!! Il doit '
                                u'y avoir un problème quelque part...'
                                u'\03{default}')
            sys.exit()
        self._detectNewProjects()
        self._checkIntegrity()
        log.add(u"* ''Liste des projets'' : %s" % t.result(), u'Timers')

    def _retrieve(self):
        """ Récupère la liste des projets évaluateurs depuis le wiki
        """
        log.setMeterDescription('projectcats', u'Catégories de projets lues')
        wikipedia.output(u'WP1: récupération de la liste des projets évaluateurs')
        cat = halcatlib.Category(site, wp10config.supercat)
        for category in cat.subcategoriesTitles():
            log.meter('projectcats')
            try:
                p = wp10project.Project(category, self._cmdline_projects, log)
                if p.name():
                    self.add(p)
            except:
                # Fixme : faudrait faire quelque chose d'utile ici :)
                traceback.print_tb(sys.exc_info()[2], file=sys.stdout)
                wikipedia.output(u'%s : %s' % (sys.exc_info()[0],
                                    sys.exc_info()[1]))
            if len(self._cmdline_projects) > 0:
                if len(self._cmdline_projects) == len(self._projects_list):
                    break
        self._updated = True

    def _oldListUpdate(self):
        """ Récupère la liste des projets participants à WP1.0 avant la
            mise à jour en cours
        """
        R = re.compile(wp10config.oldprojects_regex)
        page = wp10page.Page(site, 'projectsList')
        content = page.safeGet()
        for match in R.finditer(content):
            self._old_projects_list.append(match.group('projectname'))
        if len(self._old_projects_list) > 0:
            self._old_projects_list = \
                                natural_sort.natsort(self._old_projects_list)

    def _checkIntegrity(self):
        nb = 0
        nb_sub = 0
        root_cats = {}
        for level in wp10funcs.levelsList('a'):
            cat = halcatlib.Category(site, wp10funcs.levelValue(level, 'root'))
            root_cats[level] = []
            r = hal.Retry()
            while True:
                try:
                    for subcat in cat.subcategoriesTitles():
                        root_cats[level].append(subcat)
                except:
                    if r.retries() == 9:
                        wikipedia.output(u'WP1: Maximum de 10 tentatives '
                                            u'atteint, abandon...')
                        sys.exit()
                    wikipedia.output(u'\03{lightred}Une erreur s\'est '
                                        u'produite, nouvelle tentative dans'
                                        u'%s...\03{default}' % r.delayStr())
                    r.pause_and_incr()
                    continue
                break

        for project in self.projectGenerator(only_selected=False):
            if not project.isSubProject():
                nb += 1
                if not project.name()==u'Wikipédia Junior':    # Fixme
                    for imp in wp10funcs.levelsList('i'):
                        if not project.Category(imp):
                            log.add(u"# %s : Catégorie d'importance ''%s'' "
                                        u"manquante."
                                            % (project.pageTitle('link'),
                                            wp10funcs.levelCatName(imp)),
                                            u'Projets')
                    for qual in wp10funcs.levelsList('q'):
                        if not project.Category(qual):
                            log.add(u"# %s : Catégorie d'avancement ''%s'' "
                                        u"manquante."
                                        % (project.pageTitle('link'),
                                        wp10funcs.levelCatName(qual)),
                                        u'Projets')
            else:
                nb_sub += 1

            for level in root_cats:
                if project.Category(level):
                    if not project.Category(level) in root_cats[level]:
                        log.add(u'# [[:%s]] n\'est pas listée dans [[:%s]].'
                                    % (project.Category(level),
                                        wp10funcs.levelValue(level, 'root'),
                                        u'Arborescence générale'))

        if self._cmdline_projects == []:
            wikipedia.output(u'+++ %s projets trouvés +++' % nb)
            wikipedia.output(u'+++ %s sous-projets trouvés +++' % nb_sub)

    def _detectNewProjects(self):
        diff = set(self._projectsNameList()) - set(self._old_projects_list)
        if len(diff) > 0:
            wikipedia.output(u'\03{lightgreen}%s\03{default} nouveau(x) '
                                u'projet(s) trouvé(s) !' \
                                % len(diff))
            log.add(u'# %s nouveau%s projet%s trouvé%s :'
                        % (len(diff), len(diff) != 1 and "x" or "",
                            len(diff) != 1 and "s" or "",
                            len(diff) != 1 and "s" or ""))
            for project in diff:
                wikipedia.output(u'\t+++ \03{lightaqua}%s\03{default} +++'
                                    % project)
                log.add(u'#* %s'
                        % (self.projectFromName(project).pageTitle('link')))

    def projectFromName(self, name):
        for project in self._projects_list:
            if project.name() == name:
                return project
        raise ValueError, \
                'BUG: "%s" n\'est pas un nom de projet connu !' % name

    def _projectsNameList(self):
        l = []
        for project in self._projects_list:
            l.append(project.name())
        return l

    def cmdlineProjects(self):
        for projectname in self._cmdline_projects:
            yield projectname

    def projectGenerator(self, sort=True, only_selected=True):
        liste = []
        project_names_list = self._projectsNameList()

        if sort:
            liste = natural_sort.natsort(project_names_list)

        if len(self._cmdline_projects) > 0:
            if only_selected:
                comp_list = self._cmdline_projects
            else:
                comp_list = project_names_list
        else:
            comp_list = project_names_list

        if not liste:
            return

        for project in liste:
            if project in comp_list:
                yield self.projectFromName(project)

    def add(self, project):
        self._projects_list.append(project)

    def putList(self):
        count = 0
        output = u'{| class="sortable" style="border:0; background-color:transparent;"\r\n|-\r\n'
        output += u'! Projet !! Évalués !! Total !! Avancement\r\n|-\r\n'
        output_sub = u''
        for project in self.projectGenerator(sort=True, only_selected=False):
            if not project.isSubProject():
                total_page_title = project.pageTitle('totalPage')
                total_eval_page_title = project.pageTitle('totalEvaluatedPage')
                output += u'| {{1.0|%s}} || {{#ifexist:%s|{{formatnum:{{%s}}}}|---}} || {{#ifexist:%s|{{formatnum:{{%s}}}}|---}} || {{Avancement|{{#expr:{{%s}}/{{%s}}*100 round 0}}}}\r\n|-\r\n' \
                    % (project.name(), total_eval_page_title, total_eval_page_title, total_page_title, total_page_title, total_eval_page_title, total_page_title)
                count += 1
            else:
                output_sub += u'* \'\'{{Sous-projet 1.0|%s}}\'\'\r\n' \
                                    % project.name()
        output += u'|}\r\n----\r\n' + output_sub

        page = wp10page.Page(site, 'projectsList')
        page.save(content=output, count=count, ask=opt['ask'])


projectsList = participatingProjects()

class wp10Bot:
    def __init__(self):
        self._users = None

    def _getUsersList(self):
        self._users = []
        wikipedia.output(u'WP1: récupération de la liste des '
                            u'participants à WP:1.0')
        cat = halcatlib.Category(site, wp10config.wp10userscat)
        for user in cat.articlesTitles(namespace=[2, ]):
            self._users.append(user)
        self._users = natural_sort.natsort(self._users)

    def users(self):
        if not self._users:
            self._getUsersList()
        for user in self._users:
            yield user

    def run(self, plist):
        projectsList.update(plist)

        if (opt['update_global'] or opt['update_autonominations_list'] or \
                    opt['update_total_eval'] or opt['update_summary'] or \
                    opt['update_detail'] or opt['update_index'] or \
                    opt['update_history'] or opt['mostwanted'] or \
                    opt['mostwanted2'] or opt['sel05'] or \
                    opt['sel05table'] or opt['discordances']) and \
                    opt['update']:
            t = hal.calcTime()
            getEvaluations()
            wp10db.updateSysValue('updateTimestamp', time.time())
            log.add(u"* ''Évaluations'' : %s" % t.result(), u'Timers')

        if (opt['update_index'] or opt['update_history'] or \
                    opt['update_autonominations_list']) and opt['update']:
            t.reset()
            getOldEvaluations()
            log.add(u"* ''Anciennes évaluations'' : %s"
                        % t.result(), u'Timers')

        if (opt['sel05'] or opt['sel05table'] or \
                    opt['update_autonominations_list']) and opt['update']:
            t.reset()
            get05Selection()
            log.add(u"* ''Sélection 0.5'' : %s" % t.result(), u'Timers')

        if opt['update_global']:
            updateStatsGlobal()

        #if opt['sel05table']:
            #update05SelectionTable()

        if opt['update_autonominations_list']:
            updateNpovStatus()
            updateAutoNominationsList()

        #if opt['mostwanted']:
            #updateMostWantedLists()

        #if opt['mostwanted2']:
            #updateMostWantedLists2()

        #if opt['discordances']:
            #eval_discordantes()

        if opt['update_summary'] or opt['update_detail'] or \
                    opt['update_index'] or opt['update_total_eval'] or \
                    opt['update_history'] or opt['sel05']:
            updateProjects()

        if opt['update_projects_list']:
            projectsList.putList()
        return

mbot = wp10Bot()


def main():
    global opt
    cmd_line_projects = []

    for arg in wikipedia.handleArgs():
        if arg == '-ask':
            opt['ask'] = True
        elif arg == '-list':
            opt['update_projects_list'] = True
        elif arg == '-global':
            opt['update_global'] = True
        elif arg == '-auto':
            opt['update_autonominations_list'] = True
        elif arg == '-summary':
            opt['update_summary'] = True
        elif arg == '-totaleval':
            opt['update_total_eval'] = True
        elif arg == '-detail':
            opt['update_detail'] = True
        elif arg == '-index':
            opt['update_index'] = True
        elif arg == '-hist':
            opt['update_history'] = True
        elif arg == '-sel05':
            opt['sel05'] = True
        elif arg == '-sel05table':
            opt['sel05table'] = True
        elif arg == '-one':
            opt['one_by_one'] = True
        elif arg == '-mostwanted':
            opt['mostwanted'] = True
        elif arg == '-mostwanted2':
            opt['mostwanted2'] = True
        elif arg == '-discordances':
            opt['discordances'] = True
        elif arg == '-paslog':
            opt['log'] = False
        elif arg == '-noupdate':
            opt['update'] = False
        elif arg == '-project':
            #opt['update_summary'] = True
            opt['update_total_eval'] = True
            opt['update_detail'] = True
            opt['update_index'] = True
            opt['update_history'] = True
            opt['sel05'] = True
        elif arg == '-all':
            opt['update_projects_list'] = True
            opt['update_global'] = True
            opt['update_autonominations_list'] = True
            #opt['update_summary'] = True
            opt['update_total_eval'] = True
            opt['update_detail'] = True
            opt['update_index'] = True
            opt['update_history'] = True
            opt['sel05'] = True
            opt['sel05table'] = True
            #opt['mostwanted'] = True
            opt['mostwanted2'] = True
        elif arg.startswith('-'):
            wikipedia.output(u'Argument de ligne de commande inconnu : "%s".'
                                    % arg)
            while True:
                rep = wikipedia.input(u'Continuer quand même ? (O/N)')
                if rep in ['O', 'o']:
                    break
                elif rep in ['N', 'n']:
                    sys.exit()
        else:
            cmd_line_projects.append(arg)

    mbot.run(cmd_line_projects)

if __name__ == "__main__":
    try:
        main()
    finally:
        if opt['log']:
            log.add(u"* ''Temps total'' : %s" % tot.result(), u'Timers')
            log.put()
        wikipedia.stopme()
