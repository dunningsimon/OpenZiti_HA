#!/bin/bash

#!/bin/bash

# Bootstrap script to be run by Ziti Controller in a Docker container.

# Install the OpenZiti packages
source ./install_ziti_controller_package.sh

# Construct the FQDN for this Controller

ZITI_HOST_SUBDOMAIN=${HOSTNAME}
ZITI_HOST_FQDN="${ZITI_HOST_SUBDOMAIN}.${ZITI_INFRASTRUCTURE_DOMAIN}"

# Create ZITI_HOME dir
mkdir -pm0700 ${ZITI_HOME}

# Run PKI creation script
source ./install_pki.sh

# Write the config file
tee ${ZITI_HOME}/config.yml &> /dev/null << EOF
v: 3

cluster:
  dataDir: ./data/${ZITI_HOST_SUBDOMAIN}

identity:
  cert: ./pki/${ZITI_HOST_SUBDOMAIN}/certs/server.chain.pem
  key: ./pki/${ZITI_HOST_SUBDOMAIN}/keys/server.key
  ca: ./pki/${ZITI_HOST_SUBDOMAIN}/certs/${ZITI_HOST_SUBDOMAIN}.chain.pem

ctrl:
  listener: tls:0.0.0.0:${ZITI_CONTROLLERS_LISTEN_PORT}
  options:
    advertiseAddress: tls:${ZITI_HOST_FQDN}:${ZITI_CONTROLLERS_LISTEN_PORT}

events:
  jsonLogger:
    subscriptions:
      - type: connect
      - type: cluster
    handler:
      type: file
      format: json
      path: /tmp/ziti-events.log

edge:
  api:
    address: ${ZITI_CONTROLLERS_FQDN}:${ZITI_CONTROLLERS_API_LISTEN_PORT}
  enrollment:
    signingCert:
      cert: ./pki/${ZITI_HOST_SUBDOMAIN}/certs/${ZITI_HOST_SUBDOMAIN}.cert
      key: ./pki/${ZITI_HOST_SUBDOMAIN}/keys/${ZITI_HOST_SUBDOMAIN}.key
    edgeIdentity:
      duration: 600m
    edgeRouter:
      duration: 10m

web:
  - name: all-apis-localhost
    bindPoints:
      - interface: 0.0.0.0:${ZITI_CONTROLLERS_API_LISTEN_PORT}
        address: ${ZITI_CONTROLLERS_FQDN}:${ZITI_CONTROLLERS_API_LISTEN_PORT}
    options:
      minTLSVersion: TLS1.2
      maxTLSVersion: TLS1.3
    apis:
      - binding: health-checks
      - binding: fabric
      - binding: edge-management
      - binding: edge-client
      - binding: edge-oidc
      - binding: zac
        options:
          location: /opt/openziti/share/console
          indexFile: index.html

EOF

cat ${ZITI_HOME}/config.yml

# Run the controller
systemctl start ziti-controller.service

sleep 10

echo "Initialising cluster: ${ZITI_HOST_SUBDOMAIN}"
systemctl show -p MainPID --value ziti-controller.service | xargs -rIPID sudo nsenter --target PID --mount -- ziti agent cluster init -i ${ZITI_HOST_SUBDOMAIN} ${ZITI_USER} ${ZITI_PWD} 'Default Admin'

sleep 5

echo "Listing cluster"
systemctl show -p MainPID --value ziti-controller.service | xargs -rIPID sudo nsenter --target PID --mount -- ziti agent cluster list

# Now configure the controller with policies, services, demo ID's etc.
source ./configure_bootstrap_controller.sh
