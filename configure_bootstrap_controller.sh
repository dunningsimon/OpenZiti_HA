#!/bin/bash

# Configure policies, services, identites on the main "bootstrap" Controller

ZITI_ID_DIR="${ZITI_HOME}/identities"

mkdir -pm0755 ${ZITI_ID_DIR}

# Set up policies, services, etc.
# Always login to the first controller due to this feature not being implemented... https://openziti.discourse.group/t/ha-implementation-questions/4021/4?u=farmhouse
ziti edge login -u ${ZITI_USER} -p ${ZITI_PWD} ziti-controller-1.${ZITI_INFRASTRUCTURE_DOMAIN}:${ZITI_CONTROLLERS_API_LISTEN_PORT} --yes

ziti edge create service-edge-router-policy all --service-roles '#all' --edge-router-roles '#all'
ziti edge create edge-router-policy all --edge-router-roles '#all' --identity-roles '#all'

ziti edge create config lifeboat.ssh.cfg.intercept intercept.v1 "{
    \"addresses\": [\"*.${ZITI_IDENTITY_DOMAIN}\"],
    \"protocols\": [\"tcp\"],
    \"portRanges\": [{\"low\":22,\"high\":22}],
    \"dialOptions\": {\"identity\": \"\$dst_hostname\"}
}"

ziti edge create config lifeboat.ssh.cfg.host host.v1 '{
    "address": "127.0.0.1",
    "protocol": "tcp",
    "port": 22,
    "listenOptions": { "identity": "$tunneler_id.name" }
}'

ziti edge create service lifeboat.ssh \
  --configs lifeboat.ssh.cfg.intercept,lifeboat.ssh.cfg.host \
  --role-attributes admin,ssh

ziti edge create service-policy lifeboat.ssh.dial Dial --identity-roles "#lifeboat,#admin" --service-roles "@lifeboat.ssh"
ziti edge create service-policy lifeboat.ssh.bind Bind --identity-roles "#lifeboat,#ssh" --service-roles "@lifeboat.ssh"

# Create "identities"
# Create Admin user identities.
if [[ ! -z ${ZITI_DEMO_ADMIN_USERS} ]]; then
  for user in ${ZITI_DEMO_ADMIN_USERS}; do
    ziti edge create identity "${user}.${ZITI_IDENTITY_DOMAIN}" --role-attributes lifeboat,admin,ssh -o "${ZITI_ID_DIR}/${user}.${ZITI_IDENTITY_DOMAIN}.jwt"
  done
fi

# Create device user identities.
if [[ ! -z ${ZITI_DEMO_DEVICE_USERS} ]]; then
  for user in ${ZITI_DEMO_DEVICE_USERS}; do
    ziti edge create identity "${user}.${ZITI_IDENTITY_DOMAIN}" --role-attributes ssh -o "${ZITI_ID_DIR}/${user}.${ZITI_IDENTITY_DOMAIN}.jwt"
  done
fi
