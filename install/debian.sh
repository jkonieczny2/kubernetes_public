# Ensure keyrings dir exists
mkdir -p /etc/apt/keyrings

# Download public key
GPG_FILE="/etc/apt/keyrings/salt-archive-keyring.pgp"

if [ ! -f ${GPG_FILE} ]; then
    echo "Installing gpg file ${GPG_FILE}"
    curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public | sudo tee ${GPG_FILE}
fi

# Create apt repo target configuration
SOURCES_FILE="/etc/apt/sources.list.d/salt.sources"

if [ ! -f ${SOURCES_FILE} ]; then
    echo "Installing sources file ${SOURCES_FILE}"
    curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.sources | sudo tee ${SOURCES_FILE}
fi

# update apt
echo "Updating apt"
sudo apt update

# install various debian packages; for now just getting salt-ssh
echo "Installing salt-ssh"
sudo apt-get install salt-ssh
