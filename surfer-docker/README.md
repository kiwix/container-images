Own network "drive" with Surfer
===============================

This is a custom `Dockerfile` using
[Surfer](https://git.cloudron.io/cloudron/surfer) providing a simple
Web user and WebDAV online drive to store files.

Start a container with:
```bash
docker run -p 80:3000 -e "PASSWORD=foobar" -v /my_data_dir:/data ghcr.io/openzim/surfer
```

To connect to the admin dashboard use admin / PASSWORD credentials.