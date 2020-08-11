Kiwix/openZIM Backup Docker Image
---------------------------------

Kiwix and openZIM backup Docker image is a generic and easy to deploy
backup solution based on BorgBackup, BorgBase and Bitwarden.

## Principle

* A BorgBase account is needed. An API create-only token needs to be
  created to allow the container to create new remote Borg repository
  on demand and configure SSH access.

* A BitWarden account for Business is needed. An entry needs to be
  created with the BorgBase API token.

* A new BitWarden collection needs to be created which will contain
  the secrets to encrypt/decrypt the archives. An invited user needs to
  be created with only the ability to access this specific collection in
  read-only. The goal been to create one entry per backup container.

* A local SSH key pair needs to be configured. This is necessary
  because Borg will use SSH to connect to
  BorgBase. `create_ssh_key_pair.sh` does that for you.

* The secrets to crypt/decrypt the Borg archives needs to be created
  and uploaded to BitWarden. To the contrary of other operations, this
  one-time operation needs the BitWarden master password. We will need
  to upload the SSH keys together as well to avoid any need to
  recreate them afterward which would be cumbersome.

* The SSH public key needs to be uploaded to BorgBase. A new
  repository needs to be created too with the SSH key to access it
  (append-only). `create_new_borgbase_repository.py` allows to do that
  automatically.

* Backup in itself is run by borgmatic which is an advanced command
  line tool build on the top of the native command line client
  `borg`. A default configuration is available at
  `conf/borgmatic.yaml` but one needs to be create by backup.

* Before being able to get new backup, the remote repository needs to
  be initialized. This is mostly to configure how the data (not the
  access) will be encrypted. A choice is still to be made here but
  https://borgbackup.readthedocs.io/en/stable/usage/init.html is worth
  a reading. On our side we need to run `borgmatic -c conf/borgmatic.yaml -v 1 init --encryption repokey`.

* Then to run a new backup, we just need to run `borgmatic -c
  conf/borgmatic.yaml -v 1` as often as necessary.

* To retrieve a backup we can list them first with `borgmatic -c
  conf/borgmatic.yaml -v 1 list` and then retrieve the last archive
  with `borgmatic -c conf/borgmatic.yaml extract --archive latest`. To
  extract at the exact same place use option `--destination /`.

* To deal with databases, we need to read
  https://torsion.org/borgmatic/docs/how-to/backup-your-databases/

* A verify operation should be implemented (and run automatically
  every few weeks) to be able to verify that we can easily retrieve
  things in the future.
  
## Usage
  
To backup files of `<barckupdir>` hourly with a new container :

```
docker run -d -v <barckupdir>:/storage  -e BW_EMAIL=<your_bitwarden_login_mail> -e BW_PASSWORD=<your_bitwarden_master_password> -e BORGBASE_NAME=test_borg -e BORGBASE_KEY=<borgbase_api_token> -ti backup-docker
```
