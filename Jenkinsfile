pipeline {
    agent any

    environment {
        DEPLOY_DIR = '/var/www/flutter-app'
        FLUTTER_IMAGE = 'ghcr.io/cirruslabs/flutter:3.41.4'
        HOST_WORKSPACE = "${sh(script: 'echo $WORKSPACE | sed \"s|/var/jenkins_home|/var/lib/docker/volumes/jenkins_home/_data|\"', returnStdout: true).trim()}"
    }

    stages {
        stage('Install') {
            steps {
                sh "docker run --rm -v ${HOST_WORKSPACE}:/app -v flutter_pub_cache:/root/.pub-cache -w /app ${FLUTTER_IMAGE} flutter pub get"
            }
        }

        stage('Analyze') {
            steps {
                sh "docker run --rm -v ${HOST_WORKSPACE}:/app -v flutter_pub_cache:/root/.pub-cache -w /app ${FLUTTER_IMAGE} flutter analyze --no-fatal-infos"
            }
        }

        stage('Test') {
            steps {
                sh "docker run --rm -v ${HOST_WORKSPACE}:/app -v flutter_pub_cache:/root/.pub-cache -w /app ${FLUTTER_IMAGE} flutter test --reporter json > test-results.json || true"
                sh "docker run --rm -v ${HOST_WORKSPACE}:/app -v flutter_pub_cache:/root/.pub-cache -w /app ${FLUTTER_IMAGE} flutter test"
            }
        }

        stage('Build & Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh "docker run --rm -v ${HOST_WORKSPACE}:/app -v flutter_pub_cache:/root/.pub-cache -w /app ${FLUTTER_IMAGE} flutter build web --release"
                sh """
                    DEPLOY_TMP="${DEPLOY_DIR}_tmp_\${BUILD_NUMBER}"
                    cp -r build/web "\$DEPLOY_TMP"
                    rm -rf ${DEPLOY_DIR}
                    mv "\$DEPLOY_TMP" ${DEPLOY_DIR}
                """
            }
        }
    }

    post {
        failure {
            echo '❌ Build échoué'
        }
        success {
            echo '✅ Build réussi'
        }
        always {
            echo "Build #${BUILD_NUMBER} terminé - Branche: ${BRANCH_NAME}"
        }
    }
}