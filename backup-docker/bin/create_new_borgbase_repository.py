#!/usr/bin/python3
from borgbase_api_client.client import GraphQLClient
from borgbase_api_client.mutations import *
import os
import sys
import pprint

TOKEN = os.environ.get("BORGBASE_KEY")
#MYSQL_USER = os.environ.get("MYSQL_USER")
#MYSQL_DB = os.environ.get("MYSQL_DB")
BACKUP_NAME = os.environ.get("BORGBASE_NAME")
os.environ.get("BORGBASE_NAME")
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
            return True

    return False

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


if repo_exists(BACKUP_NAME):
    print("Repo exists with name", BACKUP_NAME)
    sys.exit(0) 


pp = pprint.PrettyPrinter(indent=4)
new_key_vars = {
    'name': 'Key for ' + BACKUP_NAME,
    'keyData': open('/root/.ssh/' + BACKUP_NAME + '_id.pub').readline().strip()
}
pp.pprint(new_key_vars)
res = client.execute(SSH_ADD, new_key_vars)
pp.pprint(res)
new_key_id = res['data']['sshAdd']['keyAdded']['id']

new_repo_vars = {
    'name': BACKUP_NAME,
    'quotaEnabled': False,
    'appendOnlyKeys': [new_key_id],
    'region': 'eu',
    'alertDays': 1,
    'quota': 2048,
    'quotaEnabled': True
}
res = client.execute(REPO_ADD, new_repo_vars)
pp.pprint(res)
new_repo_id = res['data']['repoAdd']['repoAdded']['id']
new_repo_path = new_repo_id + '@' + repo_hostname(new_repo_id) + ':repo'
print('Added new repo with path:', new_repo_path)
with open('/config/borgmatic/config.yaml', 'w') as FILE:
    FILE.write("""
location:
    source_directories:
        - /storage
        - /config
    repositories:
        - """ + new_repo_path + """
storage:
    encryption_passphrase: ""
    borg_base_directory: "/repo"
    borg_cache_directory: "/cache"
    archive_name_format: '""" + BACKUP_NAME + """__backup__{now}'
retention:
    keep_within: 48H
    keep_daily: 7
    keep_weekly: 4
    keep_monthly: 12
    keep_yearly: 1
    prefix: """ + BACKUP_NAME + """__backup__
""")
