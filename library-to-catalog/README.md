library-to-catalog
===

A script to convert a Kiwix library.xml file into a pibox/ideascube catalog.yml one.

# Requirements

* Python2.7+ or Python3.3+
* Virtualenv
* Working internet connexion (SHA-256 checksum and size of ZIM are fetched online)

## Debian/Ubuntu

``` sh
apt install python3 python3-virtualenv
```

# Installation

* Extract to appropriate location
* run `library-to-catalog.sh` script once (creates virtual envirronment at first start)
* schedule periodic run via cron

``` cron
# m h  dom mon dow   command
0 2 * * * /path/to/library-to-catalog.sh /var/www/library.xml /var/www/kiwix-catalog.yml >> /path/to/lib2cat.log
```

# Usage

``` sh
library-to-catalog.sh library.xml kiwix-catalog.yml [zim|zip]
```

* Script takes two args: path to `library.xml` file and final wanted path for `catalog.yml` file.
* Script first writes to a temporary file and only creates final yaml file upon success so it's safe to use the final location.
* Script **does not download** `library.xml` file. You can easily chain it to a `wget`|`curl` command though.

``` sh
wget -O kiwix_library.xml http://download.kiwix.org/library/library.xml && library-to-catalog.sh kiwix_library.xml /path/to/kiwix.yml
```
