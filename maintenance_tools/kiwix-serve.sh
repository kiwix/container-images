#!/bin/bash

if [ ! "`pidof kiwix-serve`" == "" ]
then
    kill -9 `pidof kiwix-serve`
fi

nice -10 kiwix-serve --port=4201 --index="wikipedia_en_wp1_0.7_30000+_05_2009_beta3.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_en_wp1_0.7_30000+_05_2009_beta3.zim" 
nice -10 kiwix-serve --port=4202 --index="schools-wikipedia-full-20081023-rc5.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/schools-wikipedia-full-20081023-rc5.zim"
nice -10 kiwix-serve --port=4203 --index="wikipedia_en_wp1_0.5_2000+_03_2007_rc2.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_en_wp1_0.5_2000+_03_2007_rc2.zim"
nice -10 kiwix-serve --port=4204 --index="wikipedia_ar_all_04_2011.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_ar_all_04_2011.zim"
nice -10 kiwix-serve --port=4205 --index="wmf_fa_all_07_2010_rc2.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wmf_fa_all_07_2010_rc2.zim"
nice -10 kiwix-serve --port=4206 --index="wikipedia_it_all_02_2011.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_it_all_02_2011.zim"
nice -10 kiwix-serve --port=4207 --index="ubuntudoc_fr_01_2009.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/ubuntudoc_fr_01_2009.zim"
nice -10 kiwix-serve --port=4208 --index="wikipedia_he_all_07_2011.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_he_all_07_2011.zim"
nice -10 kiwix-serve --port=4209 --index="wikipedia_zh_all_05_2010_alpha1.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_zh_all_05_2010_alpha1.zim"
nice -10 kiwix-serve --port=4210 --index="wikipedia_ml_500+_05_2010_beta2.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_ml_500+_05_2010_beta2.zim"
nice -10 kiwix-serve --port=4211 --index="wikipedia_ml_all_06_2010_beta1.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_ml_all_06_2010_beta1.zim"
nice -10 kiwix-serve --port=4212 --index="wikipedia_fr_all_07_2011.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_fr_all_07_2011.zim"
nice -10 kiwix-serve --port=4213 --index="wikipedia_pt_all_10_2010_alpha1.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_pt_all_10_2010_alpha1.zim"
nice -10 kiwix-serve --port=4214 --index="wikipedia_es_all_09_2010_beta1.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_es_all_09_2010_beta1.zim"
nice -10 kiwix-serve --port=4215 --index="vikidia_fr_all_10_2010_alpha1.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/vikidia_fr_all_10_2010_alpha1.zim"
nice -10 kiwix-serve --port=4216 --index="wikipedia_pl_dvd_2006_beta1.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_pl_dvd_2006_beta1.zim"
nice -10 kiwix-serve --port=4217 --index="wikipedia_de_all_10_2010_beta1.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_de_all_10_2010_beta1.zim"
nice -10 kiwix-serve --port=4218 --index="wikipedia_en_wp1_0.8_45000+_12_2010.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_en_wp1_0.8_45000+_12_2010.zim"
nice -10 kiwix-serve --port=4219 --index="wikipedia_wiktionary_my_all_07_2011.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_wiktionary_my_all_07_2011.zim"
nice -10 kiwix-serve --port=4220 --index="wikipedia_pl_all_01_2011_alpha1.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_pl_all_01_2011_alpha1.zim"
nice -10 kiwix-serve --port=4221 --index="wikipedia_nl_all_01_2011_beta1.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_nl_all_01_2011_beta1.zim"
nice -10 kiwix-serve --port=4222 --index="wikipedia_ja_all_03_2011.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_ja_all_03_2011.zim"
nice -10 kiwix-serve --port=4223 --index="wikipedia_ur_all_04_2011.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_ur_all_04_2011.zim"
nice -10 kiwix-serve --port=4224 --index="wikipedia_sw_all_04_2011.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_sw_all_04_2011.zim"
nice -10 kiwix-serve --port=4225 --index="wikipedia_ru_all_05_2011.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_ru_all_05_2011.zim"
nice -10 kiwix-serve --port=4226 --index="wikipedia_en_simple_all_08_2011.zim.idx" --daemon "/var/www/download.kiwix.org/zim/0.9/wikipedia_en_simple_all_08_2011.zim"
