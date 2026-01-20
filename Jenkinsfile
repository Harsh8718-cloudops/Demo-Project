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

    stage('Build Docker Image') {
      steps {
        dir('app') {
          sh """
            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          """
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
          sh """
            echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER} --password-stdin
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
          """
        }
      }
    }

    stage('Terraform Init') {
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding',
           credentialsId: 'aws-creds']
        ]) {
          dir('terraform') {
            sh 'terraform init -input=false'
          }
        }
      }
    }

    stage('Terraform Plan') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding',
           credentialsId: 'aws-creds']
        ]) {
        dir('terraform') {
          sh """
            terraform plan -out=tfplan
            terraform show -no-color tfplan > tfplan.txt
          """
        }
      }
    }
    }

    stage('Manual Approval') {
      when {
        allOf {
          expression { params.ACTION == 'apply' }
          expression { !params.AUTO_APPROVE }
        }
      }
      steps {
        input message: 'Approve Terraform Apply?',
              parameters: [
                text(
                  name: 'Terraform Plan',
                  defaultValue: readFile('terraform/tfplan.txt')
                )
              ]
      }
    }

    stage('Terraform Apply / Destroy') {
      steps {
         withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding',
           credentialsId: 'aws-creds']
        ]) {
        dir('terraform') {
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

    stage('Configure kubectl') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        sh """
          aws eks update-kubeconfig \
            --region ${AWS_REGION} \
            --name ${CLUSTER_NAME}
        """
      }
    }

    stage('Deploy to EKS') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        sh """
          kubectl set image deployment/demo-app \
            demo=${IMAGE_NAME}:${IMAGE_TAG} --record
          kubectl apply -f k8s/
        """
      }
    }
  }

  post {
    success {
      echo "Pipeline completed successfully!"
    }
    failure {
      echo "Pipeline failed. Please check logs."
    }
    cleanup {
      cleanWs()
    }
  }
}
