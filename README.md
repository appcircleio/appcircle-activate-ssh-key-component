# Appcircle Activate SSH Key

This step sets up your SSH key in the build machine if you used one to connect your repository. This allows the build machine to connect to your private repository using your SSH key.

Required Input Variables
- `$AC_REPOSITORY_SSH_KEY`: SSH private key to be used in RSA format.

Output Variables
- `$SSH_AUTH_SOCK`: The path of the SSH Auth Socket
