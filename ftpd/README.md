# ftpd

Simple pure-ftpd image pre-configured for Anonymous downloads.

Tweak the command for runtime-specific options.

Example:

```yaml
command: ["/usr/sbin/pure-ftpd", "-4", "-p", "2000:2050", "-S", "0.0.0.0,21", "-P", "master.download.kiwix.org"]
```
