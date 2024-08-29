#!/bin/bash

####
# Bootstrap script for initializing a fresh Amazon Linux 2 Workspace.
#
# The source for this script can be found in the GitHub repo:
# https://github.com/AlightEngineering/dx-vms
# under the folder AwsWorkspaceAL2/al2-image-bootstrap.
####

function echoColor {
  GREEN='\033[0;32m'
  echo -e "{GREEN} $1"
}

set -x

echoColor "Starting bootstrap script at $(date '+%Y-%m-%d %H:%M:%S')."

# Clear and reload cache for repos
echo "Clearing and reloading cache for repos."
yum clean all
yum makecache
echo "Cache cleared and reloaded successfully."

echo "Installing base libraries."
yum install -y gcc gettext-devel openssl11 openssl11-devel perl-CPAN perl-devel zlib-devel curl-devel autoconf expat-devel yum-utils
echo "Base libraries installed successfully."

# Need to install certificates for GitHub CLI to not complain about SSL when authenticating
wget --no-check-certificate https://artifactory.alight.com:443/artifactory/devops-generic-local/aws-linux-vdi/certificates/Alight-Root-CAs.pem -O /etc/pki/ca-trust/source/anchors/Alight-Root-CAs.pem
wget --no-check-certificate https://artifactory.alight.com:443/artifactory/devops-generic-local/aws-linux-vdi/certificates/zscaler-root.pem.cer -O /etc/pki/ca-trust/source/anchors/Zscaler-Root-CAs.pem
/bin/update-ca-trust

# Install Git
yum erase -y git

if ! command -v git &> /dev/null; then
  echo "Installing Git."
  wget --no-check-certificate https://artifactory.alight.com:443/artifactory/devops-generic-local/aws-linux-vdi/git/git-2.45.2.tar.gz -O /tmp/git.tar.gz
  mkdir -p /tmp/git
  tar -C /tmp/git -zvxf /tmp/git.tar.gz --strip-components=1
  make --directory=/tmp/git prefix=/usr/local install
  rm -rf /tmp/git.tar.gz /tmp/git
  git --version
  git config --global http.sslVerify false
  echo "Please enter your Git user email address:"
  read -r git_email
  git config --global user.email "$git_email"
  echo "Git user email configured as: $git_email"
  echo "Please enter your Git user full name:"
  read -r git_name
  git config --global user.name "$git_name"
  echo "Git user full name configured as: $git_name"
  echo "Git is successfully installed!"
else
  echo "Git is already installed. Version: $(git --version)"
fi

# Install GitHub CLI
if ! command -v gh &> /dev/null; then
  echo "Installing the GitHub CLI."
  # Configure the GitHub CLI repository
  wget --no-check-certificate https://artifactory.alight.com:443/artifactory/devops-generic-local/aws-linux-vdi/github/gh_cli_2.53.0_linux_amd64.rpm -O /tmp/github-cli.rpm
  yum install -y /tmp/github-cli.rpm
  echo "GitHub CLI installed successfully."
  rm -f /tmp/github-cli.rpm
  echo "Authenticating GitHub CLI."
  gh auth login --web
  echo "GitHub CLI authenticated successfully."
else
  echo "GitHub CLI is already installed. Version: $(gh --version)"
fi

# Clone the dx-vms repository
echo "Cloning the dx-vms repository."
rm -rf /tmp/dx-vms
gh repo clone AlightEngineering/dx-vms /tmp/dx-vms
echo "The dx-vms repository cloned successfully to /tmp/dx-vms."

while true; do
  echo "Do you wish to install developer tooling (yes/no)?"
  read -r yn
  case $yn in
      [Yy]* ) echo "Installing developer tooling."; chmod +x /tmp/dx-vms/AwsWorkspaceAL2/scripts/*; /tmp/dx-vms/AwsWorkspaceAL2/scripts/install-developer-tooling.sh; rm -rf /tmp/dx-vms; break;;
      [Nn]* ) echo "Skipping developer tooling installation."; break;;
      * ) echo "Please answer yes (Y/y) or no (N/n).";;
  esac
done

echo "Bootstrap script completed at $(date '+%Y-%m-%d %H:%M:%S')."