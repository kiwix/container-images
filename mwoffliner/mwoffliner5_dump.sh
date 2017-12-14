#!/bin/sh

ZIM2INDEX=/srv/upload/zim2index/
ARGS="--withZimFullTextIndex --adminEmail=contact@kiwix.org --deflateTmpHtml --verbose --skipHtmlCache --skipCacheCleaning"
MWOFFLINER="mwoffliner --format=novid --format=nopic $ARGS"

# Bulbagarden
$MWOFFLINER --mwUrl=https://bulbapedia.bulbagarden.net/ --aocalParsoid --speed=0.1 --outputDirectory=$ZIM2INDEX/other/

# Wikipedia in English
$MWOFFLINER --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customMainPage="User:Stephane_(Kiwix)/Landing" --outputDirectory=$ZIM2INDEX/wikipedia/
