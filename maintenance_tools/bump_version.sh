#!/bin/sh

# changes Kiwix version number everywhere needed
# arguments:
# 	$1: major build version (0.9)
# 	$2: minor build version (alpha8)

# CONSTANTS
BUILDID=`date "+%Y%m%d"`
MAJOR="$1"
MINOR="$2"

if [ "$MAJOR" = "" ]
then
	echo "missing MAJOR_VERSION number."
	echo "Usage:	$0 MAJOR_VERSION MINOR_VERSION"
	exit 1
fi

# NSI Installer for Windows
#!define PRODUCT_VERSION "0.9 alpha7"
sed -ised -e 's/^\!define PRODUCT_VERSION "[0-9\.]* [a-zA-Z0-9\.\-\_]*"/\!define PRODUCT_VERSION "'$MAJOR' '$MINOR'"/' ../moulinkiwix/installer/kiwix-install.nsi.tmpl

# XulRunner application.ini
#BuildID=20110110
sed -ised -e "s/^BuildID=[0-9]*/BuildID=$BUILDID/" ../moulinkiwix/kiwix/application.ini
#Version=0.9
sed -ised -e "s/^Version=[0-9\.]*/Version=$MAJOR/" ../moulinkiwix/kiwix/application.ini

# Xul branding strings file
#<!ENTITY  brand.version               "0.9">
sed -ised -e 's/^<!ENTITY  brand.version               "[0-9\.]*">/<!ENTITY  brand.version               "'$MAJOR'">/' ../moulinkiwix/kiwix/chrome/locale/branding/brand.dtd
#<!ENTITY  brand.subVersion            "alpha8">
sed -ised -e 's/^<!ENTITY  brand.subVersion            "[a-zA-Z0-9\.\-\_]*">/<!ENTITY  brand.subVersion            "'$MINOR'">/' ../moulinkiwix/kiwix/chrome/locale/branding/brand.dtd

# About box content source file
# kiwix/chrome/locale/branding/credits.html

#texta[0] = "Kiwix 0.9 alpha8";
sed -ised -e 's/^texta\[0\] = "Kiwix [0-9\.]* [a-zA-Z0-9\.\-\_]*";/texta\[0\] = "Kiwix '$MAJOR' '$MINOR'";/' ../moulinkiwix/kiwix/chrome/locale/branding/credits.html

# MacOS bundle property file
#<key>CFBundleGetInfoString</key>
#<string>0.9 alpha8</string>
sed -ised -e 's/\<string\>[0-9\.]* [a-zA-Z0-9\.\-\_]*\<\/string\>/\<string\>'$MAJOR' '$MINOR'\<\/string\>/' ../moulinkiwix/src/macosx/Info.plist
#<key>CFBundleShortVersionString</key>
#<string>0.9</string>
sed -ised -e 's/\<key\>CFBundleShortVersionString\<\/key\> 	\<string\>[0-9\.]*\<\/string\>/\<string\>'$MAJOR'\<\/string\>/' ../moulinkiwix/src/macosx/Info.plist
tr '\n\t' ' ' < ../moulinkiwix/src/macosx/Info.plist | sed 's/\<key\>CFBundleShortVersionString\<\/key\>   \<string\>[0-9\.]*\<\/string\>/\<key\>CFBundleShortVersionString\<\/key\>   \<string\>'$MAJOR'\<\/string\>/' | XMLLINT_INDENT=$'\t' xmllint --format --recover --output ../moulinkiwix/src/macosx/Info.plist -