#!/bin/sh

ZIM2INDEX=/srv/upload/zim2index/
ARGS="--adminEmail=contact@kiwix.org --deflateTmpHtml --verbose --skipHtmlCache --skipCacheCleaning"
MWOFFLINER="mwoffliner --format=novid --format=nopic $ARGS"
MWMATRIXOFFLINER="mwmatrixoffliner --mwUrl=https://meta.wikimedia.org/ $ARGS"

# Wikipedia
$MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM2INDEX/wikipedia/ --language="(ca|ceb|fa|id|ro|sh|war|zh)"
