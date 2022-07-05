#!/bin/bash
set -e

if [ -z "$AC_REPOSITORY_SSH_KEY" ]
then
echo "AC_REPOSITORY_SSH_KEY is not provided. Skipping step."
exit 0
fi

echo "Create a file to save the RSA SSH private key"
rm -rf ~/.ssh
mkdir -p ~/.ssh
echo "$AC_REPOSITORY_SSH_KEY" >> ~/.ssh/appcircle_ssh
chmod 600 ~/.ssh/appcircle_ssh

echo "Starting a new ssh-agent"
eval $(ssh-agent)

echo "Add the SSH private key to the ssh-agent"
ssh-add ~/.ssh/appcircle_ssh
echo -e "Host *\n    StrictHostKeyChecking no" >> ~/.ssh/config
chmod 400 ~/.ssh/config
echo "Exporting SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK" >> $AC_ENV_FILE_PATH