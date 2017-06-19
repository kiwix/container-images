#!/bin/sh

ZIM2INDEX=/srv/upload/zim2index/
ARGS="--adminEmail=contact@kiwix.org --deflateTmpHtml --verbose --skipHtmlCache --skipCacheCleaning"
MWOFFLINER="mwoffliner --format= --format=nopic $ARGS"
MWMATRIXOFFLINER="mwmatrixoffliner --mwUrl=https://meta.wikimedia.org/ $ARGS"

# Wikipedia in English
$MWOFFLINER --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customMainPage="user:Popo_le_Chien/Kiwix" --outputDirectory=$ZIM2INDEX/wikipedia/
