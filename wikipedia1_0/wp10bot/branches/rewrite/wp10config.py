# -*- coding: utf-8  -*-

#
# (C) stanlekub, 2007-2008
#
# Distributed under the terms of the MIT license.
#
# $Id$

# Catégorie mère de l'ensemble des catégories d'évaluation par projet
supercat = u'Catégorie:Évaluation d\'article par projet'

# Nom du modèle utilisé pour indiquer le titre de
# la page d'évaluation de chaque projet.
# Ne doit pas inclure l'espace de nom (e.g. 'Modèle:').
evalpage_tmpl = u'Article principal'

# Regex permettant d'extraire des paramètres passés au modèle
# précédant le titre de la page d'évaluation et le nom du projet.
# Doit impérativement contenir les groupes <project_name> et
# <eval_page_title>.
evalpage_regex = ur'(?P<namespace>(P|p)(ortail|rojet)):(?P<project_name>.+?)/(?P<eval_page_title>(Évaluation|Les plus consultés|Sélection méta))$'

# Chaîne utilisée pour déterminer si le projet identifié par la
# regex précédente est en fait un sous-projet de WP:1.0
# (e.g. "Les plus concultés").
# Si <project_name> est égal à 'subproject_tag', c'est
# <eval_page_title> qui sera utilisé comme nom de projet et le
# sous-projet sera flaggué en tant que tel.
subproject_tag = u'Wikipédia 1.0'

# Catégorie contenant la liste des utilisateurs inscrits au
# projet WP:1.0
wp10userscat = u'Catégorie:Utilisateur Wikipédia 1.0'

# Liste de sous-pages susceptibles de contenir la liste des participants
# de chacun des wikiprojets.
users_lists = (
    u'/Participants',
    u'/Contributeurs',
    u'/Ressources humaines',
    u'/Participant',
    u'/Participants actuels'
    )

# Regex permettant d'analyser l'index des projets participants
# présent sur le wiki.
# Doit contenir le groupe <projectname> qui donne le nom du projet.
oldprojects_regex = ur'\{\{([Ss]ous-projet )?1[.]0\|(?P<projectname>.*?)\}\}'

# Catégorie contenant la liste des articles sélectionnés
# pour la version 0.5
selection05category = u'Catégorie:Wikipédia 0.5'

oldeval_template = u'Évaluation'

# Emplacement sur le wiki du modèle pour la bandeau de navigation
# qui sera placé en tête de chaque page.
navigation_template = u'Projet:Wikipédia 1.0/Bot/Bandeau navigation'

# Niveau d'importance et d'avancement mini pour que l'article
# soit inclus dans les nominations automatiques.
auto_nom_importance = 3
auto_nom_quality = 3

# Nombre maximum d'articles à afficher dans chaque sous-page
# de l'index des nominations automatiques.
auto_nom_index_articles = 200

# Modèle utilisé pour l'affichage du tableau de statistiques
# détaillées de chaque projet
detailstats_template = u'Utilisateur:NicDumZ/Eval Detail'

# Dictionnaire des niveaux d'évaluations ; chacun de ces niveaux peut
# être soit de type avancement (quality) soit de type importance.
# Pour chaque niveau, on définit :
#   'code', un identifiant qui doit être unique
#   'cat_name', chaîne permettant d'identifier à quel niveau une
#               catégorie d'évaluation donnée devra être rattachée
#   'root', nom de la catégorie 'mère' de ce niveau d'évaluation
#   'template', titre du modèle utilisé pour l'affichage
#   'minitemplate', idem, mais en plus compact.
#
# Pour les deux types disponibles (quality et importance), les niveaux
# sont classés par ordre de poids croissant ; le premier niveau
# listé (poids=0) correspond à « évaluation inconnu ».
levels = {
    'quality': (
    {   'code':         'Unassessed',
        'cat_name':     u'inconnu',
        'root':         u'Catégorie:Article d\'avancement inconnu',
        'template':     u'{{Avancement inconnu}}',
        'minitemplate': u'{{Avancement inconnu mini}}',
    },
    {   'code':         'Stub',
        'cat_name':     u'ébauche',
        'root':         u'Catégorie:Article d\'avancement ébauche',
        'template':     u'{{Avancement ébauche}}',
        'minitemplate': u'{{Avancement Ébauche mini}}',
    },
    {   'code':         'Start',
        'cat_name':     u'BD',
        'root':         u'Catégorie:Article d\'avancement BD',
        'template':     u'{{Avancement BD}}',
        'minitemplate': u'{{Avancement BD mini}}',
    },
    {   'code':         'B',
        'cat_name':     u'B',
        'root':         u'Catégorie:Article d\'avancement B',
        'template':     u'{{Avancement B}}',
        'minitemplate': u'{{Avancement B mini}}',
    },
    {   'code':         'GA',
        'cat_name':     u'BA',
        'root':         u'Catégorie:Article d\'avancement BA',
        'template':     u'{{Avancement BA}}',
        'minitemplate': u'{{Avancement BA mini}}',
    },
    {   'code':         'A',
        'cat_name':     u'A',
        'root':         u'Catégorie:Article d\'avancement A',
        'template':     u'{{Avancement A}}',
        'minitemplate': u'{{Avancement A mini}}',
    },
    {   'code':         'FA',
        'cat_name':     u'AdQ',
        'root':         u'Catégorie:Article d\'avancement AdQ',
        'template':     u'{{Avancement AdQ}}',
        'minitemplate': u'{{Avancement AdQ mini}}',
    },
    ),
    'importance': (
    {   'code':         'No',
        'cat_name':     u'inconnue',
        'root':         u'Catégorie:Article d\'importance inconnue',
        'template':     u'{{Importance inconnue}}',
        'minitemplate': u'{{Importance inconnue mini}}',
    },
    {   'code':         'Low',
        'cat_name':     u'faible',
        'root':         u'Catégorie:Article d\'importance faible',
        'template':     u'{{Importance faible}}',
        'minitemplate': u'{{Importance faible mini}}',
    },
    {   'code':         'Mid',
        'cat_name':     u'moyenne',
        'root':         u'Catégorie:Article d\'importance moyenne',
        'template':     u'{{Importance moyenne}}',
        'minitemplate': u'{{Importance moyenne mini}}',
    },
    {   'code':         'High',
        'cat_name':     u'élevée',
        'root':         u'Catégorie:Article d\'importance élevée',
        'template':     u'{{Importance élevée}}',
        'minitemplate': u'{{Importance élevée mini}}',
    },
    {   'code':         'Top',
        'cat_name':     u'maximum',
        'root':         u'Catégorie:Article d\'importance maximum',
        'template':     u'{{Importance maximum}}',
        'minitemplate': u'{{Importance maximum mini}}',
    },
    ),
}


# Dictionnaire des paramètres pouvant être personnalisés par chaque projet
# L'identifiant doit être unique
#   'type':     peut être 'integer', 'boolean', 'color', 'image' ou 'list'
#               pour les trois premiers types, un contrôle sera effectué
#               par le bot pour vérifier la validité de la valeur saisie.
#   'default':  valeur par défaut.
#   'mini':     valeur minimum autorisée (incluse)
#   'maxi':     valeur maximum autorisée (incluse) !
#   'req':      paramètre requis (True/False) : envoie un message d'erreur
#               si 'req' vaut 'True' et que le paramètre n'est pas définit.
parameters_list = {
    # Nom, type, défaut, minimum, maximum
    u'wp10FondCadre': {
        'type':         'color',
        'default':      '#DFD',
        'mini':         '',
        'maxi':         '',
        'req':          False,
        },
    u'wp10FondEntete': {
        'type':         'color',
        'default':      'transparent',
        'mini':         '',
        'maxi':         '',
        'req':          False,
        },
    u'wp10PoliceEntete':    {
        'type':         'color',
        'default':      '#000000',
        'mini':         '',
        'maxi':         '',
        'req':          False,
        },
    u'wp10Logo': {
        'type':         'image',
        'default':      '',
        'mini':         '',
        'maxi':         '',
        'req':          False,
        },
    u'wp10NbArtIndex': {
        'type':         'integer',
        'default':      200,
        'mini':         100,
        'maxi':         300,
        'req':          False,
        },
    u'wp10NbJoursHist': {
        'type':         'integer',
        'default':      15,
        'mini':         10,
        'maxi':         30,
        'req':          False,
        },
    u'wp10AutresProjets': {
        'type':         'boolean',
        'default':      True,
        'mini':         '',
        'maxi':         '',
        'req':          False,
        },
    u'wp10AdQAutres': {
        'type':         'boolean',
        'default':      False,
        'mini':         '',
        'maxi':         '',
        'req':          False,
    },
    u'wp10ModèleEval': {
        'type':         'list',
        'default':      '',
        'mini':         '',
        'maxi':         '',
        'req':          True,
        },
    u'wp10ModèlesPortail': {
        'type':         'list',
        'default':      '',
        'mini':         '',
        'maxi':         '',
        'req':          False,
        },
    u'wp10CatégoriesÉbauche': {
        'type':         'list',
        'default':      '',
        'mini':         '',
        'maxi':         '',
        'req':          False,
        },
    u'wp10StatsCadreRouge': {
        'type':         'boolean',
        'default':      False,
        'mini':         '',
        'maxi':         '',
        'req':          False,
        },
    }


page_definitions = {
    'mainPage': {
        'title':            u'Projet:Wikipédia 1.0',
        },
    '05Page':    {
        'title':            u'@@mainPage@@/Version 0.5',
        },

    # Pages globales
    'globalStats': {
        'title':            u'@@mainPage@@/Statistiques',
        'hasBotSection':    True,
        'botForceSection':  True,
        'pageContent':      u'<center>\r\n##content##\r\n</center>\r\n',
        'botComment':       u'Bot: Mise à jour des statistiques globales du [[Projet:Wikipédia 1.0|Projet Wikipédia 1.0]] (##count##)',
        },
    'globalTotal': {
        'title':            u'@@mainPage@@/Total',
        'hasBotSection':    True,
        'botForceSection':  True,
        'botNoNewLine':     True,
        'pageContent':      u'##count##',
        'botComment':       u'Bot: Mise à jour des statistiques globales du [[Projet:Wikipédia 1.0|Projet Wikipédia 1.0]] (##count##)',
        },
    'projectsList': {
        'title':            u'@@mainPage@@/Index',
        'hasBotSection':    True,
        'botForceSection':  True,
        'pageContent':      u"'''''##count##''''' ''[[Projet:Accueil|projets]] participants.''\r\n----\r\n##content##\r\n",
        'botComment':       u'Bot: Mise à jour de la liste des projets participants à [[Projet:Wikipédia 1.0|Wikipédia 1.0]] (##count##)',
        },

    # Nominations automatiques
    'autoNominations': {
        'title':            u'@@mainPage@@/Nominations automatiques',
        'hasBotSection':    True,
        'botForceSection':  True,
        'pageContent':      u'<noinclude>##navigator##</noinclude>\r\n<small>\'\'Dernière mise à jour : \'\'\'##datetimestr##\'\'\'\'\' par ##login##.</small>\r\n----\r\n<noinclude>\r\n\'\'Articles listés : \'\'\'{{formatnum:##count##}}\'\'\'\'\'\r\n\r\n##content##</noinclude>\r\n',
        'botComment':       u'Bot: Mise à jour de la liste des « nominations automatiques » du projet [[Projet:Wikipédia 1.0|WP 1.0]] (##count##)',
        'navTopLink':       u'@@mainPage@@',
        'navPrecLink':      u'@@autoNominationsHist@@',
        'navPrecName':      u'suivi',
        'navNextLink':      u'@@autoNominationsTable@@',
        'navNextName':      u'synthèse par projet',
        },
    'autoNominationsSubPage': {
        'title':            u'@@autoNominations@@/@@pageNumber@@',
        'hasBotSection':    True,
        'botForceSection':  True,
        'botComment':       u'Bot: Mise à jour de la liste « nominations automatiques » du projet [[Projet:Wikipédia 1.0|WP 1.0]]',
        'pageContent':      u'<noinclude>##navigator##\r\n{{@@autoNominations@@}}</noinclude>\r\n##content##\r\n',
        'navTopLink':       u'@@autoNominations@@',
        'navPrecLink':      u'@@autoNominations@@/@@prevPage@@',
        'navPrecName':      u'page&nbsp;##prevPage##',
        'navNextLink':      u'@@autoNominations@@/@@nextPage@@',
        'navNextName':      u'page&nbsp;##nextPage##',
        'navEntete':        u'Nominations automatiques',
        },
    'autoNominationsTotal': {
        'title':            u'@@autoNominations@@/Total',
        'hasBotSection':    True,
        'botForceSection':  True,
        'botNoNewLine':     True,
        'pageContent':      u'##count##',
        'botComment':       u'Bot: Mise à jour du nombre d\'articles des « nominations automatiques » du projet [[Projet:Wikipédia 1.0|WP 1.0]] (##count##)',
        },
    'autoNominationsTable': {
        'title':            u'@@autoNominations@@/Tableau',
        'hasBotSection':    True,
        'botForceSection':  True,
        'botComment':       u'Bot: Mise à jour de la liste des « nominations automatiques » du projet [[Projet:Wikipédia 1.0|WP 1.0]]',
        'pageContent':      u'<noinclude>##navigator##</noinclude>\r\n##content##',
        'navTopLink':       u'@@mainPage@@',
        'navPrecLink':      u'@@autoNominations@@',
        'navPrecName':      u'liste',
        'navNextLink':      u'@@autoNominationsExcl@@',
        'navNextName':      u'exclusions',
        },
    'autoNominationsExcl': {
        'title':            u'@@autoNominations@@/Exclusions',
        'hasBotSection':    True,
        'botForceSection':  True,
        'botComment':       u'Bot: Mise à jour de la liste des articles exclus des « nominations automatiques » du projet [[Projet:Wikipédia 1.0|WP 1.0]] (##count##)',
        'pageContent':      u'<noinclude>##navigator##</noinclude>\r\n\'\'Articles listés : \'\'\'{{formatnum:##count##}}\'\'\'\'\'\r\n\r\n##content##',
        'navTopLink':       u'@@mainPage@@',
        'navPrecLink':      u'@@autoNominationsTable@@',
        'navPrecName':      u'synthèse par projet',
        'navNextLink':      u'@@autoNominationsHist@@',
        'navNextName':      u'suivi',
        },
    'autoNominationsHist': {
        'title':            u'@@autoNominations@@/Suivi',
        },

    # Version 0.5
    '05SelectionTable': {
        'title':            u'@@05Page@@/Synthèse sélection',
        'hasBotSection':    True,
        'botForceSection':  True,
        'botComment':       u'Bot: Mise à jour du [[Projet:Wikipédia 1.0/Version 0.5|Projet WP1.0 version 0.5]]',
        'pageContent':      u'<noinclude>##navigator##</noinclude>\r\n<small>\'\'Dernière mise à jour : \'\'\'##datetimestr##\'\'\'\'\' par ##login##.</small>\r\n----\r\n##content##\r\n',
        'navTopLink':       u'@@05Page@@',
        },

    # Projets individuels
    'projectPage': {
        'title':            u'Projet:@@name@@',
        },
    'evalPageMainProject': {
        'title':            u'@@projectPage@@/Évaluation',
        },
    'evalPageSubProject': {
        'title':            u'@@mainPage@@/@@name@@',
        },
    'totalPage': {
        'title':            u'@@projectPage@@/Total',
        },
    'totalEvaluatedPage': {
        'title':            u'@@evalPage@@/Total évalué',
        'hasBotSection':    True,
        'botForceSection':  True,
        'botNoNewLine':     True,
        'pageContent':      u'##count##',
        'botComment':       u'Bot: Mise à jour des statistiques du projet ##project## pour [[Projet:Wikipédia 1.0|WP 1.0]] (##count##)',
        },
    'statsSummaryPage': {
        'title':            u'@@evalPage@@/Statistiques',
        'hasBotSection':    False,
        'pageContent':      u'##content##',
        'botComment':       u'Bot: Mise à jour des statistiques du projet ##project## pour [[Projet:Wikipédia 1.0|WP 1.0]] (##count##)',
        },
    'statsDetailPage': {
        'title':            u'@@evalPage@@/Statistiques détaillées',
        'hasBotSection':    True,
        'botForceSection':  True,
        'botComment':       u'Bot: Mise à jour des statistiques du projet ##project## pour [[Projet:Wikipédia 1.0|WP 1.0]] (##count##)',
        'pageContent':      u'<noinclude>##navigator##</noinclude>\r\n<center>\r\n##content##\r\n</center>\r\n',
        'navTopLink':       u'@@evalPage@@',
        'navPrecLink':      u'@@logPage@@',
        'navPrecName':      u'historique',
        'navNextLink':      u'@@indexTopPage@@',
        'navNextName':      u'index',
        },
    'indexTopPage': {
        'title':            u'@@evalPage@@/Index',
        'hasBotSection':    True,
        'botForceSection':  True,
        'botComment':       u'Bot: Mise à jour de la liste des articles évalués du projet ##project## pour [[Projet:Wikipédia 1.0|WP 1.0]]',
        'pageContent':      u'<noinclude>##navigator##</noinclude>\r\n<small>\'\'Dernière mise à jour : \'\'\'##datetimestr##\'\'\'\'\' par ##login##.</small>\r\n----\r\n<noinclude>\r\n##content##\r\n</noinclude>\r\n',
        'navTopLink':       u'@@evalPage@@',
        'navPrecLink':      u'@@statsDetailPage@@',
        'navPrecName':      u'statistiques',
        'navNextLink':      u'@@logPage@@',
        'navNextName':      u'historique',
        },
    'indexSubPage': {
        'title':            u'@@indexTopPage@@/@@pageNumber@@',
        'hasBotSection':    True,
        'botForceSection':  True,
        'botComment':       u'Bot: Mise à jour de la liste des articles évalués du projet ##project## pour [[Projet:Wikipédia 1.0|WP 1.0]]',
        'pageContent':      u'<noinclude>##navigator##\r\n{{@@indexTopPage@@}}</noinclude>\r\n##content##\r\n',
        'navTopLink':       u'@@indexTopPage@@',
        'navPrecLink':      u'@@indexTopPage@@/@@prevPage@@',
        'navPrecName':      u'page&nbsp;##prevPage##',
        'navNextLink':      u'@@indexTopPage@@/@@nextPage@@',
        'navNextName':      u'page&nbsp;##nextPage##',
        },
    'logPage': {
        'title':            u'@@evalPage@@/Historique',
        },
    '05SelectionPage': {
        'title':            u'@@evalPage@@/Articles sélectionnés',
        'hasBotSection':    True,
        'botForceSection':  True,
        'botComment':       u'Bot: Mise à jour de la liste des articles sélectionnés pour [[Projet:Wikipédia 1.0/Version 0.5|WP1.0 version 0.5]] (##count##)',
        'pageContent':      u'<noinclude>##navigator##</noinclude>\r\n<small>\'\'Dernière mise à jour : \'\'\'##datetimestr##\'\'\'\'\' par ##login##.</small>\r\n----\r\n##content##\r\n</noinclude>\r\n',
        'navTopLink':       u'@@05Page@@',
        },
    'parametersPage': {
        'title':            u'@@evalPage@@/Paramètres',
        },
    'committeePage': {
        'title':            u'@@evalPage@@/Comité',
        },
    'link': {
        'title':            u'[[@@evalPage@@|@@name@@]]',
        },

        # Bot
    'botMainPage': {
        'title':            u'@@mainPage@@/Bot',
        },
    'botNavigationTemplate': {
        'title':            u'@@botMainPage@@/Bandeau navigation',
        },
    'botLog': {
        'title':            u'@@botMainPage@@/Log',
        },
    }


# Liste des modèles utilisés pour afficher un désaccord de neutralité
# sur les articles.
npov_templates = (
    u'Modèle:Désaccord de neutralité',
    u'Modèle:POV',
    u'Modèle:PasNeutre',
    u'Modèle:DesaccordDeNeutralite',
    u'Modèle:NPOV',
    u'Modèle:À neutraliser',
    u'Modèle:DdN',
    u'Modèle:Désaccord de pertinence'
    u'Modèle:Pertinence',
    u'Modèle:DesaccordDePertinence',
    )

cell_colors = {
    'FA': {
        'Top':  '#98FB98',
        'High': '#B2FBB2',
        'Mid':  '#CBFBCB',
        'Low':  '#E4FBE4',
        'No':   'transparent',
        },
    'A': {
        'Top':  '#B2FBB2',
        'High': '#B2FBB2',
        'Mid':  '#CBFBCB',
        'Low':  '#E4FBE4',
        'No':   'transparent',
        },
    'GA': {
        'Top':  '#B2FBB2',
        'High': '#B2FBB2',
        'Mid':  '#CBFBCB',
        'Low':  '#E4FBE4',
        'No':   'transparent',
        },
    'B': {
        'Top':  '#B2FBB2',
        'High': '#B2FBB2',
        'Mid':  '#CBFBCB',
        'Low':  '#E4FBE4',
        'No':   'transparent',
        },
    'Start': {
        'Top':  '#CBFBCB',
        'High': '#CBFBCB',
        'Mid':  '#CBFBCB',
        'Low':  '#E4FBE4',
        'No':   'transparent',
        },
    'Stub': {
        'Top':  '#E4FBE4',
        'High': '#E4FBE4',
        'Mid':  '#E4FBE4',
        'Low':  '#E4FBE4',
        'No':   'transparent',
        },
    'Unassessed': {
        'Top':  'transparent',
        'High': 'transparent',
        'Mid':  'transparent',
        'Low':  'transparent',
        'No':   'transparent',
        },
    }
