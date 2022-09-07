

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

import pyspark
from pyspark.sql import SparkSession
import argparse


def exec_telco_demo_biglake(project_id, dataset_name, table_name):
    #spark =SparkSession.builder.appName("exec_telco_demo_biglake_exploration").config('spark.jars', 'gs://spark-lib/bigquery/spark-bigquery-latest_2.12.jar').getOrCreate()
    spark =SparkSession.builder.appName("exec_telco_demo_biglake_exploration").getOrCreate()
    rows = spark.read.format('bigquery').option('table', project_id+':'+dataset_name+'.'+table_name).load()
    rows.show()


def main(params):
    exec_telco_demo_biglake(project_id=params.project_id, dataset_name=params.dataset_name, table_name=params.table_name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Spark driver code")
    parser.add_argument("--project_id", type=str, default="${project_id}")
    parser.add_argument("--dataset_name", type=str, default="${bq_dataset_name}")
    parser.add_argument("--table_name", type=str, default="customer_data")
    params = parser.parse_args()
    main(params)


