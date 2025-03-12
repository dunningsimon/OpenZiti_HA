#!/bin/bash

# Temporary workaround for this issue. https://openziti.discourse.group/t/ha-implementation-questions/4021/3
# Ensure that enrolment traffic always hits ziti-controller-1 by modifying /etc/hosts

# Run script once to create /etc/hosts entry
# Run script again to remove /etc/hosts entry

apt-get update 
apt-get install -y dnsutils

# Get the IP address of ziti-controller-1
ZITI_CTRL1_FQDN="ziti-controller-1.${ZITI_INFRASTRUCTURE_DOMAIN}"
HOSTS_FILE="/etc/hosts"

# Resolve IP address of ZITI_CTRL1_FQDN
IP=$(dig +short "$ZITI_CTRL1_FQDN" | head -n 1)
if [[ -z "$IP" ]]; then
  echo "Error: Could not resolve IP address for $ZITI_CTRL1_FQDN."
  exit 1
fi

if ! grep -q "${ZITI_CONTROLLERS_FQDN}" $HOSTS_FILE; then
  echo "Adding entry: $IP $ZITI_CONTROLLERS_FQDN"
  echo "$IP $ZITI_CONTROLLERS_FQDN" | tee -a "$HOSTS_FILE" > /dev/null
else
  # Remove existing entry if it exists
  sed -i "/$ZITI_CONTROLLERS_FQDN/d" "$HOSTS_FILE"
  echo "Removed entry for $ZITI_CONTROLLERS_FQDN."
fi


echo "/etc/hosts"
cat /etc/hosts