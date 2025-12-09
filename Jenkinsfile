pipeline {
  agent { label 'build' }

  environment { 
    registry = "mxr087/gova4all" 
    registryCredential = 'dockerhub'
  }

  stages {

    stage('Checkout') {
      steps {
        git branch: 'main',
            credentialsId: 'gova_jenkins',
            url: 'https://github.com/gova4all/springboot-build-pipeline.git'
      }
    }

    stage('Stage I: Build') {
      steps {
        echo "Building Jar Component ..."
        sh """
           export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
           mvn clean package
        """
      }
    }

    stage('Stage II: Code Coverage') {
      steps {
        echo "Running Code Coverage ..."
        sh """
           export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
           mvn jacoco:report
        """
      }
    }
  stage('Stage III: SCA') {
    steps { 
        echo "Running Software Composition Analysis ..."

        sh """
            export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
            mvn org.owasp:dependency-check-maven:check \
                -Danalyzer.nvd.api.enabled=false \
                -Danalyzer.nvd.api.fetch=false \
                -Danalyzer.nvd.api.failOnError=false \
                -DnvdApiEnabled=false \
                -DfailOnError=false
        """
    }
}


    stage('Stage IV: SAST') {
      steps { 
        echo "Running Static Application Security Testing (SonarQube)..."
        withCredentials([string(credentialsId: 'SonarQube_Creds', variable: 'SONAR_TOKEN')]) {
          withSonarQubeEnv('mysonarqube') {

            sh '''
              mvn sonar:sonar \
                -Dsonar.projectKey=wezvatech \
                -Dsonar.projectName=wezvatech \
                -Dsonar.login=$SONAR_TOKEN \
                -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                -Dsonar.dependencyCheck.jsonReportPath=target/dependency-check-report.json \
                -Dsonar.dependencyCheck.htmlReportPath=target/dependency-check-report.html
            '''
          }
        }
      }
    }

    stage('Stage V: Quality Gates') {
      steps {
        echo "Running Quality Gates ..."
        script {
          timeout(time: 1, unit: 'MINUTES') {
            def qg = waitForQualityGate()
            if (qg.status != 'OK') {
              error "Pipeline aborted due to Quality Gate failure: ${qg.status}"
            }
          }
        }
      }
    }

    stage('Stage VI: Build Image') {
      steps {
        echo "Building Docker Image..."
        script {
          docker.withRegistry('', registryCredential) {
            def myImage = docker.build(registry)
            myImage.push()
          }
        }
      }
    }

    stage('Stage VII: Scan Image') {
      steps {
        echo "Scanning Image for Vulnerabilities..."
        sh "trivy image --scanners vuln --offline-scan mxr087/gova4all:latest > trivyresults.txt"
      }
    }

    stage('Stage VIII: Smoke Test') {
      steps {
        echo "Running Smoke Test..."
        sh """
          docker run -d --name smokerun -p 8080:8080 mxr087/gova4all:latest
          sleep 90
          ./check.sh
          docker rm --force smokerun
        """
      }
    }

    /* -------------------------------------------------------------
       NEW STAGE IX – Build & Push Image to AWS ECR
       ------------------------------------------------------------- */
    stage('Stage IX: Push Image to AWS ECR') {
      environment {
        AWS_REGION = "us-east-1"
        AWS_ACCOUNT = "494249241115"
        ECR_REPO = "gova4all"
      }
      steps {
        echo "Pushing Image to AWS ECR..."
        withAWS(credentials: 'AWS_CREDS', region: "${AWS_REGION}") {
          sh """
            aws ecr get-login-password --region ${AWS_REGION} \
            | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com

            docker tag mxr087/gova4all:latest ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest

            docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest
          """
        }
      }
    }

    /* -------------------------------------------------------------
       NEW STAGE X – Deploy to EC2
       ------------------------------------------------------------- */
stage('Stage X: Deploy to EC2 Instance') {
    environment {
        AWS_REGION = "ap-south-1"
        AWS_ACCOUNT = "123456789012"
        ECR_REPO = "gova4all"
        EC2_USER = "ubuntu"
        EC2_HOST = "10.10.10.10"
    }
    steps {
        echo "Deploying Docker Container to EC2 using sshCommand..."

        sshCommand remote: [
            host: "${EC2_HOST}",
            user: "${EC2_USER}",
            identityFile: "/var/lib/jenkins/.ssh/id_rsa",   // <-- your private key path
            allowAnyHosts: true
        ], command: """
            aws ecr get-login-password --region ${AWS_REGION} \
            | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com

            docker pull ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest

            docker stop gova4all || true
            docker rm gova4all || true

            docker run -d --name gova4all -p 8080:8080 \
            ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest
        """
    }
}

  } // stages end
}
