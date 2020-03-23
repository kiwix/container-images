Campus Africa Setup
===================

A kiwix-hotspot like setup for a regular host, using docker containers.


# Goal

Goal is to be able to serve both ZIM files and KA-Lite from the same server. This was developed for Orange MEA in response to schools closing in several african countries.

# Setup

## Assumptions

* Debian/Ubuntu server with docker-ce installed.
* All contents served from a single place (`/data` for instance)
* Single main domain name with the following sub-domains (use `CNAME` records)
 * `zims-fr`
 * `zims-en`
 * `zims-ar`
 * `khan-fr`
 * `khan-en`

## Download content

**Note**: Location of files **crucial**, so please respect-and-create the following structure:

```
/data
    packages/
        fr/
            xxx.zim
            yyy.zim
        en/
            xxx.zim
            yyy.zim
        ar/
            xxx.zim
            yyy.zim
    kalite/
        fr/  # this will be handled by KA-lite
        en/  # idem
        shared/
            kalite_pack_en.zip  # rename downloaded file to this
            kalite_pack_fr.zip  # idem
            kalite_videos_en  # output of tar -xf on downloaded tarball
            kalite_videos_fr  # idem
    certs/  # placeholder for letsencrypt
    html/  # placeholder for home pages
    static/ # placeholder
        branding/ # you'll overwrite this later
    logs/  # placeholder for nginx
```

* Use the `download_content.py` script if you'd like some help in retrieving the content.
* Move the resulting files according to the data structure.
* Download the static folder

``` sh
wget https://github.com/kiwix/kiwix-hotspot/archive/master.zip
unzip master.zip
mv ./kiwix-hotspot-master/ansiblecube/roles/home/files/static /data/
rm -rf ./kiwix-hotspot-master master.zip
```
* Overwrite logo, favicon and style in `/data/static/branding/` with yours.

``` sh
cp branding/* /data/static/branding/
```

## Homepages

One important feature is that we have human-friendly/rebrandable list of content for both the ZIM files and the KA lite.

A script takes care of generating the homepages and the language selector using a template. Template is styled using the branding files mentioned above.

The script is in python, install its dependencies with:

``` sh
cd home/
virtualenv -p python3 venv
source venv/bin/activate
pip install -U pip Jinja2==2.10.1 PyYAML==4.2b4 requests==2.23.0
```

**Launch the script**

``` sh
FQDN="<main_domain>" ./venv/bin/python gen_homepages.py /data
```

If you'd like to customize the _title_ or _description_ of a ZIM, easiest way is to edit the `ideascube.json` file that the script generated. Look for your content from its ID and change the values. Then, re-run the script.

## docker compose

**Important Notes**: you **need** to customize the domain names.

* domain names are referenced in the compose file. Replace those carefully first  otherwise you'll get letsencrypt issues.
* if you want to test without letsencrypt first, just comment all environment lines starting with `- LETSENCRYPT_HOST=`/
* for each kiwix-serve domain, create a `<domain>_location` file in `./vhost.d` (see example). That allows the Kiwix-serve homepage to redirect to the main homepage.
* For each Khan domain, you need to create a symlink to the `khan-<lang>` file in `./vhost.d`. Name your file `<domain>`. That allows the link to set the language appropriately and direct user to the learning area.
* create a file named `kalite-password.txt` next to `docker-compose.yml` to store your desired admin password for KA-lite. Will be used for both EN and FR.

**start-up**

``` sh
docker-compose build  # builds kalite
docker-compose up -d  # startup
docker-compose down # shutdown
docker-compose logs --tail 500 -f # check logs after install
```

