#!/bin/sh

# Allows to write core file
ulimit -c unlimited

ZIM=/srv/upload/zim/
ARGS="--withZimFullTextIndex --adminEmail=contact@kiwix.org --deflateTmpHtml --verbose --skipHtmlCache --skipCacheCleaning"
MWOFFLINER="mwoffliner --format=novid --format=nopic $ARGS"
MWMATRIXOFFLINER="mwmatrixoffliner --mwUrl=https://meta.wikimedia.org/ $ARGS"

# Wikipedia
$MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM/wikipedia/ --language="(sr)" &&

# Wiktionary
$MWMATRIXOFFLINER --project=wiktionary --outputDirectory=$ZIM/wiktionary/ --language="(en|mg)" &&

# Wiktionary FR
$MWOFFLINER --mwUrl="https://fr.wiktionary.org/" --parsoidUrl="https://fr.wiktionary.org/api/rest_v1/page/html/" --customMainPage="Utilisateur:Stephane_(Kiwix)/Landing" --outputDirectory=$ZIM/wiktionary/

# Wiktionary DE
$MWOFFLINER --mwUrl="https://de.wiktionary.org/" --parsoidUrl="https://de.wiktionary.org/api/rest_v1/page/html/" --namespace=108 --outputDirectory=$ZIM/wiktionary/
