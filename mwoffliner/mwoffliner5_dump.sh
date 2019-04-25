#!/bin/sh

# Allows to write core file
ulimit -c unlimited

SCRIPT=`readlink -f $0/../`
SCRIPT_DIR=`dirname "$SCRIPT"`
ZIM=/srv/upload/zim/
ARGS="--withZimFullTextIndex --adminEmail=contact@kiwix.org --deflateTmpHtml --verbose --skipHtmlCache --skipCacheCleaning"
MWOFFLINER="mwoffliner --format=novid --format=nopic $ARGS"
MWOFFLINER_MOBILE="$MWOFFLINER --mobileLayout"

# Bulbagarden
$MWOFFLINER --mwUrl=https://bulbapedia.bulbagarden.net/ --localParsoid --speed=0.1 --outputDirectory=$ZIM/other/ &&

# Bollywood
/srv/kiwix-tools/tools/scripts/listCategoryEntries.pl --host=en.wikipedia.org --path=w --exploration=5 --namespace=1 --category="Actors_and_filmmakers_work_group_articles" --category="WikiProject_Film_articles" | sed 's/Talk://' | sort -u > "$SCRIPT_DIR/films" &&
/srv/kiwix-tools/tools/scripts/listCategoryEntries.pl --host=en.wikipedia.org --path=w --exploration=5 --namespace=1 --category="WikiProject_India_articles" | sed 's/Talk://' | sort -u > "$SCRIPT_DIR/india" &&
/srv/kiwix-tools/tools/scripts/compareLists.pl --file1=india --file2=films --mode=inter > bollywood &&
wget "https://upload.wikimedia.org/wikipedia/commons/0/01/Bollywoodbarnstar.png" -O "$SCRIPT_DIR/bollywood.png" &&
$MWOFFLINER_MOBILE --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customZimTitle="Bollywood" --customZimDescription="All Wikipedia articles about Indian cinema" --customMainPage="Wikipedia:WikiProject_Film/Offline_Bollywood" --customZimFavicon="$SCRIPT_DIR/bollywood.png" --articleList="$SCRIPT_DIR/bollywood" --outputDirectory=$ZIM/wikipedia/ &&

# Wikipedia EN WP1 0.8
wget "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/WP1_0_Icon.svg/240px-WP1_0_Icon.svg.png" -O "$SCRIPT_DIR/wp1.png" &&
$MWOFFLINER --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customZimTitle="Wikipedia 0.8" --customZimDescription="Wikipedia 45.000 best articles" --customMainPage="Wikipedia:Version_0.8" --customZimFavicon="$SCRIPT_DIR/wp1.png" --articleList="$SCRIPT_DIR/selections/wp1-0.8.lst" --outputDirectory=$ZIM/wikipedia/ &&

# Download list of articles to excludes from selections
/srv/kiwix-tools/tools/scripts/listCategoryEntries.pl --host=en.wikipedia.org --path=w --exploration=5 --namespace=1 --category="WikiProject_Biography_articles" --category="WikiProject_Companies_articles" | sed 's/Talk://' | sort -u > "$SCRIPT_DIR/filter_out" &&

# Physics
/srv/kiwix-tools/tools/scripts/listCategoryEntries.pl --host=en.wikipedia.org --path=w --exploration=5 --namespace=1 --category="WikiProject_Physics_articles" | sed 's/Talk://' | sort -u > "$SCRIPT_DIR/physics_unfiltered" &&
grep -Fxv -f "$SCRIPT_DIR/filter_out" "$SCRIPT_DIR/physics_unfiltered" | sort -u > "$SCRIPT_DIR/physics" &&
wget "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Stylised_atom_with_three_Bohr_model_orbits_and_stylised_nucleus.svg/266px-Stylised_atom_with_three_Bohr_model_orbits_and_stylised_nucleus.svg.png" -O "$SCRIPT_DIR/physics.png" &&
$MWOFFLINER_MOBILE --format=nodet --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customZimTitle="Wikipedia Physics" --customZimDescription="20,000 Physics articles from Wikipedia" --customMainPage="Wikipedia:WikiProject_Physics/Offline" --customZimFavicon="$SCRIPT_DIR/physics.png" --articleList="$SCRIPT_DIR/physics" --outputDirectory=$ZIM/wikipedia/ &&

# Molecular & Cell Biology
/srv/kiwix-tools/tools/scripts/listCategoryEntries.pl --host=en.wikipedia.org --path=w --exploration=5 --namespace=1 --category="WikiProject_Molecular_and_Cellular_Biology_articles" | sed 's/Talk://' | sort -u > "$SCRIPT_DIR/molcell_unfiltered" &&
grep -Fxv -f "$SCRIPT_DIR/filter_out" "$SCRIPT_DIR/molcell_unfiltered" | sort -u > "$SCRIPT_DIR/molcell" &&
wget "https://upload.wikimedia.org/wikipedia/commons/7/73/MolCellBiol_Kiwix.png" -O "$SCRIPT_DIR/molcell.png" &&
$MWOFFLINER_MOBILE --format=nodet --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customZimTitle="Wikipedia Molecular and Cell Biology" --customZimDescription="30,000 Molecular and Cell Biology articles from Wikipedia" --customMainPage="Wikipedia:WikiProject_Molecular_and_Cell_Biology/Offline" --customZimFavicon="$SCRIPT_DIR/molcell.png" --articleList="$SCRIPT_DIR/molcell" --outputDirectory=$ZIM/wikipedia/ &&

# Maths
/srv/kiwix-tools/tools/scripts/listCategoryEntries.pl --host=en.wikipedia.org --path=w --exploration=5 --namespace=1 --category="WikiProject_Mathematics_articles" | sed 's/Talk://' | sort -u > "$SCRIPT_DIR/maths_unfiltered" &&
grep -Fxv -f "$SCRIPT_DIR/filter_out" "$SCRIPT_DIR/maths_unfiltered" | sort -u > "$SCRIPT_DIR/maths" &&
wget "https://upload.wikimedia.org/wikipedia/commons/7/79/Glass_tesseract_still.png" -O "$SCRIPT_DIR/maths.png" &&
$MWOFFLINER_MOBILE --format=nodet --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customZimTitle="Wikipedia Maths" --customZimDescription="15,000 maths articles from Wikipedia" --customMainPage="Wikipedia:WikiProject_Mathematics/Offline" --customZimFavicon="$SCRIPT_DIR/maths.png" --articleList="$SCRIPT_DIR/maths" --outputDirectory=$ZIM/wikipedia/ &&

# Chemistry
/srv/kiwix-tools/tools/scripts/listCategoryEntries.pl --host=en.wikipedia.org --path=w --exploration=5 --namespace=1 --category="WikiProject_Chemistry_articles" | sed 's/Talk://' | sort -u > "$SCRIPT_DIR/chemistry_unfiltered" &&
grep -Fxv -f "$SCRIPT_DIR/filter_out" "$SCRIPT_DIR/chemistry_unfiltered" | sort -u > "$SCRIPT_DIR/chemistry" &&
wget "https://upload.wikimedia.org/wikipedia/commons/thumb/5/59/Nuvola_apps_edu_science.svg/128px-Nuvola_apps_edu_science.svg.png" -O "$SCRIPT_DIR/chemistry.png" &&
$MWOFFLINER_MOBILE --format=nodet --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customZimTitle="Wikipedia Chemistry" --customZimDescription="10,000 chemistry articles from Wikipedia" --customMainPage="Wikipedia:WikiProject_Chemistry/Offline" --customZimFavicon="$SCRIPT_DIR/chemistry.png" --articleList="$SCRIPT_DIR/chemistry" --outputDirectory=$ZIM/wikipedia/ &&

# Football
mwoffliner --verbose --mwUrl="https://en.wikipedia.org/" --adminEmail=kelson@kiwix.org --customZimFavicon="https://upload.wikimedia.org/wikipedia/en/thumb/e/ec/Soccer_ball.svg/900px-Soccer_ball.svg.png" --customZimTitle="Football by Wikipedia" --customZimDescription="Wikipedia articles dedicated to Football" --articleList=https://download.kiwix.org/wp1/enwiki/projects/Football --withZimFullTextIndex  --format=novid --format=nopic

# Basketball
mwoffliner --verbose --mwUrl="https://en.wikipedia.org/" --adminEmail=kelson@kiwix.org --customZimFavicon="https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/Basketball.svg/180px-Basketball.svg.png" --customZimTitle="Basketball by Wikipedia" --customZimDescription="Wikipedia articles dedicated to Basketball" --articleList=https://download.kiwix.org/wp1/enwiki/projects/Basketball --withZimFullTextIndex --format=novid --format=nopic

# History
mwoffliner --verbose --mwUrl="https://en.wikipedia.org/" --adminEmail=kelson@kiwix.org --customZimFavicon="https://upload.wikimedia.org/wikipedia/commons/a/af/P_history.png" --customZimTitle="History by Wikipedia" --customZimDescription="Wikipedia articles dedicated to History" --articleList=https://download.kiwix.org/wp1/enwiki/projects/History --withZimFullTextIndex --format=nopic --format=novid

# Geography
mwoffliner --verbose --mwUrl="https://en.wikipedia.org/" --adminEmail=kelson@kiwix.org --customZimFavicon="https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Globe.svg/900px-Globe.svg.png" --customZimTitle="Geography by Wikipedia" --customZimDescription="Wikipedia articles dedicated to Geography" --articleList=https://download.kiwix.org/wp1/enwiki/projects/Geography --format=novid --format=nopic

# Computer
wget "https://upload.wikimedia.org/wikipedia/commons/8/8a/Gnome-system.png" -O "$SCRIPT_DIR/computer.png" &&
$MWOFFLINER --mwUrl="https://en.wikipedia.org/" --customZimTitle="code7370" --customZimDescription="A broad but computing-focused subset of Wikipedia" --customMainPage="Computer_science" --customZimFavicon="$SCRIPT_DIR/computer.png" --articleList="$SCRIPT_DIR/selections/computer.lst" --outputDirectory=$ZIM/wikipedia/ &&

# Wikipedia in English
# MIGRATED $MWOFFLINER --mwUrl="https://en.wikipedia.org/" --parsoidUrl="https://en.wikipedia.org/api/rest_v1/page/html/" --customMainPage="User:Stephane_(Kiwix)/Landing" --outputDirectory=$ZIM/wikipedia/
