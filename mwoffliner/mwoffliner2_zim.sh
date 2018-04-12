#!/bin/sh

ZIM2INDEX=/srv/upload/zim2index/
MWMATRIXOFFLINER="mwmatrixoffliner --withZimFullTextIndex --verbose --adminEmail=contact@kiwix.org --mwUrl=https://meta.wikimedia.org/ --deflateTmpHtml --skipCacheCleaning --skipHtmlCache"

# Wikipedia
$MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM2INDEX/wikipedia/ --language="(ko|hu)" &&

# Wiktionary
$MWMATRIXOFFLINER --project=wiktionary --outputDirectory=$ZIM2INDEX/wiktionary/ --languageInverter --language="(fr)"
