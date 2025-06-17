#!/bin/sh

set -e
set -x

if [ -z "$INPUT_SOURCE_FILE" ]
then
  echo "Source file must be defined"
  return -1
fi

if [ -z "$INPUT_DESTINATION_BRANCH" ]
then
  INPUT_DESTINATION_BRANCH=main
fi
OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH"

CLONE_DIR=$(mktemp -d)

echo "Cloning destination git repository"
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"


rc=1
if [ ! -z "$INPUT_DESTINATION_BRANCH_CREATE" ]
then
  if [[ "$API_TOKEN_GITHUB" != "" ]]; then
    set +e
    git clone --single-branch --branch $INPUT_DESTINATION_BRANCH_CREATE "https://x-access-token:$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"
    rc=$?
    set -e
  else
    echo "$SSH_KEY_GITHUB" > /tmp/ssh.key
    chmod 0600 /tmp/ssh.key
    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i /tmp/ssh.key" 
    set +e
    git clone --single-branch --branch $INPUT_DESTINATION_BRANCH_CREATE "git@github.com:$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"
    rc=$?
    set -e
  fi
fi

if [[ "$rc" != "0" ]]; then
  if [[ "$API_TOKEN_GITHUB" != "" ]]; then
    git clone --single-branch --branch $INPUT_DESTINATION_BRANCH "https://x-access-token:$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"
  else
    echo "$SSH_KEY_GITHUB" > /tmp/ssh.key
    chmod 0600 /tmp/ssh.key
    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i /tmp/ssh.key" 
    git clone --single-branch --branch $INPUT_DESTINATION_BRANCH "git@github.com:$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"
  fi
fi

echo "Copying contents to git repo"
mkdir -p "$CLONE_DIR"/"$INPUT_DESTINATION_FOLDER"

if [ ! -z "$INPUT_RENAME" ]
then
  cp -R "$INPUT_SOURCE_FILE" "$CLONE_DIR/$INPUT_DESTINATION_FOLDER/$INPUT_RENAME"
else
  cp -R "$INPUT_SOURCE_FILE" "$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
fi
cd "$CLONE_DIR"


if [ ! -z "$INPUT_DESTINATION_BRANCH_CREATE" ]
then
  git checkout -b "$INPUT_DESTINATION_BRANCH_CREATE" || true
  git checkout "$INPUT_DESTINATION_BRANCH_CREATE"
  OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH_CREATE"
fi

if [ -z "$INPUT_COMMIT_MESSAGE" ]
then
  INPUT_COMMIT_MESSAGE="Update from https://github.com/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}"
fi

echo "Adding git commit"
git add .
if git status | grep -q "Changes to be committed"
then
  git commit --message "$INPUT_COMMIT_MESSAGE"
  echo "Checking for pull"

  set +e
  for i in {1..5}; do
    git pull origin $OUTPUT_BRANCH || true
    echo "Pushing git commit"
    git push -u origin HEAD:$OUTPUT_BRANCH  
    if [ $? -eq 0 ]; then
      set +e
      break
    fi
    if [ $i -eq 5 ]; then
      echo "Failed to push changes to the destination repository"
      exit 1
    fi
    sleep 1
  done
else
  echo "No changes detected"
fi
