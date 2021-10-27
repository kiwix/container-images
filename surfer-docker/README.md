Own network "drive" with Surfer
===============================

This is a custom `Dockerfile` using
[Surfer](https://git.cloudron.io/cloudron/surfer) providing a simple
Web user and WebDAV online drive to store files.

Start a container with:
```bash
docker run --name surfer -p 3000:3000 ghcr.io/openzim/surfer
```