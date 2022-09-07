
-- See ALL the data
SELECT *
  FROM `${project_id}.${bq_dataset_name}.customer_data`;


-- Query: Create an access policy so the admin (you) can only see Fiber Optic customers
CREATE OR REPLACE ROW ACCESS POLICY rap_customer_data_InternetService_Fiber_optic
    ON `${project_id}.${bq_dataset_name}.customer_data`
    GRANT TO ("user:${gcp_account_name}")
FILTER USING (InternetService = 'Fiber optic');

-- See just the data you are allowed to see
SELECT *
  FROM `${project_id}.${bq_dataset_name}.customer_data`;


-- Switch to a pySpark script and see the effects of the RAP with a different RAP for a different user (compute engine default SA)

CREATE OR REPLACE ROW ACCESS POLICY rap_customer_data_InternetService_DSL
    ON `${project_id}.${bq_dataset_name}.customer_data`
    GRANT TO ("serviceAccount:${default_service_account}")
FILTER USING (InternetService = 'DSL');

-- Lanch from SPARK a query: launch_pyspark_serverless_rendered.sh 

-- Drop the policy
DROP ALL ROW ACCESS POLICIES ON `${project_id}.${bq_dataset_name}.customer_data`;


-- See all the data
SELECT *
  FROM `${project_id}.${bq_dataset_name}.customer_data`;


 -- Create a BQ native table
CREATE TABLE `${project_id}.${bq_dataset_name}.customer_data_native` AS SELECT *
  FROM `${project_id}.${bq_dataset_name}.customer_data` WHERE InternetService = 'DSL';