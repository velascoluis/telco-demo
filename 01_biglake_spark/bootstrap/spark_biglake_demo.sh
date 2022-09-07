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
echo "${LOG_DATE} Telco demo Deploy 01 - Starting  .."
echo "${LOG_DATE} This scripts stages data into GCS and create BigLake tables  .."

if [ "${#}" -ne 2 ]; then
    echo "Illegal number of parameters. Exiting ..."
    echo "Usage: ${0} <VARIABLES_FILE> <(DEPLOY|DESTROY)>"
    echo "Example: ${0} variables.json deploy"
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

COMMAND="${2}"
if [[ ! "${COMMAND}" =~ ^(deploy|destroy)$ ]]; then
    echo "Command needs to be deploy | destroy. Exiting ..."
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


BASE_DIR="${PWD}/.."
DATA_DIR="${BASE_DIR}"/sample-data
TF_CORE_DIR="${BASE_DIR}"/terraform

PROJECT_APIS_LIST='["compute.googleapis.com" , "dataproc.googleapis.com" , "bigquery.googleapis.com" , "storage.googleapis.com" , "iam.googleapis.com" , "iamcredentials.googleapis.com" ,"orgpolicy.googleapis.com"]'

CUSTOMER_DATA_FILES="customers_raw_data/*.parquet"
SERVICE_DATA_FILES="service_raw_data/service_threshold_data.csv"

SRC_CUSTOMER_DATA="${DATA_DIR}"/"${CUSTOMER_DATA_FILES}"
SRC_SERVICE_DATA="${DATA_DIR}"/"${SERVICE_DATA_FILES}"
SRC_TELECOM_DATA="${DATA_DIR}"/"${TELECOM_DATA_FILES}"


DST_CUSTOMER_DATA=gs://"${BUCKET_NAME}"/data/customers_raw_data
DST_SERVICE_DATA=gs://"${BUCKET_NAME}"/data/service_raw_data
DST_TELECOM_DATA=gs://"${BUCKET_NAME}"/data/telecom_raw_data


PLAN_NAME_CORE="telco-demo-infra-core.plan"


LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Launching Terraform ..."


export TF_VAR_project_id="${PROJECT_ID}"
export TF_VAR_region="${REGION}"
export TF_VAR_project_apis_list="${PROJECT_APIS_LIST}"
export TF_VAR_bucket_name="${BUCKET_NAME}"
export TF_VAR_bq_dataset_name="${BQ_DATASET_NAME}"
export TF_VAR_gcp_account_name="${GCP_ACCOUNT_NAME}"


export TF_VAR_src_customer_data="${SRC_CUSTOMER_DATA}"
export TF_VAR_src_service_data="${SRC_SERVICE_DATA}"

export TF_VAR_dst_customer_data="${DST_CUSTOMER_DATA}"
export TF_VAR_dst_service_data="${DST_SERVICE_DATA}"



LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} - TF Variables:"
echo "TF var project_id : ${PROJECT_ID}"
echo "TF var region : ${REGION}"
echo "TF var project_api_list : ${PROJECT_APIS_LIST}"
echo "TF var bucket_name : ${BUCKET_NAME}"
echo "TF var bq_dataset_name : ${BQ_DATASET_NAME}"
echo "TF var src_customer_data : ${SRC_CUSTOMER_DATA}"
echo "TF var src_service_data  : ${SRC_SERVICE_DATA}"
echo "TF var dst_customer_data : ${DST_CUSTOMER_DATA}"
echo "TF var dst_service_data : ${DST_SERVICE_DATA}"
echo "TF var gcp_account_name : ${GCP_ACCOUNT_NAME}"

cd "${TF_CORE_DIR}" || exit 1
"${TERRAFORM_BIN}" init -reconfigure
if [ ! "${?}" -eq 0 ]; then
        LOG_DATE=`date`
        echo "${LOG_DATE} Unable to run ${TERRAFORM_BIN} init -reconfigure. Exiting ..."
        exit 1
fi
"${TERRAFORM_BIN}" validate
if [ ! "${?}" -eq 0 ]; then
        LOG_DATE=`date`
        echo "${LOG_DATE} Unable to run ${TERRAFORM_BIN} validate. Exiting ..."
        exit 1
fi
"${TERRAFORM_BIN}" plan -out="${PLAN_NAME_CORE}"

if [ "${COMMAND}" = "deploy" ] ; then
    "${TERRAFORM_BIN}" apply "${PLAN_NAME_CORE}"
    if [ ! "${?}" -eq 0 ]; then
        LOG_DATE=`date`
        echo "${LOG_DATE} Unable to run ${TERRAFORM_BIN} apply -out=${PLAN_NAME_CORE} . Exiting ..."
        exit 1
    fi
    else
        #destroy
        "${TERRAFORM_BIN}" "${COMMAND}"  -auto-approve
        if [ ! "${?}" -eq 0 ]; then
            LOG_DATE=`date`
            echo "${LOG_DATE} Unable to run ${TERRAFORM_BIN} ${COMMAND}  -auto-approve . Exiting ..."
            exit 1
        fi
fi
LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Execution finished! ..."