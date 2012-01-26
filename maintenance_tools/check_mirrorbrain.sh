#!/bin/bash
curl --silent --head http://download.kiwix.org/zim/0.9/ICD10-fr.zim.mirrorlist | grep Content-Type | grep html > /dev/null ; if [[ "$?" == "1" ]] ; then if [ ! -f /tmp/mb_error ] ; then touch /tmp/mb_error; zenity --display=:1 --error --text="Error with mirrorbrain" ; rm /tmp/mb_error; fi ; fi
