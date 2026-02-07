#!/usr/bin/env bash
set -e

ORG_NAME="$1"
TEMPLATE_DIR="$2"

if [ -z "$ORG_NAME" ] || [ -z "$TEMPLATE_DIR" ]; then
  echo "Usage: ./sync-files.sh <org-name> <template-dir>"
  exit 1
fi

REPOS=$(gh repo list "$ORG_NAME" --limit 1000 --json name --jq '.[].name')

for repo in $REPOS; do
  echo "Syncing $repo"
  gh repo clone "$ORG_NAME/$repo" "/tmp/$repo" || continue
  rsync -av "$TEMPLATE_DIR/" "/tmp/$repo/"
  cd "/tmp/$repo"
  git add .
  git commit -m "chore: sync shared files" || true
  git push
  cd -
done
