Create a project folder
create a nginx index.html
create a config file of nginx
craete a dockerfile 
Use base image nginx:alpine
Copy index.html to /usr/share/nginx/html/
Copy nginx.conf to /etc/nginx/conf.d/

Build and Push Docker Image
Build the Docker image locally and push to a registry accessible by GCP.

Run docker build -t gcr.io/<PROJECT_ID>/nginx-app:v1 .

Authenticate with GCP: gcloud auth configure-docker

Push image: docker push gcr.io/<PROJECT_ID>/nginx-app:v1

Create Kubernetes Deployment and Service
Define Kubernetes manifests to deploy the image and expose it.

Create deployment.yaml with replicas and container spec

Create service.yaml with type LoadBalancer to expose externally

Apply with kubectl apply -f deployment.yaml -f service.yaml

Set Up GitHub Actions Workflow
Automate build, push, and deploy steps with CI/CD.

Add .github/workflows/deploy.yml

Define jobs: Checkout → Build Docker → Push to GCR → Deploy to GKE

Use GitHub Secrets for GCP credentials and project ID

Add steps: gcloud auth activate-service-account, docker build/push, kubectl apply

Verify External URL
Confirm that the service is exposed to the outer world.

Run kubectl get svc

Copy the external IP assigned by LoadBalancer

Access http://<EXTERNAL_IP> in browser

