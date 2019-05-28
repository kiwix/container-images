PATTERN_WITHOUT_OPTION="%s %s %s %s\n"
PATTERN_WITH_OPTION="%s %s %s %s %s\n"
ZIM_DIR='/var/www/download.kiwix.org/zim'
find $ZIM_DIR  -name "*.zim"  -printf "%f\n" | awk -v P="$PATTERN_WITHOUT_OPTION" -v POPT="$PATTERN_WITH_OPTION"   'BEGIN{FS="_"} { sub(".zim","",$0);  if ($5 == "") { printf($P,$1,$2,$3, $4  )} else { printf($POPT,$1,$2,$3,$4,$5) }  }'
