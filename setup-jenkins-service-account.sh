#!/bin/bash
set -Eeuo pipefail

trap "echo Setup failed!" ERR

# Setup service account namespace for jenkins user and generate token
# By convention the service account name will be the same as the namespace it belongs to

if [[ $# -eq 0 ]]; then
    SCRIPT_NAME=`basename "$0"`
    echo "Usage:"
    echo "./$SCRIPT_NAME <jenkins-service-account-name> <ocp-api-url> <ocp-admin-token>"
    echo ""
    echo "Usage example:"
    echo "./$SCRIPT_NAME jenkins https://api.openshiftcluster.company.com:6443 abcedf-dasdi31231-dasfaf"
    exit 0
fi

if [[ $# -ne 3 ]]; then
    echo "Illegal number of parameters"
    exit 1
fi

JENKINS_SERVICE_ACCOUNT=$1
OCP_API_URL=$2
TOKEN=$3

TOKEN_PARAM="--token=${TOKEN}"
SERVER_PARAM="--server=${OCP_API_URL}"
PROJECT_PARAM="-n ${JENKINS_SERVICE_ACCOUNT}"

echo "----------------------------------------------------------------------"
echo "PARAMETERS"
echo "----------------------------------------------------------------------"
echo "Openshift API URL: ${OCP_API_URL}"
echo "Target Namespace (service account name): ${JENKINS_SERVICE_ACCOUNT}"

# Create namespace for jenkins
echo "----------------------------------------------------------------------"
echo "CREATING NAMESPACE ${JENKINS_SERVICE_ACCOUNT}"
echo "----------------------------------------------------------------------"
oc new-project ${JENKINS_SERVICE_ACCOUNT} ${TOKEN_PARAM} ${SERVER_PARAM}

# Create service account
echo "----------------------------------------------------------------------"
echo "CREATING SERVICE ACCOUNT ${JENKINS_SERVICE_ACCOUNT}"
echo "----------------------------------------------------------------------"
oc create serviceaccount ${JENKINS_SERVICE_ACCOUNT} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}

# Generate service account token
echo "----------------------------------------------------------------------"
echo "GENERATING TOKEN FOR SERVICE ACCOUNT ${JENKINS_SERVICE_ACCOUNT}"
echo "----------------------------------------------------------------------"
SERVICE_ACCOUNT_TOKEN=$(oc serviceaccounts get-token ${JENKINS_SERVICE_ACCOUNT} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM})
echo ""
echo "Token for ${JENKINS_SERVICE_ACCOUNT} service account: ${SERVICE_ACCOUNT_TOKEN}"

echo ""
echo "Setup successfully completed for service account ${JENKINS_SERVICE_ACCOUNT}"
