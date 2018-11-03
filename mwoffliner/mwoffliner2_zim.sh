#!/bin/sh

# Allows to write core file
ulimit -c unlimited

ZIM=/srv/upload/zim2index/
MWMATRIXOFFLINER="mwmatrixoffliner --withZimFullTextIndex --verbose --adminEmail=contact@kiwix.org --mwUrl=https://meta.wikimedia.org/ --deflateTmpHtml --skipCacheCleaning --skipHtmlCache"

# Wikipedia
$MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM/wikipedia/ --language="(ko|hu)" &&

# Wiktionary
$MWMATRIXOFFLINER --project=wiktionary --outputDirectory=$ZIM/wiktionary/ --languageInverter --language="(en|fr|mg)"
