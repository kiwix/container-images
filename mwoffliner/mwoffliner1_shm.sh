#!/bin/sh

# Allows to write core file
ulimit -c unlimited

ZIM=/srv/upload/zim/
ARGS="--withZimFullTextIndex --deflateTmpHtml --verbose --adminEmail=contact@kiwix.org --skipCacheCleaning --skipHtmlCache --tmpDirectory=/dev/shm/"
MWOFFLINER="mwoffliner --format=novid --format=nopic $ARGS"
MWOFFLINER_MOBILE="$MWOFFLINER --mobileLayout"
MWMATRIXOFFLINER="mwmatrixoffliner --mwUrl=https://meta.wikimedia.org/ $ARGS"
MWMATRIXOFFLINER_MOBILE="$MWMATRIXOFFLINER --mobileLayout"

# Wikibooks
WIKIBOOKS_ARGS="--outputDirectory=$ZIM/wikibooks/"
$MWMATRIXOFFLINER --project=wikibooks $WIKIBOOKS_ARGS --languageInverter --language="(en)" &&
$MWOFFLINER --mwUrl="https://en.wikibooks.org/" $WIKIBOOKS_ARGS --addNamespaces="112" &&

# Wikispecies
$MWMATRIXOFFLINER --project=species --outputDirectory=$ZIM/wikispecies/ &&

# Wikisource
$MWMATRIXOFFLINER --project=wikisource --outputDirectory=$ZIM/wikisource/ --language="(en|de|fr|zh)" --languageInverter &&

# Wikivoyage
$MWMATRIXOFFLINER_MOBILE --project=wikivoyage --outputDirectory=$ZIM/wikivoyage/ --languageInverter --language="(en|de)" &&

# Wikiquote
$MWMATRIXOFFLINER --project=wikiquote --outputDirectory=$ZIM/wikiquote/ &&

# Wikiversity
$MWMATRIXOFFLINER --project=wikiversity --outputDirectory=$ZIM/wikiversity/ &&

# Wikipedia
$MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM/wikipedia/ --languageInverter --language="(ar|bg|ceb|cs|da|de|el|en|eo|eu|et|es|fi|fr|gl|hu|hy|hi|hr|it|ja|kk|ms|min|nl|nn|no|ro|simple|sk|sl|sr|sh|tr|pl|pt|ru|sv|vi|war|fa|ca|ko|id|he|la|lt|uk|uz|zh)"
