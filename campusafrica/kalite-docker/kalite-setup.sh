#!/bin/bash

echo "KA-lite setup starting..."

function die() {
    echo $1
    exit 1
}

if [ -f /var/run/kalite-password.txt ]
then
    ADMIN_PASSWORD=$(cat kalite-password.txt)
fi

function importlangpack() {
    lang=$1
    echo "import Kalite language pack: ${lang}"
    marker="${KALITE_HOME}/done_setup_lang_${lang}"
    if [ ! -f $marker ]
    then
        "${KALITE_ENV}/bin/kalite" manage retrievecontentpack local $lang ${KALITE_LANGPACKS_PREFIX}${lang}.zip || die "Unable to import lang pack for ${lang}"
        touch $marker
    fi
}

langs=(${KALITE_LANGS//:/ })

marker="${KALITE_HOME}/done_setup_account"
if [ ! -f $marker ]
    then
        echo "setting up KA-lite env (${ADMIN_ACCOUNT} / ${ADMIN_PASSWORD})"
        "${KALITE_ENV}/bin/kalite" manage setup --username="$ADMIN_ACCOUNT" --password="$ADMIN_PASSWORD" --noinput || die "Unable to setup KAlite and create account"
        touch $marker
    fi

importlangpack "en"

for lang in "${langs[@]}"
do
    echo "STARTUP SETUP for KA-lite ${lang}"

    importlangpack $lang

    echo "move downloaded videos to kalite folder"
    mv ${KALITE_VIDEOS_PREFIX}${lang}/* ${KALITE_HOME}/content/

    # loop over content folder to find and reckon downloaded video files
    echo "Perfom a video scan on the device"
    marker="${KALITE_HOME}/done_scanvideo_${lang}"
    if [ ! -f $marker ]
    then
        "${KALITE_ENV}/bin/kalite" manage videoscan --language=$lang || die "Unable to scan videos for ${lang}"
        touch $marker
    fi
done
