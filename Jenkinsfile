pipeline {
    agent any

    environment {
        DEPLOY_DIR = '/var/jenkins_home/workspace/flutter-deploy'
        PUB_CACHE_VOL = 'flutter_pub_cache'
    }

    stages {
        stage('Install') {
            steps {
                sh 'docker run --rm -v $PWD:/app -v ${PUB_CACHE_VOL}:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:stable flutter pub get'
            }
        }

        stage('Analyze') {
            steps {
                sh 'docker run --rm -v $PWD:/app -v ${PUB_CACHE_VOL}:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:stable flutter analyze --no-fatal-warnings --no-fatal-infos'
            }
        }

        stage('Test') {
            steps {
                sh 'docker run --rm -v $PWD:/app -v ${PUB_CACHE_VOL}:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:stable flutter test'
            }
        }

        stage('Build & Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh 'docker run --rm -v $PWD:/app -v ${PUB_CACHE_VOL}:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:stable flutter build web --release'
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