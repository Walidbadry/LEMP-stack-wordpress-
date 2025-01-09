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
<img src="EKS-Terraform-GitHub-Actions-master/Presentation1.gif" width="1000">

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
    # Use the official Ubuntu image
    FROM ubuntu:20.04

    # Set environment variables to avoid interactive prompts during package installation
    ENV DEBIAN_FRONTEND=noninteractive

    # Update and install required packages
    RUN apt-get update && apt-get install -y \
        apache2 \
        php \
        php-mysql \
        libapache2-mod-php \
        curl \
        unzip \
        wget \
        mysql-client \
        && apt-get clean

    # Enable Apache rewrite module
    RUN a2enmod rewrite

    # Set working directory
    WORKDIR /var/www/html

    # Copy your WordPress application files into the container
    COPY ./wordpress /var/www/html

    # Set correct permissions
    RUN chown -R www-data:www-data /var/www/html \
        && chmod -R 755 /var/www/html

    # Expose port 80
    EXPOSE 80

    # Start Apache in the foreground
    CMD ["apachectl", "-D", "FOREGROUND"]
    ```

2. Build and push the Docker image for test:

    ```bash
    docker build -t <dockerhub_username>/my-app:latest .
    docker push <dockerhub_username>/my-app:latest
    ```

---

### 3. Set Up CI/CD with Jenkins
<img src="Pipeline-view.png" width="1000">

1. Create a Jenkins pipeline job with the following script:

    ```groovy
    pipeline {
        agent any
        tools {
            jdk 'jdk'
            nodejs 'nodejs'
        }
        environment {
            SCANNER_HOME = tool 'sonar-scanner'
            DOCKER_CREDENTIALS = credentials('docker-hub')
            DOCKER_USERNAME = credentials('DOCKER_USERNAME')
            DOCKER_PASSWORD = credentials('DOCKER_PASSWORD')
            AWS_ACCOUNT_ID = credentials('ACCOUNT_ID')
            AWS_DEFAULT_REGION = 'us-east-1'
            REPOSITORY_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/"
            DEFECTDOJO_API_URL = 'http://defectdojo.example.com/api/v2/'
            DEFECTDOJO_API_KEY = credentials('defectdojo-api-key')
            DEFECTDOJO_PRODUCT_ID = '123' // Replace with your DefectDojo Product ID
            BUILD_TAG = "${BUILD_NUMBER}"
        }
        stages {
            stage('Clean Workspace') {
                steps {
                    cleanWs()
                }
            }

            stage('Checkout Code') {
                steps {
                    git credentialsId: 'GITHUB', url: 'https://github.com/WordPress/WordPress.git'
                }
            }

            stage('Secret Scanning with Gitleaks') {
                steps {
                    sh 'gitleaks detect --source . --report-format json --report-path gitleaks-report.json || true'
                }
                post {
                    always {
                        script {
                            uploadToDefectDojo('gitleaks-report.json', 'Gitleaks Scan')
                        }
                    }
                }
            }

            stage('SonarQube Analysis') {
                steps {
                    dir('Application-Code/backend') {
                        withSonarQubeEnv('sonar-server') {
                            sh '''
                            $SCANNER_HOME/bin/sonar-scanner \
                            -Dsonar.projectName=three-tier-backend \
                            -Dsonar.projectKey=three-tier-backend
                            '''
                        }
                    }
                }
                post {
                    always {
                        script {
                            uploadToDefectDojo('sonar-report.json', 'SonarQube Analysis')
                        }
                    }
                }
            }

            stage('Dependency Check (OWASP)') {
                steps {
                    dir('Application-Code/backend') {
                        dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check'
                        dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                    }
                }
                post {
                    always {
                        script {
                            uploadToDefectDojo('dependency-check-report.xml', 'OWASP Dependency Check')
                        }
                    }
                }
            }

            stage('Trivy File Scan') {
                steps {
                    dir('Application-Code/backend') {
                        sh 'trivy fs . --format json --output trivy-file-scan.json'
                    }
                }
                post {
                    always {
                        script {
                            uploadToDefectDojo('trivy-file-scan.json', 'Trivy File Scan')
                        }
                    }
                }
            }

            stage('Build Docker Image') {
                steps {
                    dir('Application-Code/backend') {
                        sh 'docker build -t ${DOCKER_USERNAME}/${AWS_ECR_REPO_NAME} .'
                    }
                }
            }

            stage('Push Docker Image to Docker Hub') {
                steps {
                    script {
                        docker.withRegistry('', 'docker-hub') {
                            sh '''
                            docker tag ${DOCKER_USERNAME}/${AWS_ECR_REPO_NAME}:latest ${DOCKER_USERNAME}/${AWS_ECR_REPO_NAME}:${BUILD_NUMBER}
                            docker push ${DOCKER_USERNAME}/${AWS_ECR_REPO_NAME}:${BUILD_NUMBER}
                            docker push ${DOCKER_USERNAME}/${AWS_ECR_REPO_NAME}:latest
                            '''
                        }
                    }
                }
            }

            stage('Image Vulnerability Scan with Trivy') {
                steps {
                    sh 'trivy image ${DOCKER_USERNAME}/${AWS_ECR_REPO_NAME}:${BUILD_NUMBER} --format json --output trivy-image-scan.json'
                }
                post {
                    always {
                        script {
                            uploadToDefectDojo('trivy-image-scan.json', 'Trivy Image Scan')
                        }
                    }
                }
            }

            stage('Update Deployment file') {
                environment {
                    GIT_REPO_NAME = "End-to-End-Kubernetes-Three-Tier-DevSecOps-Project"
                    GIT_USER_NAME = "walidbadry"
                }
                steps {
                    dir('K8s') {
                        withCredentials([string(credentialsId: 'github', variable: 'GITHUB_TOKEN')]) {
                            sh '''
                                git config user.email "walidbadry@gmail.com"
                                git config user.name "walidbadry"
                                BUILD_NUMBER=${BUILD_NUMBER}
                                echo $BUILD_NUMBER
                                imageTag=$(grep -oP '(?<=php:)[^ ]+' wordpress-deployment.yaml)
                                echo $imageTag
                                sed -i "s/${AWS_ECR_REPO_NAME}:${imageTag}/${AWS_ECR_REPO_NAME}:${BUILD_NUMBER}/" wordpress-deployment.yaml
                                git add wordpress-deployment.yaml
                                git commit -m "Update deployment Image to version \${BUILD_NUMBER}"
                                git push https://${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME} HEAD:master
                            '''
                        }
                    }
                }
            }

            stage('DAST (Dynamic Analysis with ZAP)') {
                steps {
                    sh 'zap-baseline.py -t http://staging-environment.com -r zap-report.html'
                }
                post {
                    always {
                        script {
                            uploadToDefectDojo('zap-report.html', 'ZAP DAST Scan')
                        }
                    }
                }
            }
        }

        post {
            always {
                archiveArtifacts artifacts: '**/*.json, **/*.xml, **/*.html', allowEmptyArchive: true
            }
        }
    }

    // Utility method to upload reports to DefectDojo
    def uploadToDefectDojo(reportPath, scanType) {
        sh """
        curl -X POST "${DEFECTDOJO_API_URL}engagements/1/import_scan/" \
            -H "Authorization: Token ${DEFECTDOJO_API_KEY}" \
            -H "Content-Type: multipart/form-data" \
            -F 'scan_type=${scanType}' \
            -F 'file=@${reportPath}' \
            -F 'engagement=1' \
            -F 'tags=${BUILD_TAG}' \
            -F 'minimum_severity=Low'
        """
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
