#!/bin/sh
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# shellcheck disable=SC2006
# shellcheck disable=SC2086
# shellcheck disable=SC2181
# shellcheck disable=SC2129


BQ_BIN=`which bq`
GCLOUD_BIN=`which gcloud`
JQ_BIN=`which jq`


LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Telco demo Deploy 05 - Starting  .."
echo "${LOG_DATE} This scripts generates a remote cloud function callable from BQ  .."

if [ "${#}" -ne 1 ]; then
    echo "Illegal number of parameters. Exiting ..."
    echo "Usage: ${0} <VARIABLES_FILE>"
    echo "Example: ${0} variables.json"
    echo "Exiting ..."
    exit 1
fi

if [ ! "${CLOUD_SHELL}" = true ] ; then
    echo "This script needs to run on Google Cloud Shell. Exiting ..."
    exit 1
fi

CONFIG_FILE="${1}"
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Unable to find ${CONFIG_FILE}"
    exit 1
fi



LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Reading and parsing config file  ${CONFIG_FILE}.."

PROJECT_ID=`cat "${CONFIG_FILE}" | "${JQ_BIN}" -r '.project_id'`
if [ -z "${PROJECT_ID}" ]
then
      echo "Error reading PROJECT_ID"
      echo "Exiting ..."
      exit 1
else
    echo "PROJECT : ${PROJECT_ID}"
fi

REGION=`cat "${CONFIG_FILE}" | "${JQ_BIN}" -r '.region'`
if [ -z "${REGION}" ]
then
      echo "Error reading REGION"
      echo "Exiting ..."
      exit 1
else
    echo "REGION : ${REGION}"
fi

BUCKET_NAME=`cat "${CONFIG_FILE}" | "${JQ_BIN}" -r '.bucket_name'`
if [ -z "${BUCKET_NAME}" ]
then
      echo "Error reading BUCKET_NAME"
      echo "Exiting ..."
      exit 1
else
    echo "BUCKET_NAME : ${BUCKET_NAME}"
fi


BQ_DATASET_NAME=`cat "${CONFIG_FILE}" | "${JQ_BIN}" -r '.bq_dataset_name'`
if [ -z "${BQ_DATASET_NAME}" ]
then
      echo "Error reading BQ_DATASET_NAME"
      echo "Exiting ..."
      exit 1
else
    echo "BQ_DATASET_NAME : ${BQ_DATASET_NAME}"
fi


"${GCLOUD_BIN}" config set project ${PROJECT_ID}
if [ ! "${?}" -eq 0 ];then
    LOG_DATE=`date`
    echo "Unable to run ${GCLOUD_BIN} config set project ${PROJECT_ID}"
    echo "Exiting ..."
    exit 1
fi

GCP_ACCOUNT_NAME=`"${GCLOUD_BIN}" auth list --filter=status:ACTIVE --format="value(account)"`
if [ ! "${?}" -eq 0 ];then
    LOG_DATE=`date`
    echo "Unable to run ${GCLOUD_BIN} auth list --filter=status:ACTIVE --format=value(account)"
    echo "Exiting ..."
    exit 1
fi

LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Deploying cloud function  ..."
CFN_NAME="telco-demo-cfn"
CODE_DIR=${PWD}/../scripts-templates
cd ${CODE_DIR}
"${GCLOUD_BIN}" functions deploy ${CFN_NAME} --runtime python310 --gen2 --trigger-http --allow-unauthenticated --region ${REGION}
if [ ! "${?}" -eq 0 ];then
    LOG_DATE=`date`
    echo "Unable to run ${GCLOUD_BIN} functions deploy ${CFN_NAME} --runtime python310 --gen2 --trigger-http --allow-unauthenticated --region ${REGION}"
    echo "Exiting ..."
    exit 1
fi
echo "Getting URI .."
CFN_URI=`"${GCLOUD_BIN}" functions describe ${CFN_NAME} --gen2 --region ${REGION} --format="value(serviceConfig.uri)"`
if [ ! "${?}" -eq 0 ];then
    LOG_DATE=`date`
    echo "Unable to run ${GCLOUD_BIN} functions describe ${CFN_NAME} --gen2 --region ${REGION} --format=value(serviceConfig.uri)"
    echo "Exiting ..."
    exit 1
fi
echo "URI: ${CFN_URI}"
LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Creating remote function on BigQuery  ..."
#Convert - to _ as required by BQ
CFN_NAME_TX=`echo "${CFN_NAME}" | tr '-' '_'`
CREATE_FN_SQL="CREATE OR REPLACE FUNCTION \`${PROJECT_ID}.${BQ_DATASET_NAME}_transformed.${CFN_NAME_TX}\`(meanThr_DL FLOAT64, meanThr_UL FLOAT64, maxThr_DL FLOAT64, maxThr_UL FLOAT64, meanUE_DL FLOAT64, meanUE_UL FLOAT64, maxUE_DL FLOAT64, maxUE_UL FLOAT64, maxUE_UL_DL FLOAT64 ) RETURNS FLOAT64 REMOTE WITH CONNECTION \`${PROJECT_ID}.${REGION}.biglake-telco-demo\` OPTIONS (endpoint='${CFN_URI}')"
echo "Executing ${CREATE_FN_SQL} ..."
${BQ_BIN} query --nouse_legacy_sql "${CREATE_FN_SQL}"
if [ ! "${?}" -eq 0 ];then
    LOG_DATE=`date`
    echo "Unable to run ${BQ_BIN} query --nouse_legacy_sql ${CREATE_FN_SQL}"
    echo "Exiting ..."
    exit 1
fi
LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Execution finished! ..."