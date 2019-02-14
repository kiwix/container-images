#!/bin/sh

# Allows to write core file
ulimit -c unlimited

ZIM=/srv/upload/zim/
ARGS="--withZimFullTextIndex --adminEmail=contact@kiwix.org --deflateTmpHtml --verbose --skipHtmlCache --skipCacheCleaning"
MWOFFLINER="mwoffliner --format=novid --format=nopic $ARGS"
MWMATRIXOFFLINER="mwmatrixoffliner --mwUrl=https://meta.wikimedia.org/ $ARGS"

# Wikisource
# MIGRATED $MWMATRIXOFFLINER --project=wikisource --outputDirectory=$ZIM/wikisource/ --language="(de|en|fr|zh)" &&

# Wikipedia
$MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM/wikipedia/ --language="(sv|vi)"
