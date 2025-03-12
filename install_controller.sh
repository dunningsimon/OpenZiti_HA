#!/bin/bash

# Install and configure an additinal (non bootstrap) Ziti controller.

# Install the OpenZiti packages
source ./install_ziti_controller_package.sh

# Wait for controller 1 to be initialised
source ./wait_for_bootstrap.sh

# Construct the FQDN for this Controller

ZITI_HOST_SUBDOMAIN=${HOSTNAME}
ZITI_HOST_FQDN="${ZITI_HOST_SUBDOMAIN}.${ZITI_INFRASTRUCTURE_DOMAIN}"

# Create ZITI_HOME dir
mkdir -pm0700 ${ZITI_HOME}

# Temp process for now just to simply get the PKI assets
# Wget PKI assets from the boostrap controller. 
mkdir -p "${ZITI_HOME}/pki/${ZITI_HOST_SUBDOMAIN}/certs"
mkdir -p "${ZITI_HOME}/pki/${ZITI_HOST_SUBDOMAIN}/keys"
wget "http://ziti-controller-1.${ZITI_INFRASTRUCTURE_DOMAIN}/pki/${ZITI_HOST_SUBDOMAIN}/certs/server.chain.pem" -O "${ZITI_HOME}/pki/${ZITI_HOST_SUBDOMAIN}/certs/server.chain.pem"
wget "http://ziti-controller-1.${ZITI_INFRASTRUCTURE_DOMAIN}/pki/${ZITI_HOST_SUBDOMAIN}/keys/server.key" -O "${ZITI_HOME}/pki/${ZITI_HOST_SUBDOMAIN}/keys/server.key"
wget "http://ziti-controller-1.${ZITI_INFRASTRUCTURE_DOMAIN}/pki/${ZITI_HOST_SUBDOMAIN}/certs/${ZITI_HOST_SUBDOMAIN}.chain.pem" -O "${ZITI_HOME}/pki/${ZITI_HOST_SUBDOMAIN}/certs/${ZITI_HOST_SUBDOMAIN}.chain.pem"
wget "http://ziti-controller-1.${ZITI_INFRASTRUCTURE_DOMAIN}/pki/${ZITI_HOST_SUBDOMAIN}/certs/${ZITI_HOST_SUBDOMAIN}.cert" -O "${ZITI_HOME}/pki/${ZITI_HOST_SUBDOMAIN}/certs/${ZITI_HOST_SUBDOMAIN}.cert"
wget "http://ziti-controller-1.${ZITI_INFRASTRUCTURE_DOMAIN}/pki/${ZITI_HOST_SUBDOMAIN}/keys/${ZITI_HOST_SUBDOMAIN}.key" -O "${ZITI_HOME}/pki/${ZITI_HOST_SUBDOMAIN}/keys/${ZITI_HOST_SUBDOMAIN}.key"

# Write the ${ZITI_HOST_SUBDOMAIN} conf file
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

# Run the controller
systemctl start ziti-controller.service

sleep 10

echo "Adding to cluster: ${ZITI_HOST_SUBDOMAIN}"
systemctl show -p MainPID --value ziti-controller.service | xargs -rIPID sudo nsenter --target PID --mount --  ziti agent cluster add "tls:ziti-controller-1.${ZITI_INFRASTRUCTURE_DOMAIN}:${ZITI_CONTROLLERS_LISTEN_PORT}"

sleep 5

echo "listing cluster:"
systemctl show -p MainPID --value ziti-controller.service | xargs -rIPID sudo nsenter --target PID --mount --  ziti agent cluster list

echo "logging in......"
ziti edge login -u ${ZITI_USER} -p ${ZITI_PWD} ziti-controller-1.${ZITI_INFRASTRUCTURE_DOMAIN}:${ZITI_CONTROLLERS_API_LISTEN_PORT} --yes
