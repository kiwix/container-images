#!/bin/sh

# Allows to write core file
ulimit -c unlimited

ZIM=/srv/upload/zim/
MWMATRIXOFFLINER="mwmatrixoffliner --withZimFullTextIndex --verbose --deflateTmpHtml --adminEmail=contact@kiwix.org --mwUrl=https://meta.wikimedia.org/ --tmpDirectory=/dev/shm/ --skipCacheCleaning --skipHtmlCache"

# Wikipedia
$MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM/wikipedia/ --language="(bg|cs|da|et|el|eo|eu|gl|hy|hi|hr|kk|lt|la|ms|min|nn|simple|sk|sl|uk|uz)"
