#!/bin/bash

# Configre PKI for Ziti Controller(s) inside the Docker container

ZITI_PKI_ROOT='pki'
ZITI_CA_FILE='root'
ZITI_INTERMEDIATE_FILE="ziti-controller-1"
ZITI_SERVER_FILE=server
ZITI_CLIENT_FILE=client

ziti pki create ca \
  --pki-root "${ZITI_HOME}/${ZITI_PKI_ROOT}" \
  --trust-domain ${ZITI_CONTROLLERS_FQDN} \
  --ca-file "${ZITI_CA_FILE}" \
  --ca-name "${ZITI_CONTROLLERS_FQDN} Trust Root"

ziti pki create intermediate \
  --pki-root "${ZITI_HOME}/${ZITI_PKI_ROOT}" \
  --ca-name "${ZITI_CA_FILE}" \
  --intermediate-file "${ZITI_INTERMEDIATE_FILE}" \
  --intermediate-name 'ziti-controller-1 Signing Cert'

ziti pki create key \
  --pki-root "${ZITI_HOME}/${ZITI_PKI_ROOT}" \
  --ca-name "${ZITI_INTERMEDIATE_FILE}" \
  --key-file "${ZITI_SERVER_FILE}"

#ziti pki create server \
#  --pki-root "${ZITI_HOME}/${ZITI_PKI_ROOT}" \
#  --ca-name "${ZITI_INTERMEDIATE_FILE}" \
#  --key-file "${ZITI_SERVER_FILE}" \
#  --server-file "${ZITI_SERVER_FILE}" \
#  --dns "localhost,${ZITI_CONTROLLERS_FQDN},${ZITI_HOST_FQDN}" \
#  --ip "127.0.0.1,::1,${ZITI_INTERMEDIATE_FILE}" \
#  --server-name "${ZITI_INTERMEDIATE_FILE}" \
#  --spiffe-id "controller/${ZITI_INTERMEDIATE_FILE}" \
#  --allow-overwrite

ziti pki create server \
  --pki-root "${ZITI_HOME}/${ZITI_PKI_ROOT}" \
  --ca-name "${ZITI_INTERMEDIATE_FILE}" \
  --key-file "${ZITI_SERVER_FILE}" \
  --server-file "${ZITI_SERVER_FILE}" \
  --dns "localhost,${ZITI_CONTROLLERS_FQDN},${ZITI_HOST_FQDN}" \
  --ip "127.0.0.1,::1,${ZITI_INTERMEDIATE_FILE}" \
  --server-name "${ZITI_INTERMEDIATE_FILE}" \
  --spiffe-id "controller/${ZITI_INTERMEDIATE_FILE}" \
  --allow-overwrite

ziti pki create client \
  --pki-root "${ZITI_HOME}/${ZITI_PKI_ROOT}" \
  --ca-name "${ZITI_INTERMEDIATE_FILE}" \
  --client-name "${ZITI_INTERMEDIATE_FILE}" \
  --key-file "${ZITI_SERVER_FILE}" \
  --client-file "${ZITI_CLIENT_FILE}" \
  --spiffe-id "controller/${ZITI_INTERMEDIATE_FILE}" \
  --allow-overwrite

if [[ ${ZITI_TOTAL_CONTROLLERS} -gt 1 ]]; then
  # Start incrementing from 2 because PKI for ziti-controller-1 is already created above.
  CTRL_ID=2
  for i in $(seq ${CTRL_ID} ${ZITI_TOTAL_CONTROLLERS}); do
    CTRL_ID=$i
    ziti pki create intermediate \
      --pki-root "${ZITI_HOME}/${ZITI_PKI_ROOT}" \
      --ca-name "${ZITI_CA_FILE}" \
      --intermediate-file ziti-controller-${CTRL_ID} \
      --intermediate-name "controller${CTRL_ID} Signing Cert"

    ziti pki create server \
      --pki-root "${ZITI_HOME}/${ZITI_PKI_ROOT}" \
      --ca-name ziti-controller-${CTRL_ID} \
      --dns "localhost,${ZITI_CONTROLLERS_FQDN},ziti-controller-${CTRL_ID}.${ZITI_INFRASTRUCTURE_DOMAIN}" \
      --ip "127.0.0.1,::1" \
      --server-name ziti-controller-${CTRL_ID} \
      --spiffe-id "controller/ziti-controller-${CTRL_ID}"

    ziti pki create client \
      --pki-root "${ZITI_HOME}/${ZITI_PKI_ROOT}" \
      --ca-name ziti-controller-${CTRL_ID} \
      --client-name ziti-controller-${CTRL_ID} \
      --spiffe-id "controller/ziti-controller-${CTRL_ID}"
  done
fi


apt-get install -y apache2
# For now, serve the PKI assets to other ziti controllers on port 80
tee /etc/apache2/sites-available/pki.conf &>/dev/null <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@hostname.com

    DocumentRoot /var/www
        <Directory /var/www/>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
rm -R /var/www/html
/usr/sbin/a2dissite 000-default
/usr/sbin/a2ensite pki
systemctl enable --now apache2
systemctl reload apache2
cp -r /var/lib/private/ziti-controller/pki/ /var/www/pki/
chmod -R 0777 /var/www/pki/