# DNS Cache

A simple DNS Cache that uses a DoH (DNS over HTTP) upstream to workaround DNS-related issues.

At the moment, it uses [Cloudflare's DoH](https://developers.cloudflare.com/1.1.1.1/encryption/dns-over-https/)
because it is both reliable and available without bootstraping DNS to resolve its own domain.
