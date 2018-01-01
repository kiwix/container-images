#!/bin/sh

ZIM2INDEX=/srv/upload/zim2index/
ARGS="--withZimFullTextIndex --adminEmail=contact@kiwix.org --deflateTmpHtml --verbose --skipHtmlCache --skipCacheCleaning"
MWOFFLINER="mwoffliner --format=novid --format=nopic $ARGS"

# Bulbagarden
$MWOFFLINER --mwUrl=https://bulbapedia.bulbagarden.net/ --aocalParsoid --speed=0.1 --outputDirectory=$ZIM2INDEX/other/ &&

# Bollywood
/srv/kiwix-tools/tools/scripts/listCategoryEntries.pl --host=en.wikipedia.org --path=w --exploration=5 --namespace=1 --category="WikiProject_Film_articles" | sed 's/Talk://' | sort -u > "$SCRIPT_DIR/films" &&
/srv/kiwix-tools/tools/scripts/listCategoryEntries.pl --host=en.wikipedia.org --path=w --exploration=5 --namespace=1 --category="WikiProject_India_articles" | sed 's/Talk://' | sort -u > "$SCRIPT_DIR/india" &&
/srv/kiwix-tools/tools/scripts/compareLists.pl --file1=india --file2=films --mode=inter > boolywood &&
wget "https://upload.wikimedia.org/wikipedia/commons/0/01/Bollywoodbarnstar.png" -O "$SCRIPT_DIR/bollywood.png" &&
$MWOFFLINER_MOBILE --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customZimTitle="Bollywood" --customZimDescription="All Wikipedia article about Indian cinema" --customMainPage="Wikipedia:WikiProject_Film/Offline_Bollywood" --customZimFavicon="$SCRIPT_DIR/bollywood.png" --articleList="$SCRIPT_DIR/bollywood" --outputDirectory=$ZIM2INDEX/wikipedia/ &&

# Wikipedia EN WP1 0.8
wget "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/WP1_0_Icon.svg/240px-WP1_0_Icon.svg.png" -O "$SCRIPT_DIR/wp1.png" &&
$MWOFFLINER --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customZimTitle="Wikipedia 0.8" --customZimDescription="Wikipedia 45.000 best articles" --customMainPage="Wikipedia:Version_0.8" --customZimFavicon="$SCRIPT_DIR/wp1.png" --articleList="$SCRIPT_DIR/selections/wp1-0.8.lst" --outputDirectory=$ZIM2INDEX/wikipedia/ &&

# Maths
/srv/kiwix-tools/tools/scripts/listCategoryEntries.pl --host=en.wikipedia.org --path=w --exploration=5 --namespace=1 --category="WikiProject_Mathematics_articles" | sed 's/Talk://' | sort -u > "$SCRIPT_DIR/maths_unfiltered" &&
/srv/kiwix-tools/tools/scripts/listCategoryEntries.pl --host=en.wikipedia.org --path=w --exploration=5 --namespace=1 --category="WikiProject_Biography_articles" --category="WikiProject_Companies_articles" | sed 's/Talk://' | sort -u > "$SCRIPT_DIR/maths_filter" &&
grep -Fxv -f "$SCRIPT_DIR/maths_filter" "$SCRIPT_DIR/maths_unfiltered" | sort -u > "$SCRIPT_DIR/maths" &&
wget "https://upload.wikimedia.org/wikipedia/commons/7/79/Glass_tesseract_still.png" -O "$SCRIPT_DIR/maths.png" &&
$MWOFFLINER_MOBILE --format=nodet --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customZimTitle="Wikipedia Maths" --customZimDescription="15.000 maths articles from Wikipedia" --customMainPage="Wikipedia:WikiProject_Mathematics/Offline" --customZimFavicon="$SCRIPT_DIR/maths.png" --articleList="$SCRIPT_DIR/maths" --outputDirectory=$ZIM2INDEX/wikipedia/ &&

# Computer
wget "https://upload.wikimedia.org/wikipedia/commons/8/8a/Gnome-system.png" -O "$SCRIPT_DIR/computer.png" &&
$MWOFFLINER --mwUrl="https://en.wikipedia.org/" --customZimTitle="code7370" --customZimDescription="A broad but computing-focused subset of Wikipedia" --customMainPage="Computer_science" --customZimFavicon="$SCRIPT_DIR/computer.png" --articleList="$SCRIPT_DIR/selections/wikipedia_en_computer.lst" --outputDirectory=$ZIM2INDEX/wikipedia/ &&

# Wikipedia in English
$MWOFFLINER --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customMainPage="User:Stephane_(Kiwix)/Landing" --outputDirectory=$ZIM2INDEX/wikipedia/
