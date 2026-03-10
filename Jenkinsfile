pipeline {
    agent any

    environment {
        DEPLOY_DIR = '/var/www/flutter-app'
        HOST_WORKSPACE = "/var/lib/docker/volumes/jenkins_home/_data/workspace/gestion-equipement-medical_main"
    }

    stages {
        stage('Install') {
            steps {
                sh 'docker run --rm -v ${HOST_WORKSPACE}:/app -v flutter_pub_cache:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:stable flutter pub get'
            }
        }

        stage('Analyze') {
            steps {
                sh 'docker run --rm -v ${HOST_WORKSPACE}:/app -v flutter_pub_cache:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:stable flutter analyze --no-fatal-warnings --no-fatal-infos'
            }
        }

        stage('Test') {
            steps {
                sh 'docker run --rm -v ${HOST_WORKSPACE}:/app -v flutter_pub_cache:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:stable flutter test'
            }
        }

        stage('Build & Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh 'docker run --rm -v ${HOST_WORKSPACE}:/app -v flutter_pub_cache:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:stable flutter build web --release'
                sh "rm -rf ${DEPLOY_DIR}/*"
                sh "cp -r build/web/* ${DEPLOY_DIR}/"
            }
        }
    }

    post {
        failure {
            echo 'Build échoué'
        }
        success {
            echo 'Build réussi'
        }
    }
}