#!/bin/bash
# Set GitHub Actions secrets on a repo from fastlane/.env
# Usage: ./scripts/set-secrets.sh org/repo-name

REPO=$1

if [ -z "$REPO" ]; then
  echo "Usage: ./scripts/set-secrets.sh org/repo-name"
  exit 1
fi

ENV_FILE="fastlane/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "Error: $ENV_FILE not found"
  exit 1
fi

# Read the .env on FD 3 and give gh its own stdin (</dev/null). Otherwise an
# empty VALUE makes `gh secret set --body ""` fall back to reading the secret
# from stdin — which is the redirected .env — silently swallowing the rest of
# the file so only the first secret ever gets set.
#
# Split on the FIRST '=' only, via parameter expansion. `IFS='=' read KEY VALUE`
# is wrong here: bash strips trailing IFS characters from the last field, which
# silently drops the '='/'==' padding off base64 values (ASC_KEY_CONTENT) and
# corrupts the secret — altool then rejects the key with error 259.
while IFS= read -r LINE <&3; do
  # skip empty lines, comments, and lines without '='
  [[ -z "$LINE" || "$LINE" == \#* || "$LINE" != *=* ]] && continue
  KEY="${LINE%%=*}"
  VALUE="${LINE#*=}"
  # skip empty values (e.g. a blank Jira field) rather than set an empty secret
  if [[ -z "$VALUE" ]]; then
    echo "skip $KEY (empty)"
    continue
  fi
  gh secret set "$KEY" --body "$VALUE" --repo "$REPO" </dev/null
  echo "OK $KEY set on $REPO"
done 3< "$ENV_FILE"

echo ""
echo "Done. Secrets set on $REPO from $ENV_FILE"
