pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    choice(
      name: 'ACTION',
      choices: ['apply', 'destroy'],
      description: 'Terraform action'
    )
    booleanParam(
      name: 'AUTO_APPROVE',
      defaultValue: false,
      description: 'Skip manual approval'
    )
  }

  environment {
    IMAGE_NAME   = "cloudopsharsh/demo-app"
    IMAGE_TAG    = "${BUILD_NUMBER}"
    AWS_REGION   = "us-east-1"
    CLUSTER_NAME = "demo-eks"
  }

  stages {

   

    stage('Checkout Code') {
      steps {
        git branch: 'main',
            url: 'https://github.com/Harsh8718-cloudops/Demo-Project.git'
      }
    }

    stage("Trivy: Filesystem scan"){
            steps{
                script{
                    sh "trivy fs ."
                }
            }
        }

    stage("OWASP: Dependency check"){
            steps{
                script{
                    dependencyCheck additionalArguments: '--scan ./', odcInstallation: 'OWASP'
                    dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                }
            }
        }
        
    stage("SonarQube: Code Analysis"){
            steps{
                script{
                    withSonarQubeEnv("${SonarQubeAPI}"){
                    sh "$SONAR_HOME/bin/sonar-scanner -Dsonar.projectName=${Projectname} -Dsonar.projectKey=${ProjectKey} -X"
            }
                }
            }
        }
        
    stage("SonarQube: Code Quality Gates"){
            steps{
                script{
                    timeout(time: 1, unit: "MINUTES"){
                    waitForQualityGate abortPipeline: false
            }
                }
            }
        }

    stage('Build Docker Image') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        dir('app') {
          sh '''
            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          '''
        }
      }
    }

    stage('Push Docker Image') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        withCredentials([
          usernamePassword(
            credentialsId: 'dockerhub-creds',
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS'
          )
        ]) {
          sh '''
            echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER} --password-stdin
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
          '''
        }
      }
    }

    /* =====================================================
       VPC : INIT
    ===================================================== */

    stage('VPC - Terraform Init') {
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding',
           credentialsId: 'aws-creds']
        ]) {
          dir('terraform/Terraform Manifest/vpc') {
            sh 'terraform init -input=false'
          }
        }
      }
    }

    /* =====================================================
       VPC : PLAN
    ===================================================== */

    stage('VPC - Terraform Plan') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding',
           credentialsId: 'aws-creds']
        ]) {
          dir('terraform/Terraform Manifest/vpc') {
            sh '''
              terraform plan -out=tfplan
              terraform show -no-color tfplan > tfplan.txt
            '''
          }
        }
      }
    }

    /* =====================================================
       VPC : APPROVAL
    ===================================================== */

    stage('VPC - Manual Approval') {
      when {
        allOf {
          expression { params.ACTION == 'apply' }
          expression { !params.AUTO_APPROVE }
        }
      }
      steps {
        input message: 'Approve VPC Terraform Apply?',
              parameters: [
                text(
                  name: 'VPC Terraform Plan',
                  defaultValue: readFile('terraform/Terraform Manifest/vpc/tfplan.txt')
                )
              ]
      }
    }

    /* =====================================================
       VPC : APPLY / DESTROY
    ===================================================== */

    stage('VPC - Terraform Apply / Destroy') {
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding',
           credentialsId: 'aws-creds']
        ]) {
          dir('terraform/Terraform Manifest/vpc') {
            script {
              if (params.ACTION == 'apply') {
                sh 'terraform apply -auto-approve tfplan'
              } else {
                sh 'terraform destroy -auto-approve'
              }
            }
          }
        }
      }
    }

    /* =====================================================
       EKS : INIT (AFTER VPC)
    ===================================================== */

    stage('EKS - Terraform Init') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding',
           credentialsId: 'aws-creds']
        ]) {
          dir('terraform/Terraform Manifest/eks') {
            sh 'terraform init -input=false'
          }
        }
      }
    }

    /* =====================================================
       EKS : PLAN
    ===================================================== */

    stage('EKS - Terraform Plan') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding',
           credentialsId: 'aws-creds']
        ]) {
          dir('terraform/Terraform Manifest/eks') {
            sh '''
              terraform plan -out=tfplan
              terraform show -no-color tfplan > tfplan.txt
            '''
          }
        }
      }
    }

    /* =====================================================
       EKS : APPROVAL
    ===================================================== */

    stage('EKS - Manual Approval') {
      when {
        allOf {
          expression { params.ACTION == 'apply' }
          expression { !params.AUTO_APPROVE }
        }
      }
      steps {
        input message: 'Approve EKS Terraform Apply?',
              parameters: [
                text(
                  name: 'EKS Terraform Plan',
                  defaultValue: readFile('terraform/Terraform Manifest/eks/tfplan.txt')
                )
              ]
      }
    }

    /* =====================================================
       EKS : APPLY / DESTROY
    ===================================================== */

    stage('EKS - Terraform Apply / Destroy') {
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding',
           credentialsId: 'aws-creds']
        ]) {
          dir('terraform/Terraform Manifest/eks') {
            script {
              if (params.ACTION == 'apply') {
                sh 'terraform apply -auto-approve tfplan'
              } else {
                sh 'terraform destroy -auto-approve'
              }
            }
          }
        }
      }
    }

    /* =====================================================
       KUBECTL CONFIG + DEPLOY
    ===================================================== */

    stage('Configure kubectl') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        sh '''
          aws eks update-kubeconfig \
            --region ${AWS_REGION} \
            --name ${CLUSTER_NAME}
        '''
      }
    }

    stage('Deploy Application to EKS') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        sh '''
          kubectl apply -f k8s/
          kubectl set image deployment/demo-app \
            demo=${IMAGE_NAME}:${IMAGE_TAG} --record || true
        '''
      }
    }
  }

  post {
    success {
      echo "CI + VPC + EKS pipeline completed successfully!"
    }
    failure {
      echo "Pipeline failed. Check logs."
    }
    cleanup {
      cleanWs()
    }
  }
}
