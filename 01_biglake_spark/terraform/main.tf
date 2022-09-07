variable "project_id" {
    type = string
    description = "This is the GCP where the telecom demo will de deployed"
    validation {
        condition     = length(var.project_id) > 0
        error_message = "The project_id is required."
  }
}

variable "gcp_account_name" {
    type = string
    description = "The GCP account executing the demo"
    validation {
        condition     = length(var.gcp_account_name) > 0
        error_message = "The gcp_account_name is required. It should have been automatically infered"
  }
}

variable "region" {
    type = string
    description = "This is the GCP region where the telecom demo will deploy its resources"
    validation {
        condition     = length(var.region) > 0
        error_message = "The project_id is required."
  }
}
variable "bucket_name" {
    type = string
    description = "This is the GCP GCS bucket where data and code will be staged"
    validation {
        condition     = length(var.bucket_name) > 0
        error_message = "The project_id is required."
  }
}
variable "bq_dataset_name" {
    type = string
    description = "This is the GCP BigQuery dataset name where the tables will be generated"
    validation {
        condition     = length(var.bq_dataset_name) > 0
        error_message = "The project_id is required."
  }
}

variable "src_customer_data" {
    type = string
    description = "This is the source path of staging data (src_customer_data)"
    validation {
        condition     = length(var.src_customer_data) > 0
        error_message = "The src_customer_data is required. It should have been automatically infered"
  }
}
variable "src_service_data" {
    type = string
    description = "This is the source path of staging data (src_service_data)"
    validation {
        condition     = length(var.src_service_data) > 0
        error_message = "The src_service_data is required. It should have been automatically infered"
  }
}

variable "dst_customer_data" {
    type = string
    description = "This is the destination path of staging data (dst_customer_data)"
    validation {
        condition     = length(var.dst_customer_data) > 0
        error_message = "The dst_customer_data is required. It should have been automatically infered"
  }
}
variable "dst_service_data" {
    type = string
    description = "This is the destination path of staging data (dst_service_data)"
    validation {
        condition     = length(var.dst_service_data) > 0
        error_message = "The dst_service_data is required. It should have been automatically infered"
  }
}

variable "project_apis_list" {
    type = list(string)
    description = "This is the list og GCP APIs to enable"
    validation {
        condition     = length(var.project_apis_list) > 0
        error_message = "The project_apis_list is required. It should have been automatically infered"
  }
}



provider "google-beta" {
  project = var.project_id
  region  = var.region
}


resource "google_project_service" "telco-demo-gcp-services" {
  provider                   = google-beta
  count                      = length(var.project_apis_list)
  service                    = var.project_apis_list[count.index]
  disable_dependent_services = true
}


resource "time_sleep" "wait_1_min_after_activate_service_apis" {
  depends_on      = [google_project_service.telco-demo-gcp-services]
  create_duration = "1m"
}



resource "google_storage_bucket" "telco-demo-gcs-bucket-staging" {
  provider = google-beta
  depends_on = [
    time_sleep.wait_1_min_after_activate_service_apis
  ]
  name          = var.bucket_name
  location      = var.region
  force_destroy = true
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "gsutil cp '${var.src_customer_data}' '${var.dst_customer_data}'/ && gsutil cp '${var.src_service_data}' '${var.dst_service_data}'/"

  }
}



resource "google_bigquery_dataset" "telco-demo-bq-dataset" {
  provider = google-beta
  depends_on = [
    time_sleep.wait_1_min_after_activate_service_apis
  ]
  dataset_id                 = var.bq_dataset_name
  location                   = var.region
  delete_contents_on_destroy = true
}


resource "google_bigquery_connection" "telco-demo-biglake-connection" {
  provider = google-beta
  depends_on = [
    time_sleep.wait_1_min_after_activate_service_apis
  ]
  location      = var.region
  connection_id = "biglake-telco-demo"
  cloud_resource {}
}

resource "google_project_iam_member" "telco-demo-connection-grant" {
  provider = google-beta
  project  = var.project_id
  role     = "roles/storage.objectViewer"
  member   = format("serviceAccount:%s", google_bigquery_connection.telco-demo-biglake-connection.cloud_resource[0].service_account_id)
}

resource "time_sleep" "wait_1_min_after_grants" {
  depends_on      = [google_project_iam_member.telco-demo-connection-grant]
  create_duration = "1m"
}


resource "google_bigquery_table" "telco-demo-biglake-table-customer-data" {
  provider   = google-beta
  depends_on = [time_sleep.wait_1_min_after_grants, google_bigquery_dataset.telco-demo-bq-dataset, google_storage_bucket.telco-demo-gcs-bucket-staging]
  dataset_id = var.bq_dataset_name
  #Hardcoded
  table_id   = "customer_data"
  external_data_configuration {
    autodetect    = true
    source_format = "PARQUET"
    connection_id = google_bigquery_connection.telco-demo-biglake-connection.name
    source_uris   = [format("%s/*.parquet", var.dst_customer_data)]


  }
  deletion_protection = false
}


resource "google_bigquery_table" "telco-demo-biglake-table-service-data" {
  provider   = google-beta
  depends_on = [time_sleep.wait_1_min_after_grants, google_bigquery_dataset.telco-demo-bq-dataset,google_storage_bucket.telco-demo-gcs-bucket-staging]
  dataset_id = var.bq_dataset_name
  #Hardcoded
  table_id   = "service_data"
  external_data_configuration {
    autodetect    = true
    source_format = "CSV"
    connection_id = google_bigquery_connection.telco-demo-biglake-connection.name
    source_uris   = [format("%s/*.csv", var.dst_service_data)]
  }
  deletion_protection = false
}



data "google_compute_default_service_account" "default" {
    provider   = google-beta
}


data "template_file" "sproc_telco_demo_biglake_bq" {
  template = "${file("../scripts-templates/telco_demo_biglake.sql")}"
  vars = {
    project_id = var.project_id
    bq_dataset_name = var.bq_dataset_name
    gcp_account_name = var.gcp_account_name
    default_service_account = data.google_compute_default_service_account.default.email
  }  
}


resource "google_bigquery_routine" "sproc_telco_demo_biglake_bq" {
  depends_on = [google_bigquery_dataset.telco-demo-bq-dataset]
  provider   = google-beta
  dataset_id      = var.bq_dataset_name
  routine_id      = "sproc_telco_demo_biglake"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_telco_demo_biglake_bq.rendered}"
}

resource "local_file" "sproc_telco_demo_biglake_bq_rendered" {
  filename = "${path.module}/../scripts-templates/telco_demo_biglake_rendered.sql"
  content  = "${data.template_file.sproc_telco_demo_biglake_bq.rendered}"
}


data "template_file" "sproc_telco_demo_biglake_spark" {
  template = "${file("../scripts-templates/telco_demo_biglake.py")}"
  vars = {
    project_id = var.project_id
    bq_dataset_name = var.bq_dataset_name
    gcp_account_name = var.gcp_account_name
  }  
}

resource "local_file" "sproc_telco_demo_biglake_spark_rendered" {
  depends_on = [google_storage_bucket.telco-demo-gcs-bucket-staging]
  filename = "${path.module}/../scripts-templates/telco_demo_biglake_rendered.py"
  content  = "${data.template_file.sproc_telco_demo_biglake_spark.rendered}"
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "gsutil cp '${path.module}/../scripts-templates/telco_demo_biglake_rendered.py' gs://${var.bucket_name}/code/"

  }
}

data "template_file" "sproc_telco_demo_biglake_spark_launcher" {
  template = "${file("../scripts-templates/launch_pyspark_serverless.sh")}"
  vars = {
    project_id = var.project_id
    region = var.region
    pyspark_file = format("gs://%s/code/telco_demo_biglake_rendered.py", var.bucket_name)

  }  
}

resource "local_file" "sproc_telco_demo_biglake_spark_launcher_rendered" {
  filename = "${path.module}/../scripts-templates/launch_pyspark_serverless_rendered.sh"
  content  = "${data.template_file.sproc_telco_demo_biglake_spark_launcher.rendered}"
}

