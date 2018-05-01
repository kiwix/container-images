#!/bin/sh

# Allows to write core file
ulimit -c unlimited

ZIM2INDEX=/srv/upload/zim2index/
ARGS="--withZimFullTextIndex --deflateTmpHtml --verbose --adminEmail=contact@kiwix.org --skipCacheCleaning --skipHtmlCache --tmpDirectory=/dev/shm/"
MWOFFLINER="mwoffliner --format=novid --format=nopic $ARGS"
MWMATRIXOFFLINER="mwmatrixoffliner --mwUrl=https://meta.wikimedia.org/ $ARGS"

# Wikibooks
WIKIBOOKS_ARGS="--outputDirectory=$ZIM2INDEX/wikibooks/"
$MWMATRIXOFFLINER --project=wikibooks $WIKIBOOKS_ARGS --languageInverter --language="(en)" --languageTrigger="ba" &&
$MWOFFLINER --mwUrl="https://en.wikibooks.org/" $WIKIBOOKS_ARGS --addNamespaces="112" &&

# Wikispecies
$MWMATRIXOFFLINER --project=species --outputDirectory=$ZIM2INDEX/wikispecies/ &&

# Wikisource
$MWMATRIXOFFLINER --project=wikisource --outputDirectory=$ZIM2INDEX/wikisource/ --language="(en|de|fr|zh)" --languageInverter &&

# Wikivoyage
$MWMATRIXOFFLINER --project=wikivoyage --outputDirectory=$ZIM2INDEX/wikivoyage/ --languageInverter --language="(en|de)" &&

# Wikiquote
$MWMATRIXOFFLINER --project=wikiquote --outputDirectory=$ZIM2INDEX/wikiquote/ &&

# Wikiversity
$MWMATRIXOFFLINER --project=wikiversity --outputDirectory=$ZIM2INDEX/wikiversity/ &&

# Wikipedia
$MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM2INDEX/wikipedia/ --languageInverter --language="(ar|bg|ceb|cs|da|de|el|en|eo|eu|et|es|fi|fr|gl|hu|hy|hi|hr|it|ja|kk|ms|min|nl|nn|no|ro|simple|sk|sl|sr|sh|tr|pl|pt|ru|sv|vi|war|fa|ca|ko|id|he|la|lt|uk|uz|zh)"
