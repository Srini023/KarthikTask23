Step 1: Prepare Environment VariablesBefore running the script, export your Docker Hub credentials and log into Google Cloud in your terminal:

export DOCKER_HUB_USERNAME="2823"
export DOCKER_HUB_PASSWORD="your_docker_hub_access_token_or_password"

gcloud auth application-default login


Run these deployment tools to start the process:

terraform init
terraform apply -var="docker_hub_password=$DOCKER_HUB_PASSWORD"

