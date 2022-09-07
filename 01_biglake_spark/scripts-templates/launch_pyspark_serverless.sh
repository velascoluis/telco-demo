gcloud dataproc batches submit --project ${project_id} --region ${region} pyspark ${pyspark_file} --jars gs://spark-lib/bigquery/spark-3.1-bigquery-0.26.0-preview.jar --subnet default 
