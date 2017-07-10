#!/bin/sh

ZIM2INDEX=/srv/upload/zim2index/
MWMATRIXOFFLINER="mwmatrixoffliner --verbose --adminEmail=contact@kiwix.org --mwUrl=https://meta.wikimedia.org/ --deflateTmpHtml --skipCacheCleaning"

# Wikipedia
$MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM2INDEX/wikipedia/ --language="(ja|nl|pl|pt|ru)"
