#!/bin/bash

# Initialize a ziti-router

# Install the Ziti router package
source ./install_ziti_router_package.sh

# Wait for controller 1 to be initialised
source ./wait_for_bootstrap.sh

# Create ZITI_HOME dir
mkdir -pm0700 ${ZITI_HOME}

ZITI_HOST_SUBDOMAIN="${HOSTNAME}" # Should be ziti-router-x

ZITI_HOST_FQDN="${ZITI_HOST_SUBDOMAIN}.${ZITI_INFRASTRUCTURE_DOMAIN}" # E.G router.x.example.com

# Create a random string to use in the router name
RANDOM_STRING=$(tr -dc 'a-z' < /dev/urandom | head -c 5)

# Login to the controller
echo "logging in......"
ziti edge login -u ${ZITI_USER} -p ${ZITI_PWD} ziti-controller-1.${ZITI_INFRASTRUCTURE_DOMAIN}:${ZITI_CONTROLLERS_API_LISTEN_PORT} --yes

# Create an edge-router
echo "ziti edge create router......"
ziti edge create edge-router "edge-router-${RANDOM_STRING}" --jwt-output-file "${ZITI_HOME}/edge-router-${RANDOM_STRING}.jwt" --tunneler-enabled

tee ${ZITI_HOME}/config.yml &> /dev/null << EOF
v: 3

identity:
  cert:             "${ZITI_HOME}/router.cert"
  server_cert:      "${ZITI_HOME}/router.server.chain.cert"
  key:              "${ZITI_HOME}/router.key"
  ca:               "${ZITI_HOME}/router.cas"

ha:
  enabled: true

ctrl:
  endpoint:             tls:${ZITI_CONTROLLERS_FQDN}:${ZITI_CONTROLLERS_LISTEN_PORT}

link:
  dialers:
    - binding: transport
  listeners:
    - binding:          transport
      bind:             tls:0.0.0.0:${ZITI_ROUTER_LINK_LISTEN_PORT}
      advertise:        tls:${ZITI_HOST_FQDN}:${ZITI_ROUTER_LINK_LISTEN_PORT}
      options:
        outQueueSize:   4

listeners:
# bindings of edge and tunnel requires an "edge" section below
  - binding: edge
    address: tls:0.0.0.0:${ZITI_ROUTER_EDGE_LISTEN_PORT}
    options:
      advertise: ${ZITI_ROUTERS_FQDN}:${ZITI_ROUTER_EDGE_LISTEN_PORT}
      connectTimeoutMs: 5000
      getSessionTimeout: 60
  - binding: tunnel
    options:
      mode: host #tproxy|host

edge:
  csr:
    country: US
    province: NC
    locality: Charlotte
    organization: NetFoundry
    organizationalUnit: Ziti
    sans:
      dns:
        - localhost
        - ${ZITI_HOST_FQDN}
        - ${ZITI_ROUTERS_FQDN}
        - $(hostname)
      ip:
        - "127.0.0.1"
        - "::1"

#transport:
#  ws:
#    writeTimeout: 10
#    readTimeout: 5
#    idleTimeout: 120
#    pongTimeout: 60
#    pingInterval: 54
#    handshakeTimeout: 10
#    readBufferSize: 4096
#    writeBufferSize: 4096
#    enableCompression: true

forwarder:
  latencyProbeInterval: 0
  xgressDialQueueLength: 1000
  xgressDialWorkerCount: 128
  linkDialQueueLength: 1000
  linkDialWorkerCount: 32

EOF

# Enroll the router. For some reason it dumps router.cert into PWD not ZITI_HOME
echo "enrolling......"
(
  cd ${ZITI_HOME} && ziti router enroll ${ZITI_HOME}/config.yml --jwt "${ZITI_HOME}/edge-router-${RANDOM_STRING}.jwt"
)

systemctl start ziti-router.service

sleep 5

ziti edge list edge-routers
