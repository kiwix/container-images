#!/bin/sh

ZIM2INDEX=/srv/upload/zim2index/
MWMATRIXOFFLINER="mwmatrixoffliner --verbose --deflateTmpHtml --adminEmail=contact@kiwix.org --mwUrl=https://meta.wikimedia.org/ --tmpDirectory=/dev/shm/ --skipCacheCleaning"

# Wikipedia
$MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM2INDEX/wikipedia/ --language="(bg|cs|da|et|el|eo|eu|fi|gl|hy|hi|hr|kk|lt|la|ms|min|nn|no|simple|sk|sl|sr|uk|uz)"