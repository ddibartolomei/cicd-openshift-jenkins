#!/bin/bash

# Cleanup Project
if [[ $# -eq 0 ]]; then
    SCRIPT_NAME=`basename "$0"`
    echo "Usage:"
    echo "./$SCRIPT_NAME <target-namespace> <ocp-api-url> <ocp-admin-token>"
    echo ""
    echo "Usage example:"
    echo "./$SCRIPT_NAME my-project https://api.openshiftcluster.company.com:6443 abcedf-dasdi31231-dasfaf"
    exit 0
fi

if [[ $# -ne 3 ]]; then
    echo "Illegal number of parameters"
    exit 1
fi

PRJ=$1
OCP_API_URL=$2
TOKEN=$3

TOKEN_PARAM="--token=${TOKEN}"
SERVER_PARAM="--server=${OCP_API_URL}"

echo "----------------------------------------------------------------------"
echo "PARAMETERS"
echo "----------------------------------------------------------------------"
echo "Openshift API URL: ${OCP_API_URL}"
echo "Target Namespace: ${PRJ}"

# Delete namespace
echo "----------------------------------------------------------------------"
echo "DELETING NAMESPACE ${PRJ}"
echo "----------------------------------------------------------------------"
oc delete project ${PRJ} ${TOKEN_PARAM} ${SERVER_PARAM}

echo ""
echo "Cleanup successfully completed for project ${PRJ}"
