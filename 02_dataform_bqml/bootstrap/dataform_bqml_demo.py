from google.cloud import dataform_v1beta1
from google.api_core.exceptions import AlreadyExists
import argparse


def read_file_and_replace(filename,project_id,location,repository_name,bq_dataset_name):
    with open(filename, 'r') as file :
        filedata = file.read()
        filedata = filedata.replace('PROJECT_ID', project_id)
        filedata = filedata.replace('LOCATION', location)
        filedata = filedata.replace('REPOSITORY_NAME', repository_name)
        filedata = filedata.replace('BQ_DATASET_NAME', bq_dataset_name)
    return filedata

def get_repo_files(project_id,location,repository_name,bq_dataset_name):
    return {
        "directories" : ['definitions','includes'],
        "files" : [
            {
                "path" : 'dataform.json',
                "contents" : "{{  \r\"defaultSchema\": \"{}\",\r \"assertionSchema\":  \"dataform_assertions\",\r\"warehouse\":  \"bigquery\",\r\"defaultDatabase\": \"{}\",\r\"defaultLocation\":  \"{}\"\r }}".format(bq_dataset_name,project_id,location).encode('ascii')
        },
        {
            "path" : "package.json",
            "contents" : "{{ \r\"name\":\"{}\",\r\"dependencies\": {{ \"@dataform/core\": \"2.0.1\" }}\r}}".format(repository_name).encode('ascii')
        },
         {
            "path" : ".gitignore",
            "contents" : "node_modules/".format(repository_name).encode('ascii')
        },
          {
            "path" : "definitions/service_data.sqlx",
            "contents" : read_file_and_replace("../scripts-templates/service_data.sqlx",project_id,location,repository_name,bq_dataset_name).encode('ascii')
        },

        {
            "path" : "definitions/customer_data.sqlx",
            "contents" : read_file_and_replace("../scripts-templates/customer_data.sqlx",project_id,location,repository_name,bq_dataset_name).encode('ascii')
        },
        {
        "path" : "definitions/customer_augmented.sqlx",
        "contents" : read_file_and_replace("../scripts-templates/customer_augmented.sqlx",project_id,location,repository_name,bq_dataset_name).encode('ascii')
        },
                {
        "path" : "definitions/churn_classifier.sqlx",
        "contents" : read_file_and_replace("../scripts-templates/churn_classifier.sqlx",project_id,location,repository_name,bq_dataset_name).encode('ascii')
        }

        
    ]
}

def bootstrap_dataform(project_id,location,repository_name,workspace_name,bq_dataset_name):

    client = dataform_v1beta1.DataformClient()
    try:
        repository_request = dataform_v1beta1.CreateRepositoryRequest(
            parent="projects/{}/locations/{}".format(project_id,location),
            repository_id="{}".format(repository_name))
        repository_response = client.create_repository(request=repository_request)
        print(repository_response)
    except AlreadyExists:
        print("Repository {} already exists".format(repository_name))
    try:
        workspace_request = dataform_v1beta1.CreateWorkspaceRequest(
            parent="projects/{}/locations/{}/repositories/{}".format(project_id,location,repository_name),
            workspace_id="{}".format(workspace_name))
        workspace_response = client.create_workspace(request=workspace_request)
        print(workspace_response) 
    except AlreadyExists:
        print("Workspace {} already exists".format(workspace_name))

    repo_structure = get_repo_files(project_id,location,repository_name,bq_dataset_name)
    for directory in repo_structure['directories']:
        try:
            directory_request = dataform_v1beta1.MakeDirectoryRequest(
                workspace="projects/{}/locations/{}/repositories/{}/workspaces/{}".format(project_id,location,repository_name,workspace_name),
                path=directory,
            )
            directory_response = client.make_directory(request=directory_request)
            print(directory_response)
        except AlreadyExists:
            print("Directory {} already exists".format(directory))
    for file in repo_structure['files']:
        file_request = dataform_v1beta1.WriteFileRequest(
                workspace="projects/{}/locations/{}/repositories/{}/workspaces/{}".format(project_id,location,repository_name,workspace_name),
                path = file['path'],
                contents = file['contents'],
            )
        client.write_file(request=file_request)
        print("File {} created or updated".format(file['path']))

    


   
           
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='dataform setup')
    parser.add_argument('--project_id', type=str)
    parser.add_argument('--location', type=str)
    parser.add_argument('--repository_name', type=str)
    parser.add_argument('--workspace_name', type=str)
    parser.add_argument('--bq_dataset_name', type=str)
    params = parser.parse_args()
    bootstrap_dataform(params.project_id,params.location,params.repository_name,params.workspace_name,params.bq_dataset_name)


