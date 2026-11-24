# Appcircle _Activate SSH Private Key_ component

This step sets up your SSH key in the build machine if you used one to connect your repository. This allows the build machine to connect to your private repository using your SSH key.

## Input Variables

### Required

- `AC_REPOSITORY_SSH_KEY`: SSH private key in RSA format.

## Output Variables

- `SSH_AUTH_SOCK`: It contains the path of the unix file socket that the SSH agent uses for communication with other processes.

## Relationship

Below workflow steps are related with this step and should be used as recommended.

### Required Steps

There is no required step that needs to be run beforehand for this step to work as expected.

### Preceding Steps

There is no preceding step advised to be run beforehand for this step to work as expected.

### Following Steps

Below are the steps that should be run afterwards if they are used in the workflow with this step.

- [Appcircle Git Clone](https://github.com/appcircleio/appcircle-git-clone-component.git)

## Running tests

Requires [bats-core](https://github.com/bats-core/bats-core) (`brew install bats-core` or `npm install -g bats`). The tests run `main.sh` with a temporary `HOME` and stub `ssh-agent` / `ssh-add`, so your own `~/.ssh` and the real SSH tools are never touched.

```bash
bats test/
```
