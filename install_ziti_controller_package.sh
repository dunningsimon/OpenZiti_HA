#!/bin/bash

# Script to install OpenZiti Controller packages on a Debian based VM.

# Use the one liner to set APT sources/keys up.
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" --allow-downgrades --allow-remove-essential --allow-change-held-packages -fuy dist-upgrade
apt-get install -y gnupg curl wget
rm -f /usr/share/keyrings/openziti.gpg
curl -sSLf https://get.openziti.io/tun/package-repos.gpg | gpg --dearmor --output /usr/share/keyrings/openziti.gpg
chmod a+r /usr/share/keyrings/openziti.gpg
# Configure APT to use the zitipax-openziti-deb-test repository as we need the latest HA features
echo "deb [signed-by=/usr/share/keyrings/openziti.gpg] https://packages.openziti.org/zitipax-openziti-deb-test debian main" > /etc/apt/sources.list.d/openziti-release.list
apt-get update
# Install OpenZiti packages
apt-get install -y openziti=${ZITI_CLI_DEB_VER} openziti-controller=${ZITI_CONTROLLER_DEB_VER} openziti-console --allow-downgrades
tee /etc/systemd/system/ziti-controller.service.d/override.conf &> /dev/null << EOF
[Service]
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStartPre=
ExecStart=
ExecStart=/opt/openziti/bin/ziti controller run config.yml
EOF

systemctl daemon-reload

systemctl enable ziti-controller.service
