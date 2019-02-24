#!/bin/sh

# Allows to write core file
ulimit -c unlimited

ZIM=/srv/upload/zim/
MWMATRIXOFFLINER="mwmatrixoffliner --withZimFullTextIndex --verbose --adminEmail=contact@kiwix.org --mwUrl=https://meta.wikimedia.org/ --deflateTmpHtml --skipCacheCleaning --skipHtmlCache"

# Wikipedia
# MIGRATED $MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM/wikipedia/ --language="(ja|nl|pl|pt|ru)"
