#!/usr/bin/python3
from borgbase_api_client.client import GraphQLClient
from borgbase_api_client.mutations import *
import os
import sys
import pprint
import subprocess

TOKEN = os.environ.get("BORGBASE_KEY")
#MYSQL_USER = os.environ.get("MYSQL_USER")
#MYSQL_DB = os.environ.get("MYSQL_DB")
BACKUP_NAME = os.environ.get("BORGBASE_NAME")
CONFIG_DIR = "/root/"
BORGMATIC_CONFIG = CONFIG_DIR + ".config/borgmatic/config.yaml"
KNOWN_HOSTS_FILE = os.environ.get("KNOWN_HOSTS_FILE")

client = GraphQLClient(TOKEN)

def repo_exists(name):
    query = """
    {
      repoList {
        id
        name
      }
    }
    """
    res = client.execute(query)
    for repo in res['data']['repoList']:
        if repo['name'] == name:
            return repo['id']

    return ''

def repo_hostname(repo_id):
    query = """
    {
      repoList {
        id
        name
        server {
          hostname
        }
      }
    }
    """
    res = client.execute(query)
    pp = pprint.PrettyPrinter(indent=4)
    pp.pprint(res)
    for repo in res['data']['repoList']:
        if repo['id'] == repo_id:
            return repo['server']['hostname']

def create_repo(name):
    pp = pprint.PrettyPrinter(indent=4)
    new_key_vars = {
        'name': 'Key for ' + name,
        'keyData': open(CONFIG_DIR+'.ssh/' + name + '_id.pub').readline().strip()
    }
    pp.pprint(new_key_vars)
    res = client.execute(SSH_ADD, new_key_vars)
    pp.pprint(res)
    new_key_id = res['data']['sshAdd']['keyAdded']['id']

    new_repo_vars = {
        'name': name,
        'quotaEnabled': False,
        'appendOnlyKeys': [new_key_id],
        'region': 'eu',
        'alertDays': 1,
        'quota': 2048,
        'quotaEnabled': True
    }
    res = client.execute(REPO_ADD, new_repo_vars)
    
    pp.pprint(res)
    
    return res['data']['repoAdd']['repoAdded']['id']

def main(name):
    repo_id = repo_exists(name)
    new_repo = False

    if len(repo_id) > 0 :
        print("Repo exists with name", name)
    else:
        print("Repo not exists with name", name, ", create it ...")
        repo_id = create_repo(name)
        new_repo = True

    hostname = repo_hostname(repo_id)
    repo_path = repo_id + '@' + hostname + ':repo'

    with open(KNOWN_HOSTS_FILE, "w") as outfile:
        subprocess.run(["/usr/bin/ssh-keyscan","-H", hostname], stdout=outfile)

    print('Use repo path :', repo_path)

    with open(BORGMATIC_CONFIG, 'w') as FILE:
        FILE.write("""
    location:
        source_directories:
            - /storage
            - /config
        repositories:
            - """ + repo_path + """
    storage:
        encryption_passphrase: ""
        borg_base_directory: "/repo"
        borg_cache_directory: "/cache"
        archive_name_format: '""" + name + """__backup__{now}'
    retention:
        keep_within: 48H
        keep_daily: 7
        keep_weekly: 4
        keep_monthly: 12
        keep_yearly: 1
        prefix: """ + name + """__backup__
    """)

    if (new_repo):
        print("Init Borgmatic ...")
        subprocess.call(["/root/.local/bin/borgmatic", "-c", BORGMATIC_CONFIG, "-v", "1", "init","--encryption","repokey"])

if __name__ == '__main__':
    main(BACKUP_NAME)
