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
    sh """
      export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
      mvn org.owasp:dependency-check-maven:check \
        -Danalyzer.nvd.api.enabled=false \
        -Danalyzer.nvd.api.fetch=false \
        -Danalyzer.nvd.api.failOnError=false \
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
        echo "Running Smoke Test with Auto Port..."

        sh """
            # Remove old container if exists
            docker rm -f smokerun || true

            # Run container with a random free port
            CONTAINER_ID=\$(docker run -d --name smokerun -p 0:8080 mxr087/gova4all:latest)
            echo "Container started: \$CONTAINER_ID"

            # Extract mapped random host port (e.g. 32768)
            PORT=\$(docker port smokerun | sed 's/.*://')
            echo "App is running on port: \$PORT"

            # Run smoke test with dynamic port
            chmod +x ./check.sh
            ./check.sh \$PORT

            # Cleanup the container
            docker rm -f smokerun || true
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
stage('Deploy to EC2') {
    environment {
        AWS_REGION = "us-east-1"
        AWS_ACCOUNT = "494249241115"
        ECR_REPO = "gova4all"
    }

    steps {
            sshCommand remote: [
            name: "EC2",
            host: "ec2-174-129-104-148.compute-1.amazonaws.com",
            user: "ubuntu",
            identityFile: "/var/lib/jenkins/.ssh/Ec2_key.pem",
            allowAnyHosts: true
        ], 
        
        command: """
            set -e

            echo "Logging into AWS ECR..."
            aws ecr get-login-password --region ${AWS_REGION} \
            | sudo docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com

            echo "Pulling latest Docker image..."
            sudo docker pull ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest

            echo "Stopping old container..."
            sudo docker stop gova4all || true
            sudo docker rm gova4all || true

            echo "Starting new container..."
            sudo docker run -d --name gova4all -p 8080:8080 \
            ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest

            echo "Health Check..."
            sleep 5
            sudo curl -fsS http://localhost:8080
        """
    }
}

  } // stages end 
}
