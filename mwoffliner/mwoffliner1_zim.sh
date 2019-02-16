#!/bin/sh

# Allows to write core file
ulimit -c unlimited

ZIM=/srv/upload/zim2index/
ARGS="--withZimFullTextIndex --adminEmail=contact@kiwix.org --deflateTmpHtml --verbose --skipHtmlCache --skipCacheCleaning"
MWOFFLINER="mwoffliner --format=novid --format=nopic $ARGS"
MWMATRIXOFFLINER="mwmatrixoffliner --mwUrl=https://meta.wikimedia.org/ $ARGS"

# Wikipedia
# MIGRATED $MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM/wikipedia/ --language="(ca|ceb|fa|id|ro|sh|war|zh)"
