#!/usr/bin/env bash
set -x

# Initialization
DEFAULT_CONTAINER_EXECUTABLE="docker"
CONTAINER_CLIENT="${CONTAINER_EXECUTABLE:-$DEFAULT_CONTAINER_EXECUTABLE}"
CERT_EXE_UBUNTU=update-ca-certificates
CERT_EXE_REDHAT=update-ca-trust
HOSTNAME=cnftest-local.redhat.com
echo "$(which $CERT_EXE_UBUNTU 2>/dev/null)"]
if [[ -n "$(which $CERT_EXE_UBUNTU 2>/dev/null)" ]];
then
  echo "Running on Ubuntu Linux"
  CERT_UPDATER=$CERT_EXE_UBUNTU
  CERT_PATH=/usr/local/share/ca-certificates/$HOSTNAME.crt

elif [[ -n "$(which $CERT_EXE_REDHAT 2>/dev/null)" ]];
then
  echo "Running on Redhat/Fedora Linux"
  CERT_UPDATER=$CERT_EXE_REDHAT
  CERT_PATH=/etc/pki/ca-trust/source/anchors/$HOSTNAME.crt

else
  echo "OS unknown, don't know how to update certificates"
  exit 1
fi

# Create certificates for registry authentication
rm -rf certs
mkdir certs
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes  -keyout certs/registry.key -out certs/registry.crt -subj "/CN=registry"  -addext "subjectAltName=DNS:${HOSTNAME},IP:127.0.0.1"
openssl x509 -in certs/registry.crt -out certs/registry.pem -outform PEM
chmod 666 certs/*


# Enable the new certificates for use in the current host
sudo cp certs/registry.crt  $CERT_PATH
sudo $CERT_UPDATER

# Add the hostname to /etc/hosts
if [ -z $( grep "$HOSTNAME" /etc/hosts) ]
then
  REGISTRY_ADDRESS=$(hostname -I|awk '{print $1}')
  echo REGISTRY_ADDRESS= $REGISTRY_ADDRESS 
  sudo REGISTRY_ADDRESS1="$REGISTRY_ADDRESS" sh -c 'echo "$REGISTRY_ADDRESS1 ${HOSTNAME}" >> /etc/hosts'
else 
  echo "entry already present"
fi
cat /etc/hosts


# Get hostname to have a host-wide reacheable address
HOSTNAME=$(hostname)
${CONTAINER_CLIENT} rm -f registry

# Create secret (must be named cert.pem)
cp certs/registry.pem certs/cert.pem
oc create secret generic foo-cert-sec --from-file=certs/cert.pem  -n $TNF_PARTNER_NAMESPACE

# Remove the docker registry 
${CONTAINER_CLIENT} rm -f registry

# Create the docker registry
${CONTAINER_CLIENT} run -d \
  --restart=always \
  --name registry \
  -v $(pwd)/certs:/certs:Z \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  -p 443:443 \
  registry:2

echo "Created local registry at: ${HOSTNAME}:443"