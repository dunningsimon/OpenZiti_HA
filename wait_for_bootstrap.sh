#!/bin/bash

# A script to wait for the bootstrap controller to be initialized.

ziti_controller_login() {
  echo "Attempting ziti-controller-1 Login..."
  ziti edge login -u ${ZITI_USER} -p ${ZITI_PWD} ziti-controller-1.${ZITI_INFRASTRUCTURE_DOMAIN}:${ZITI_CONTROLLERS_API_LISTEN_PORT} --yes > /dev/null 2>&1
}

echo "Waiting for ziti-controller-1 initialisation..."

count=0
max_attempts=30

until ziti_controller_login; do
  count=$((count + 1))
  if [ $count -ge $max_attempts ]; then
    echo "Maximum attempts reached. Exiting."
    exit 1
  fi
  sleep 10
done

sleep 10