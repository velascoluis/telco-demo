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


TERRAFORM_BIN=`which terraform`
GCLOUD_BIN=`which gcloud`
JQ_BIN=`which jq`


LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Telco demo Deploy 04 - Starting  .."
echo "${LOG_DATE} This scripts generates a DataPlex lake  .."

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
echo "${LOG_DATE} Calling dataplex python SDK  ..."


pip3 install --upgrade pip
python3 -m venv local_test_env
source local_test_env/bin/activate
pip3 install -r requirements.txt
python3 dataplex_demo.py --project_id ${PROJECT_ID} --location ${REGION} --bucket_name ${BUCKET_NAME} --bq_dataset_name ${BQ_DATASET_NAME}
deactivate

LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Staging DQ rules file  ..."
DQ_RULES_PATH=${PWD}/../scripts-templates/dq_rules_template.yml
DQ_RULES_FILE=`basename ${DQ_RULES_PATH}`

sed -i s/PROJECT_ID/${PROJECT_ID}/g ${DQ_RULES_PATH}
sed -i s/LOCATION/${REGION}/g ${DQ_RULES_PATH}

gsutil cp ${DQ_RULES_PATH} gs://${BUCKET_NAME}/code/${DQ_RULES_FILE}