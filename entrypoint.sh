#!/bin/bash

# For now, use the hostname to determine how we set up the VM.

# OpenZiti controllers will have hostnames ziti-controller-x
# OpenZiti Routers will have hostnames ziti-router-x

if [[ -f "${ZITI_HOME}/install_complete" ]]; then
  echo "Install already completed"
  exit 0
fi

HOSTNAME=$(hostname)

source ./config.env

if [[ "${HOSTNAME}" == "ziti-controller-1" ]]; then # Only the first Controller follows this path
  # Run the custom Controller Bootstrap process
  ZITI_HOME="/var/lib/private/ziti-controller"
  echo -e "\nInstalling ${HOSTNAME}"
  # Add temporary /etc/hosts entry see README
  source ./temp_route_to_ctrl1.sh
  source ./bootstrap_controller.sh
  # Remove temporary /etc/hosts entry
  source ./temp_route_to_ctrl1.sh
elif [[ "${HOSTNAME}" == "ziti-controller-"* ]]; then # All Controllers except the first follow this path
  ZITI_HOME="/var/lib/private/ziti-controller"
  # Run the controller install process to set it up as a non bootstrap controller
  echo -e "\nInstalling ${HOSTNAME}"
  # Add temporary /etc/hosts entry see README
  source ./temp_route_to_ctrl1.sh
  source ./install_controller.sh
  # Remove temporary /etc/hosts entry
  source ./temp_route_to_ctrl1.sh
elif [[ "${HOSTNAME}" == "ziti-router-"* ]]; then # All edge-routers follow this path
  ZITI_HOME="/var/lib/private/ziti-router"
  # Run the router install process
  echo -e "\nInstalling ${HOSTNAME}"
  # Add temporary /etc/hosts entry see README
  source ./temp_route_to_ctrl1.sh
  source ./install_router.sh
  # Remove temporary /etc/hosts entry
  source ./temp_route_to_ctrl1.sh
elif [[ "${HOSTNAME}" == "router" ]]; then # haproxy for routers
  # Run the haproxy router install process
  echo -e "\nInstalling ${HOSTNAME}"
  source ./haproxy_router_install.sh
elif [[ "${HOSTNAME}" == "controller" ]]; then # haproxy for controllers
  # Run the haproxy controller install process
  echo -e "\nInstalling ${HOSTNAME}"
  source ./haproxy_controller_install.sh
else
  echo "Error: ${HOSTNAME} is invalid. Exiting!"
  exit 1
fi

touch "${ZITI_HOME}/install_complete"
