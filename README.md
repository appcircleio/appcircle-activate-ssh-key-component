# Appcircle _Activate SSH Private Key_ component

This step sets up your SSH key in the build machine if you used one to connect your repository. This allows the build machine to connect to your private repository using your SSH key.

## Required Inputs

- `AC_REPOSITORY_SSH_KEY`: SSH private key in RSA format.

## Output Variables

- `SSH_AUTH_SOCK`: SSH Auth Sock. The path of the SSH Auth Socket.

## Required Steps

- There is no required step that needs to be run afterward for this step to work as expected.

## Preceding Steps

- There is no preceding step advised to be run beforehand for this step to work as expected.

## Following Steps

-  Git Clone
