#!/usr/bin/env bash

set -euo pipefail

echo "Installing all-contributors CLI..."
npm install --no-save all-contributors-cli

echo "Fetching commits for PR #${PR_NUMBER} from ${REPO}..."

gh api "repos/${REPO}/pulls/${PR_NUMBER}/commits" --paginate > pr_commits.json


echo "Extracting commit authors..."
AUTHOR_LOGINS=$(jq -r '.[].author.login // empty' pr_commits.json)


echo "Extracting co-authors from commit messages..."
COAUTHOR_LOGINS=$(
  jq -r '.[].commit.message // ""' pr_commits.json \
  | awk 'BEGIN{IGNORECASE=1} /^co-authored-by:/{print}' \
  | sed -nE 's/.*<([^>]+)>.*/\1/p' \
  | sed -E 's/^([0-9]+\+)?([^@]+)@users\.noreply\.github\.com$/\2/I' \
  | grep -v '@' || true
)


echo "Combining and deduplicating GitHub usernames..."

ALL_USERS=$(printf "%s\n%s\n" "$AUTHOR_LOGINS" "$COAUTHOR_LOGINS" \
  | sed '/^$/d' \
  | grep -viE '\[bot\]$' \
  | sort -u)


echo
echo "Users detected:"
echo "----------------"
echo "$ALL_USERS"
echo "----------------"
echo


echo "Adding contributors..."

while IFS= read -r user; do
  [ -z "$user" ] && continue

  echo "Adding contributor: $user"
  npx all-contributors add "$user" "${CONTRIBUTION_TYPE:-code}"

done <<< "$ALL_USERS"


echo "Regenerating contributors section..."
npx all-contributors generate


echo "Preparing commit..."

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"


git add .all-contributorsrc README.md


if git diff --cached --quiet -- .all-contributorsrc README.md; then
  echo "No contributor changes detected."
  exit 0
fi


echo "Committing contributor updates..."
# git commit -m "update contributors"


echo "Pushing changes to ${PR_BRANCH}..."
# git push origin "HEAD:${PR_BRANCH}"


echo "Contributor update completed."