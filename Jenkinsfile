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
