# Kiwix tracker

This is the private [BitTorrent](https://en.wikipedia.org/wiki/BitTorrent) tracker of the Kiwix organisation.

It tries to make the best use of the famous [opentracker](https://erdgeist.org/arts/software/opentracker/). 

## Run

```bash
$docker run -d --name bittorrent-tracker -p 6969:6969/udp -p 6969:6969 -v \
  offline_whitelisted_files.tsv:/etc/opentracker/offline_whitelisted_files.tsv ghcr.io/kiwix/bittorrent-tracker`
```

This will bind the port `6969` to the docker container (UDP and TCP) and you're good to go.

The `offline_whitelisted_files.tsv` keeps track of which files are
published at https://library.kiwix.org/. It can be empty at start, but
will be populated over time.

This file is then used (indirectly) by opentracker to know which
torrent can be whitelisted.

## Thanks & Donations
[Best wishes to the creators of opentracker!](http://erdgeist.org/arts/software/opentracker/)
opentracker is _beerware_ so feel free to donate those guys a drink ;-)
