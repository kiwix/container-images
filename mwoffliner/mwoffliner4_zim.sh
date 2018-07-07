#!/bin/sh

# Allows to write core file
ulimit -c unlimited

ZIM2INDEX=/srv/upload/zim2index/
ARGS="--withZimFullTextIndex --adminEmail=contact@kiwix.org --deflateTmpHtml --verbose --skipHtmlCache --skipCacheCleaning"
MWOFFLINER="mwoffliner --format=novid --format=nopic $ARGS"
MWMATRIXOFFLINER="mwmatrixoffliner --mwUrl=https://meta.wikimedia.org/ $ARGS"

# Wikipedia
$MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM2INDEX/wikipedia/ --language="(sr)" &&

# Wiktionary
$MWMATRIXOFFLINER --project=wiktionary --outputDirectory=$ZIM2INDEX/wiktionary/--language="(en|mg)" &&

# Wiktionary FR
$MWOFFLINER --mwUrl="https://fr.wiktionary.org/" --parsoidUrl="https://fr.wiktionary.org/api/rest_v1/page/html/" --customMainPage="Utilisateur:Stephane_(Kiwix)/Landing" --outputDirectory=$ZIM2INDEX/wiktionary/ &&
