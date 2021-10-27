# Shared files access using Surfer

Custom [Surfer](https://git.cloudron.io/cloudron/surfer) container with configurable Admin password via docker secrets to share common files publicly for other tools such as [Zimfarm](https://github.com/openzim/zimfarm).

## Usage

```sh
docker run -p 8080:80 -e "PASSWORD=foobar" -v /my_data_dir:/data ghcr.io/openzim/surfer
```

Connect to admin dashboard using admin / admin (default) or your specified password.