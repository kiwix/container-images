#!/bin/sh

ZIM2INDEX=/srv/upload/zim2index/
ARGS="--adminEmail=contact@kiwix.org --deflateTmpHtml --verbose --skipHtmlCache --skipCacheCleaning"
MWOFFLINER="mwoffliner --format=novid --format=nopic $ARGS"

# Wikipedia in English
$MWOFFLINER --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customMainPage="User:Stephane_(Kiwix)/Landing" --outputDirectory=$ZIM2INDEX/wikipedia/
