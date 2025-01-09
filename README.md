# DevOps Application Deployment

This repository contains infrastructure and pipeline configurations to deploy an application using the following technologies:

1. **Terraform** for provisioning an Amazon Elastic Kubernetes Service (EKS) cluster.
2. **Docker** for containerizing the application.
3. **Jenkins** for CI/CD with integrated DevSecOps tools.
4. **ArgoCD** for GitOps-based continuous delivery.

## Prerequisites

- AWS account with IAM permissions to create EKS resources.
- Terraform installed on your local machine.
- Docker installed on your local machine.
- Jenkins server with required plugins (Pipeline, Docker, Kubernetes).
- ArgoCD installed and configured.

---

## Steps to Deploy the Application

### 1. Provision EKS with Terraform
![Terraform Diagram]([https://example.com/path/to/image.png](https://github.com/Walidbadry/LEMP-stack-wordpress-/blob/main/EKS-Terraform-GitHub-Actions-master/Presentation1.gif))

1. Navigate to the `terraform` directory:

    ```bash
    cd terraform
    ```

2. Initialize Terraform:

    ```bash
    terraform init
    ```

3. Apply the configuration to create an EKS cluster:

    ```bash
    terraform apply
    ```

4. Update your `kubeconfig` to use the new EKS cluster:

    ```bash
    aws eks --region <region> update-kubeconfig --name <cluster_name>
    ```

---

### 2. Dockerize the Application

1. Create a `Dockerfile` in the root of your application:

    ```dockerfile
    FROM node:16
    WORKDIR /app
    COPY package*.json ./
    RUN npm install
    COPY . .
    CMD ["npm", "start"]
    EXPOSE 3000
    ```

2. Build and push the Docker image:

    ```bash
    docker build -t <dockerhub_username>/my-app:latest .
    docker push <dockerhub_username>/my-app:latest
    ```

---

### 3. Set Up CI/CD with Jenkins

1. Create a Jenkins pipeline job with the following script:

    ```groovy
    pipeline {
        agent any
        stages {
            stage('Checkout') {
                steps {
                    git 'https://github.com/your-repo/your-app.git'
                }
            }
            stage('Build Docker Image') {
                steps {
                    sh 'docker build -t <dockerhub_username>/my-app:latest .'
                }
            }
            stage('Push Docker Image') {
                steps {
                    sh 'docker push <dockerhub_username>/my-app:latest'
                }
            }
            stage('Deploy to Kubernetes') {
                steps {
                    sh 'kubectl apply -f k8s/deployment.yaml'
                }
            }
        }
    }
    ```

2. Integrate security tools like **Trivy** for scanning the Docker image and **SonarQube** for code analysis.

---

### 4. Configure GitOps with ArgoCD

1. Install ArgoCD on your EKS cluster:

    ```bash
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```

2. Expose the ArgoCD server:

    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```

3. Login to the ArgoCD UI and configure your application:

    ```bash
    argocd app create my-app \
      --repo https://github.com/your-repo/your-app.git \
      --path k8s \
      --dest-server https://kubernetes.default.svc \
      --dest-namespace default
    ```

4. Sync the application:

    ```bash
    argocd app sync my-app
    ```

---

## Monitoring and Logs

- Use **kubectl** to monitor your application:

    ```bash
    kubectl get pods -n default
    kubectl logs -f <pod-name>
    ```

- Monitor Jenkins pipelines for build and deployment statuses.

- Access ArgoCD UI to track GitOps deployments.

---

## Directory Structure

```
.
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── Dockerfile
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
├── Jenkinsfile
└── README.md
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
