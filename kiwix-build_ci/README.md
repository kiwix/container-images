To run the `kiwix-build` command line tool for openZIM & Kiwix CI and
CD, Kiwix Build requires prepared compilation environments for
multiple GNU/Linux systems.

These prepared environments include: compilers, binary toolchains and
any third-party tool necessary to run the compilation toolchain. They
don't contain pre-compiled library dependencies build by kiwix-build,
(like Xapian, Libicu, Libmicrohttps, ...) but they contain dependencies
installed with package manager.

These container images are necessary and intended to be used by Kiwix
itself in many of its CI. But they are free to download et can be
reused, although they can break anytime, therefore at your won risk.
You can find them on
[here](https://github.com/orgs/kiwix/packages?tab=packages&q=kiwix-build).
