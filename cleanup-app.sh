#!/bin/bash

# Cleanup App (delete resources with label app=<app-name>)
if [[ $# -eq 0 ]]; then
    SCRIPT_NAME=`basename "$0"`
    echo "Usage:"
    echo "./$SCRIPT_NAME <target-namespace> <app-name> <ocp-api-url> <ocp-admin-token>"
    echo ""
    echo "Usage example:"
    echo "./$SCRIPT_NAME my-project my-app https://api.openshiftcluster.company.com:6443 abcedf-dasdi31231-dasfaf"
    exit 0
fi

if [[ $# -ne 4 ]]; then
    echo "Illegal number of parameters"
    exit 1
fi

PRJ=$1
APP=$2
OCP_API_URL=$3
TOKEN=$4

TOKEN_PARAM="--token=${TOKEN}"
SERVER_PARAM="--server=${OCP_API_URL}"
PROJECT_PARAM="-n ${PRJ}"

echo "----------------------------------------------------------------------"
echo "PARAMETERS"
echo "----------------------------------------------------------------------"
echo "Openshift API URL: ${OCP_API_URL}"
echo "Target Namespace: ${PRJ}"
echo "Application name: ${APP}"

# Delete namespace
echo "----------------------------------------------------------------------"
echo "DELETING RESOURCES OF APP ${APP} (based on label app=${APP})"
echo "----------------------------------------------------------------------"
oc delete all --selector app=${APP} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}
oc delete configmap --selector app=${APP} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}
oc delete secret --selector app=${APP} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}

echo ""
echo "Cleanup successfully completed for app ${APP}"
