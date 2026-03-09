pipeline {
    agent any

    environment {
        DEPLOY_DIR = '/var/www/flutter-app'
    }

    stages {
        stage('Install') {
            steps {
                sh 'docker run --rm -v $PWD:/app -w /app ghcr.io/cirruslabs/flutter:stable flutter pub get'
            }
        }

        stage('Analyze') {
            steps {
                sh 'docker run --rm -v $PWD:/app -w /app ghcr.io/cirruslabs/flutter:stable flutter analyze'
            }
        }

        stage('Test') {
            steps {
                sh 'docker run --rm -v $PWD:/app -w /app ghcr.io/cirruslabs/flutter:stable flutter test'
            }
        }

        stage('Build & Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh 'docker run --rm -v $PWD:/app -w /app ghcr.io/cirruslabs/flutter:stable flutter build web --release'
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