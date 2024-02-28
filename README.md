# Appcircle _Activate SSH Private Key_ component

This step sets up your SSH key in the build machine if you used one to connect your repository. This allows the build machine to connect to your private repository using your SSH key.

## Input Variables

### Required

- `AC_REPOSITORY_SSH_KEY`: SSH private key in RSA format.

## Output Variables

- `SSH_AUTH_SOCK`: SSH Auth Sock. The path of the SSH Auth Socket.

## Relationship

Below workflow steps are related with this step and should be used as recommended.

### Required Steps

There is no required step that needs to be run beforehand for this step to work as expected.

### Preceding Steps

There is no preceding step advised to be run beforehand for this step to work as expected.

### Following Steps

Below are the steps that should be run afterwards if they are used in the workflow with this step.
- [Appcircle Git Clone](https://github.com/appcircleio/appcircle-git-clone-component.git)
