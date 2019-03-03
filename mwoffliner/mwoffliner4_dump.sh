#!/bin/sh

# Allows to write core file
ulimit -c unlimited

ZIM=/srv/upload/zim/
ARGS="--withZimFullTextIndex --adminEmail=contact@kiwix.org --deflateTmpHtml --verbose --skipHtmlCache --skipCacheCleaning"
MWOFFLINER="mwoffliner --format=novid --format=nopic $ARGS"
MWMATRIXOFFLINER="mwmatrixoffliner --mwUrl=https://meta.wikimedia.org/ $ARGS"

# Wikipedia in Arabic
# MIGRATED $MWOFFLINER --mwUrl="https://ar.wikipedia.org/" --parsoidUrl="https://ar.wikipedia.org/api/rest_v1/page/html/" --customMainPage="مستخدم:Stephane_(Kiwix)/Landing" --outputDirectory=$ZIM/wikipedia/ &&

# Wikipedia in Hebrew
# MIGRATED $MWOFFLINER --mwUrl="https://he.wikipedia.org/" --parsoidUrl="https://he.wikipedia.org/api/rest_v1/page/html/" --customMainPage="ויקיפדיה:עמוד_ראשי/לא-מקוון" --outputDirectory=$ZIM/wikipedia/ &&

# Wikipedia in French
# MIGRATED $MWOFFLINER --mwUrl="https://fr.wikipedia.org/" --parsoidUrl="https://fr.wikipedia.org/api/rest_v1/page/html/" --customMainPage="Utilisateur:Popo_le_Chien/Kiwix" --outputDirectory=$ZIM/wikipedia/ &&

# Wikipedia in Spanish
# MIGRATED $MWOFFLINER --mwUrl="https://es.wikipedia.org/" --parsoidUrl="https://es.wikipedia.org/api/rest_v1/page/html/" --customMainPage="Usuario:Popo_le_Chien/Kiwix" --outputDirectory=$ZIM/wikipedia/ &&

# Wikipedia TR
# MIGRATED $MWOFFLINER --mwUrl="https://tr.wikipedia.org/" --parsoidUrl="https://tr.wikipedia.org/api/rest_v1/page/html/" --customMainPage="Kullanıcı:Stephane_(Kiwix)/Landing" --outputDirectory=$ZIM/wikipedia/ &&

# Wikipedia DE
# MIGRATED $MWOFFLINER --mwUrl="https://de.wikipedia.org/" --parsoidUrl="https://de.wikipedia.org/api/rest_v1/page/html/" --customMainPage="Benutzer:The_other_Kiwix_guy/Landing" --outputDirectory=$ZIM/wikipedia/ &&

# Wikipedia
# MIGRATED $MWMATRIXOFFLINER --project=wiki --outputDirectory=$ZIM/wikipedia/ --language="(fi|no|it)"
