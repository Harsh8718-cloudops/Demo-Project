pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    choice(
      name: 'ACTION',
      choices: ['apply'],
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
    SONAR_HOME = tool "Sonar"
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
                  sh '''
                    set -euo pipefail
                    trivy fs .
                    '''
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
                    sh '''
                    set -euo pipefail
                    $SONAR_HOME/bin/sonar-scanner -Dsonar.projectName=${Projectname} -Dsonar.projectKey=${ProjectKey} -X
                    '''
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
      
      steps {
        dir('app') {
          sh '''
            set -euo pipefail
            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          '''
        }
      }
    }

    stage('Push Docker Image') {
      
      steps {
        withCredentials([
          usernamePassword(
            credentialsId: 'dockerhub-creds',
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS'
          )
        ]) {
          sh '''
            set -euo pipefail
            docker login -u ${DOCKER_USER} --password-stdin <<< "${DOCKER_PASS}"
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
          '''
        }
      }
    }

  

    stage('Terraform Init') {
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding',
           credentialsId: 'aws-creds']
        ]) {
          dir('terraform/Terraform Manifest/vpc') {
            sh "set -euo pipefail"
            sh 'terraform init -input=false'
          }
        }
      }
    }

    /* =====================================================
       VPC : PLAN
    ===================================================== */

    stage('Terraform Plan') {
     
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding',
           credentialsId: 'aws-creds']
        ]) {
          dir('terraform/Terraform Manifest/vpc') {
            sh '''
              set -euo pipefail
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

    stage('Manual Approval') {
      when {
        
          expression { !params.AUTO_APPROVE }
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

    stage('Terraform Apply') {
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding',
           credentialsId: 'aws-creds']
        ]) {
          dir('terraform/Terraform Manifest/vpc') {
            script {
             
                sh '''
                 set -euo pipefail
                 terraform apply -auto-approve tfplan
                '''
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
          set -euo pipefail
          aws eks update-kubeconfig \
            --region ${AWS_REGION} \
            --name ${CLUSTER_NAME}
        '''
      }
    }

    stage('Deploy Application to EKS') {
      steps {
        sh '''
          set -euo pipefail
          kubectl apply -f k8s/
          kubectl set image deployment/demo-app \
            demo=${IMAGE_NAME}:${IMAGE_TAG}
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
