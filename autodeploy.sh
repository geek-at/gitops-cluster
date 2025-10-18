#!/bin/sh

set -euo pipefail


REPO_DIR=$(dirname "$(realpath "$0")")  # path of this repo cloned on your controller node
REPO_REMOTE="origin"                    # git remote
REPO_BRANCH="main"                      # git branch
STACK_DIR="$REPO_DIR/stacks"            # path to your stack files ymls 
DEPLOY_LOG="/var/log/gitopscluster-last-deploy.log" # path to log file
LOCKFILE="/tmp/swarm-deploy.lock"       # lock file to avoid concurrent runs

send_notification() {
  local message="$1"
  # do what you want in this function. I use it to send it via Signal to myself
  # but you can do discord, slack, email, ...
}

# Avoid concurrent execution
exec 200>"$LOCKFILE"
flock -n 200 || exit 1

cd "$REPO_DIR"

# Fetch changes
git fetch "$REPO_REMOTE" "$REPO_BRANCH"
CHANGED_FILES=$(git diff --name-status HEAD.."$REPO_REMOTE"/"$REPO_BRANCH" -- "$STACK_DIR")

# Update repo
git pull "$REPO_REMOTE" "$REPO_BRANCH" >/dev/null

if [[ -z "$CHANGED_FILES" ]]; then
  echo "No changes."
  exit 0
fi

echo "Changes detected:"
echo "$CHANGED_FILES"

while read -r status file; do
  [[ -z "$file" ]] && continue
  stack_name=$(basename "$file" .yml)

  case "$status" in
    A|M)
      echo "Deploying $stack_name..."
      if ! docker stack deploy -c "$file" "$stack_name"; then
        send_notification "[ERR] Deployment failed for $stack_name"
        else
        send_notification "[OK] Successfully deployed $stack_name"
      fi
      ;;
    D)
      echo "Removing $stack_name..."
      if ! docker stack rm "$stack_name"; then
        send_notification "[ERR] Failed to remove stack $stack_name"
        else
        send_notification "[OK] Successfully removed $stack_name"
      fi
      ;;
  esac
done <<< "$CHANGED_FILES"

