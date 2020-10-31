#!/bin/bash
set -Eeuo pipefail

trap "echo Setup failed!" ERR

# Setup project application

if [[ $# -eq 0 ]]; then
    SCRIPT_NAME=`basename "$0"`
    echo "Usage:"
    echo "./$SCRIPT_NAME <environment-type> <target-namespace> <app-name> <config-map-mount-absolute-dir> <ocp-api-url> <ocp-service-token>"
    echo ""
    echo "Usage example:"
    echo "./$SCRIPT_NAME dev my-project my-app /opt/configurazioni/config https://api.openshiftcluster.company.com:6443 MY_LONG_SERVICE_ACCOUNT_TOKEN"
    echo ""
    echo "<environment-type> can be:"
    echo "  dev              : for development environments, where an image build is executed"
    echo "  any other string : for environments where no image build is executed because an existing image is deployed (e.g.: test, prod, ...)"
    exit 0
fi

if [[ $# -ne 6 ]]; then
    echo "Illegal number of parameters"
    exit 1
fi

ENV_TYPE=$1
PRJ=$2
APP=$3
CONFIG_MAP_MOUNT_DIR=$4
OCP_API_URL=$5
TOKEN=$6

TOKEN_PARAM="--token=${TOKEN}"
SERVER_PARAM="--server=${OCP_API_URL}"
PROJECT_PARAM="-n ${PRJ}"

echo "----------------------------------------------------------------------"
echo "PARAMETERS"
echo "----------------------------------------------------------------------"
echo "Openshift API URL: ${OCP_API_URL}"
echo "Target environment type: ${ENV_TYPE}"
echo "Target Namespace: ${PRJ}"
echo "Application name: ${APP}"
echo "Config map mount absolute directory: ${CONFIG_MAP_MOUNT_DIR}"

# Create app resources
echo "----------------------------------------------------------------------"
echo "CREATING APPLICATION RESOURCE FOR APP ${APP}"
echo "----------------------------------------------------------------------"
BASE_IMAGE="jboss-eap72-openshift:1.1"
echo "Using base image for JBoss EAP 7.2 (${BASE_IMAGE})"
oc new-app --image-stream ${BASE_IMAGE} --binary --name=${APP} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}

# Patch deployment config to remove automatic trigger for config/image change
echo "----------------------------------------------------------------------"
echo "PATCHING DC FOR APP ${APP}"
echo "----------------------------------------------------------------------"
oc patch dc ${APP} -p '{"spec":{"triggers":[]}}' -o name ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}

# Create route for the app 
echo "----------------------------------------------------------------------"
echo "CREATING ROUTE FOR APP ${APP}"
echo "----------------------------------------------------------------------"
oc expose svc/${APP} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}

# Create and bind the config map with app properties
CONFIG_MAP_NAME=${APP}-config
echo "----------------------------------------------------------------------"
echo "CREATING AND BINDING CONFIG MAP ${CONFIG_MAP_NAME} FOR APP ${APP}"
echo "----------------------------------------------------------------------"
oc create configmap ${CONFIG_MAP_NAME} --from-file=config/ ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}
oc label configmap ${CONFIG_MAP_NAME} app=${APP} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}
oc set volumes dc/${APP} --add --name=${CONFIG_MAP_NAME} --configmap-name=${CONFIG_MAP_NAME} -m ${CONFIG_MAP_MOUNT_DIR} --overwrite -t configmap ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}

# Create secret for db data and set it as and env variable on the dc
echo "----------------------------------------------------------------------"
echo "CREATING SECRET DEFINED IN FILE secret/config-data-secret.yaml FOR APP ${APP}"
echo "----------------------------------------------------------------------"
sed "s/APP_NAME/${APP}/g" secret/config-data-secret.yaml | oc create ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM} -f -
oc label secret ${APP}-config-data app=${APP} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}
# By convention the openshift secret defined in secret/config-data-secret.yaml will be named ${APP}-config-data
oc set env --from=secret/${APP}-config-data dc/${APP} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}

# Create probes
echo "----------------------------------------------------------------------"
echo "CREATING PROBES FOR LIVENESS AND READINESS HEALTH CHECK FOR APP ${APP}"
echo "----------------------------------------------------------------------"
# Probes for JBoss EAP 7.2
oc set probe dc/${APP} --liveness --initial-delay-seconds=60 --period-seconds=16 --success-threshold=1 --failure-threshold=3 --timeout-seconds=1 ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM} -- /bin/bash '-c' /opt/eap/bin/livenessProbe.sh
oc set probe dc/${APP} --readiness --initial-delay-seconds=10 --period-seconds=16 --success-threshold=1 --failure-threshold=3 --timeout-seconds=1 ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM} -- /bin/bash '-c' /opt/eap/bin/readinessProbe.sh

# Delete unused resources based on the environment type
echo "----------------------------------------------------------------------"
echo "DELETE UNUSED RESOURCES FOR APP ${APP}"
echo "----------------------------------------------------------------------"
oc set image dc/${APP} ${APP}=unset-target-image ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}
oc patch bc ${APP} -o name -p '{"spec":{"output":{"to":{"kind":"DockerImage","name":"unset-target-image"}}}}' ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}
oc delete is/${APP} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}
if [ "$ENV_TYPE" != "dev" ]; then
   oc delete bc/${APP} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}
fi

echo ""
echo "Setup successfully completed for app ${APP}"
