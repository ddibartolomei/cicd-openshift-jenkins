#!/bin/bash
set -Eeuo pipefail

trap "echo Setup failed!" ERR

# Setup project, bind Jenkins service account and create Quay registry push/pull secret

if [[ $# -eq 0 ]]; then
    SCRIPT_NAME=`basename "$0"`
    echo "Usage:"
    echo "./$SCRIPT_NAME <target-namespace> <jenkins-service-account-name> <quay-pull-secret-yaml-file> <ocp-api-url> <ocp-admin-token>"
    echo ""
    echo "Usage example:"
    echo "./$SCRIPT_NAME my-project jenkins quay/quay-pull-secret.yaml https://api.openshiftcluster.company.com:6443 abcedf-dasdi31231-dasfaf"
    exit 0
fi

if [[ $# -ne 4 ]]; then
    echo "Illegal number of parameters"
    exit 1
fi

PRJ=$1
JENKINS_SERVICE_ACCOUNT=$2
QUAY_SECRET_FILE=$3
OCP_API_URL=$4
TOKEN=$5

TOKEN_PARAM="--token=${TOKEN}"
SERVER_PARAM="--server=${OCP_API_URL}"
PROJECT_PARAM="-n ${PRJ}"

echo "----------------------------------------------------------------------"
echo "PARAMETERS"
echo "----------------------------------------------------------------------"
echo "Openshift API URL: ${OCP_API_URL}"
echo "Target Namespace: ${PRJ}"
echo "Jenkins Service Account name: ${JENKINS_SERVICE_ACCOUNT}"

# Create namespace
echo "----------------------------------------------------------------------"
echo "CREATING NAMESPACE ${PRJ}"
echo "----------------------------------------------------------------------"
oc new-project ${PRJ} ${TOKEN_PARAM} ${SERVER_PARAM}

# Bind service account
echo "----------------------------------------------------------------------"
echo "BINDING SERVICE ACCOUNT ${JENKINS_SERVICE_ACCOUNT}"
echo "----------------------------------------------------------------------"
oc policy add-role-to-user edit system:serviceaccount:${JENKINS_SERVICE_ACCOUNT}:${JENKINS_SERVICE_ACCOUNT} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}

# Create Quay registry push/pull secret
echo "----------------------------------------------------------------------"
echo "CREATING QUAY PUSH/PULL SECRET USING FILE ${QUAY_SECRET_FILE}"
echo "----------------------------------------------------------------------"
oc create -f ${QUAY_SECRET_FILE} ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}
oc secrets link builder quay-pull-secret ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}
oc secrets link default quay-pull-secret --for=pull ${PROJECT_PARAM} ${TOKEN_PARAM} ${SERVER_PARAM}

echo ""
echo "Setup successfully completed for namespace/project ${PRJ}"

