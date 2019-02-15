#!/bin/sh

# Allows to write core file
ulimit -c unlimited

ZIM=/srv/upload/zim2index/
MWMATRIXOFFLINER="mwmatrixoffliner --withZimFullTextIndex --verbose --adminEmail=contact@kiwix.org --mwUrl=https://meta.wikimedia.org/ --deflateTmpHtml --skipCacheCleaning --skipHtmlCache"

# Wikipedia
# MIGRATED $MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM/wikipedia/ --language="(ko|hu)" &&

# Wiktionary
# MIGRATED $MWMATRIXOFFLINER --project=wiktionary --outputDirectory=$ZIM/wiktionary/ --languageInverter --language="(de|en|fr|mg)"
