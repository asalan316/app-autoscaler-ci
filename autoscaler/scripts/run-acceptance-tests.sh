#!/bin/bash

set -euo pipefail

VAR_DIR=bbl-state/bbl-state/vars
pushd bbl-state/bbl-state
  eval "$(bbl print-env)"
popd

cf api https://api.${SYSTEM_DOMAIN} --skip-ssl-validation

CF_ADMIN_PASSWORD=$(credhub get -n /bosh-autoscaler/cf/cf_admin_password -q)
cf auth admin $CF_ADMIN_PASSWORD

set +e
SERVICE_BROKER_EXISTS=$(cf service-brokers | grep -c autoscalerservicebroker.${SYSTEM_DOMAIN}) 
set -e
if [[ $SERVICE_BROKER_EXISTS == 1 ]]; then
  echo "Service Broker already exists, assuming this is ok..."
  #cf delete-service-broker -f autoscaler
else
  echo "Creating service broker..."
  AUTOSCALER_SERVICE_BROKER_PASSWORD=$(credhub get  -n /bosh-autoscaler/app-autoscaler/autoscaler_service_broker_password -q)
  cf create-service-broker autoscaler autoscaler_service_broker_user $AUTOSCALER_SERVICE_BROKER_PASSWORD https://autoscalerservicebroker.${SYSTEM_DOMAIN}
fi

#cf enable-service-access autoscaler

export GOPATH=$PWD/app-autoscaler-release
pushd app-autoscaler-release/src/acceptance
cat > acceptance_config.json <<EOF
{
  "api": "api.${SYSTEM_DOMAIN}",
  "admin_user": "admin",
  "admin_password": "${CF_ADMIN_PASSWORD}",
  "apps_domain": "${SYSTEM_DOMAIN}",
  "skip_ssl_validation": ${SKIP_SSL_VALIDATION},
  "use_http": false,

  "service_name": "autoscaler",
  "service_plan": "autoscaler-free-plan",
  "aggregate_interval": 120,

  "autoscaler_api": "autoscaler.${SYSTEM_DOMAIN}",
  "service_offering_enabled": ${SERVICE_OFFERING_ENABLED}
}
EOF

#cat acceptance_config.json

CONFIG=$PWD/acceptance_config.json ./bin/test -race -nodes=3 -slowSpecThreshold=120 -trace api app broker

popd
