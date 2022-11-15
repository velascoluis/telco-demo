# Telco demo : A GCP Data Platform tour

The aim of this demo is to present various specific differential aspects of the Google Cloud data platform using a telco dataset as a proxy to conduct the demo. The demo is structured on 4 parts.
It should be used together with this slide deck.

## Demo 1 : DataLake+EDWH convergence: BigLake, SPARK serverless and terraform

### Overview

**Objective:** Shows a fully automated deployment with Terraform and focus on the interoperability between BQ and SPARK - Convergence of DLs and DWHs

- Use Terraform to deploy GCP components (GCS buckets, data staging, creation of procedures)
- Use BigLake to create GCS external tables in PARQUET and CSV files formats.
- Shows how BigLake unifies RAP from BQ and from SPARK Serverlesss


### Step by step guide

* Edit `01_biglake_spark/bootstrap/variables.json` file
* * Pay special attention of the location (region), some services are not yet fully avaliable in all regions (e.g. dataform)
* Deploy infra by launching the bootstrap script **Cloud Shell**
```bash
$ cd 01_biglake_spark/bootstrap
source spark_biglake_demo.sh variables.json deploy
```
* Now, go to BigQuery and look at the tables that are beign provisioned
* Execute Step By Step the `sproc_telco_demo_biglake` stored procedure to see the effects of RAP, at some point you will launch a SPARK serverless job, use the rendered local scripts generated on the `scripts_templates` folder, terraform will take care of the hydratation


## Demo 2 : dataform and BQML

### Overview

**Objective:** Introduce the ELT dataOps paradigm with dataform and then shows the BQML feature of BQ 

- Use dataform SDK to boostrap a dataform repo with a simple transformation
- Execute a workflow that includes the creation of a BQML model


### Step by step guide

* You should have executed first the lab 01 to stage the data in BQ
* From **Cloud Shell**, Edit `02_dataform_bqml/bootstrap/variables.json` file
* Deploy the repo, workspace and stage the pipeline by executing from **Cloud Shell**
```bash
cd 02_dataform_bqml/bootstrap
$ source dataform_bqml_demo.sh variables.json
```
* Give permissions to the recently created dataform service account, follow [this](https://cloud.google.com/dataform/docs/required-access)
* Now, go to BigQuery dataform and review the repository

**_NOTE:_**  Once you are inside the dataform code repository, open the `package.json` file and click on "INSTALL PACKAGES"

* Execute the workflow
* See the XGBoost model created

## Demo 3 : BI Engine

### Overview

**Objective:** Introduce BI Engine the the audience and show how it works from the GUI

- Create a large table
- Execute a query aggregation over the table with and without BI Engine

### Step by step guide

* You should have executed  lab 01 and lab 02 to generate the data in BQ
* Execute this script from the BQ GUI to generate A LOT (500GB or so) of data, be careful with the costs:
```sql
DECLARE n int64;
DECLARE i INT64 DEFAULT 1;
SET n = 20;
CREATE TABLE `<PROJECT_ID>.telco_demo_dataset_transformed.customer_augmented_mat` AS 
SELECT
    *
FROM
    `<PROJECT_ID>.telco_demo_dataset_transformed.customer_augmented`;
WHILE i < n DO
INSERT INTO
  `<PROJECT_ID>.telco_demo_dataset_transformed.customer_augmented_mat`
SELECT
  *
FROM
  `<PROJECT_ID>.telco_demo_dataset_transformed.customer_augmented_mat`;
  SET i = i + 1;
END WHILE
;
```
* Enable BI Engine from the GUI, and create a reservation  with the PINNED tables option pointing to the `<PROJECT_ID>.telco_demo_dataset_transformed.customer_augmented_mat` table , and execute this query from the BQ SQL GUI:
```sql
SELECT
  MAX(PRBUsageUL),
  CellTower,
  InternetService,
  tenure
FROM
  `<PROJECT_ID>.telco_demo_dataset_transformed.customer_augmented_mat`
GROUP BY
  CellTower,
  InternetService,
  tenure
```

## Demo 4 : Data Fabric with Dataplex

### Overview

**Objective:** Introduce the data fabric framework dataplex and run a DataQuality task

- Use dataplex SDK to boostrap  a lake , with zones and attatch resources to it
- Execute a data qualiy task


### Step by step guide

* You should have executed lab 01 and lab 02 to generate the data in BQ
* Edit `04_dataplex/bootstrap/variables.json` file
* Deploy the data lake taxonomy
```bash
cd 04_dataplex/bootstrap
$ source dataplex_demo.sh variables.json
```
* Now, go to DataPlex and examine the structure deployed
* From the GUI launch a new DQ Task using the rules on `${BUCKET_NAME}/code/dq_rules_templates.yml`
* NOTE: You might need to wait for the discovery task to kick in and registger the entities (GCS tables) inside the assets


## Demo 5 : Remote Cloud Functions / Cloud Run from BigQuery

### Overview

**Objective:** Shows the integration between BigQuery UDFs with Cloud Functions 

- Use the CLI to deploy a python cloud function that uses a external package (e.g. numpy)
- Deploy a remote UDF at BQ that ends calling up the cloud function


### Step by step guide

* You should have executed labs 01 and lab 02 to generate the data in BQ
* Edit `05_remote_cfn/bootstrap/variables.json` file
* Deploy the cloud function and the remote UDF
```bash
cd 05_remote_cfn/bootstrap
$ source remote_cfn_demo.sh variables.json
```
* Now, go to BQ and launch the folowing SQL:

```sql
SELECT
    `<PROJECT_ID>.telco_demo_velascoluis_dev_sandbox_transformed.telco_demo_cfn`(
        meanThr_DL ,
        meanThr_UL ,
        maxThr_DL ,
        maxThr_UL ,
        meanUE_DL ,
        meanUE_UL ,
        maxUE_DL ,
        maxUE_UL ,
        maxUE_UL_DL) AS matrix_determinant
FROM
    `<PROJECT_ID>.telco_demo_velascoluis_dev_sandbox_transformed.customer_augmented`
WHERE
    tenure < 1
```

NOTE: This demo uses some of the data and scripts from  [Spark serverless workshop - Cell Tower Anomaly Detection.](https://github.com/velascoluis/serverless-spark-workshop/tree/main/cell-tower-anomaly-detection)

