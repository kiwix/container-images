# dropbox

OpenSSH server with configurable, independent jailed users

## Usage

```sh
docker run -v /some/path:/jails/john/data -p 8022:22 -e USERS='[{"id": 1010, "name": "john", "keys": ["ssh-rsa AAAAB3NzaC1yc2EAAAxxxx me@myhost"]}]' ghcr.io/kiwix/dropbox
```

### ⚠️ Note

mount target directory anywhere under `/jails/<user>` (except for existing tree: `bin` `dev` `etc` `lib` `lib64` `usr`).
Each volume you want to allow uploads to must be owned by said user **using same `uid`/`gid` on the host**.

With above example, host needs to `chmod 1010:1010 /some/path` (or any subdirectory one wants to write to).

```sh
scp -p 8022 ~/file.txt john@host:/data/
```

## `USERS` JSON format

- All `id`, `name` and `keys` fields are mandatory.
- `id` field is the user-id (`uid`) to set. `gid` will use same value. `id` must be at least `1000`.
- `name` is the username.
- `keys` is a list of public key strings to add to the authorized keys.

```json
[{"id": 1000, "name": "ci", "keys": ["ssh-rsa AAAAB3NzaC1yc2EAAAxxxx user@host"]}]
```
