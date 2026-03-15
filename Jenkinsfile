pipeline {
    agent any

    options {
        skipDefaultCheckout(true)   // on gère le checkout manuellement
    }

    environment {
        FLUTTER_IMAGE   = 'ghcr.io/cirruslabs/flutter:3.41.4'
        HOST_WORKSPACE  = "${sh(script: 'echo $WORKSPACE | sed "s|/var/jenkins_home|/var/lib/docker/volumes/jenkins_home/_data|"', returnStdout: true).trim()}"

        DEPLOY_DIR_PROD = '/var/www/flutter-app'
        DEPLOY_DIR_DEV  = '/var/www/flutter-app-dev'

        IS_MAIN = "${env.BRANCH_NAME == 'main' ? 'true' : 'false'}"
        IS_DEV  = "${env.BRANCH_NAME == 'dev'  ? 'true' : 'false'}"
    }

    stages {

        // ── 0. Cleanup puis Checkout ──────────────────────────────────────────
        // Supprime build/ (root-owned par Docker) AVANT que git checkout -f
        // tente de toucher ces fichiers. Sans skipDefaultCheckout(true) +
        // ce stage, Jenkins planterait au checkout automatique.
        stage('Cleanup & Checkout') {
            steps {
                sh """
                    docker run --rm \
                        -v ${HOST_WORKSPACE}/flutter-app:/app \
                        alpine \
                        sh -c "rm -rf /app/build /app/.pub-cache"
                """
                checkout scm
            }
        }

        // ── 1. Flutter : Install ──────────────────────────────────────────────
        stage('Flutter Install') {
            steps {
                dir('flutter-app') {
                    sh """
                        docker run --rm \
                            -v ${HOST_WORKSPACE}/flutter-app:/app \
                            -e PUB_CACHE=/app/.pub-cache \
                            -w /app \
                            ${FLUTTER_IMAGE} \
                            flutter pub get
                    """
                }
            }
        }

        // ── 2. Flutter : Analyze ──────────────────────────────────────────────
        stage('Flutter Analyze') {
            steps {
                dir('flutter-app') {
                    sh """
                        docker run --rm \
                            -v ${HOST_WORKSPACE}/flutter-app:/app \
                            -e PUB_CACHE=/app/.pub-cache \
                            -w /app \
                            ${FLUTTER_IMAGE} \
                            flutter analyze --no-fatal-infos
                    """
                }
            }
        }

        // ── 3. Flutter : Test ─────────────────────────────────────────────────
        stage('Flutter Test') {
            steps {
                dir('flutter-app') {
                    sh """
                        docker run --rm \
                            -v ${HOST_WORKSPACE}/flutter-app:/app \
                            -e PUB_CACHE=/app/.pub-cache \
                            -w /app \
                            ${FLUTTER_IMAGE} \
                            flutter test
                    """
                }
            }
            post {
                always {
                    // Restitue la propriété de build/ au user Jenkins
                    // pour que git checkout ne plante pas au prochain build.
                    sh """
                        docker run --rm \
                            -v ${HOST_WORKSPACE}/flutter-app:/app \
                            alpine \
                            sh -c "chown -R \$(stat -c '%u:%g' /app) /app/build 2>/dev/null || true"
                    """
                }
            }
        }

        // ── 4. Flutter : Build & Deploy (main → prod) ─────────────────────────
        stage('Flutter Build & Deploy PROD') {
            when { branch 'main' }
            steps {
                dir('flutter-app') {
                    sh """
                        docker run --rm \
                            -v ${HOST_WORKSPACE}/flutter-app:/app \
                            -e PUB_CACHE=/app/.pub-cache \
                            -w /app \
                            ${FLUTTER_IMAGE} \
                            flutter build web --release \
                                --dart-define=AUTH_URL=https://auth.lucaslopvet.fr \
                                --dart-define=DB_URL=https://DB.lucaslopvet.fr

                        mkdir -p ${DEPLOY_DIR_PROD}
                        rm -rf ${DEPLOY_DIR_PROD}/*
                        cp -r build/web/* ${DEPLOY_DIR_PROD}/
                    """
                }
            }
        }

        // ── 5. Flutter : Build & Deploy (dev → dev) ───────────────────────────
        stage('Flutter Build & Deploy DEV') {
            when { branch 'dev' }
            steps {
                dir('flutter-app') {
                    sh """
                        docker run --rm \
                            -v ${HOST_WORKSPACE}/flutter-app:/app \
                            -e PUB_CACHE=/app/.pub-cache \
                            -w /app \
                            ${FLUTTER_IMAGE} \
                            flutter build web --release \
                                --dart-define=AUTH_URL=https://dev.auth.lucaslopvet.fr \
                                --dart-define=DB_URL=https://dev.DB.lucaslopvet.fr

                        mkdir -p ${DEPLOY_DIR_DEV}
                        rm -rf ${DEPLOY_DIR_DEV}/*
                        cp -r build/web/* ${DEPLOY_DIR_DEV}/
                    """
                }
            }
        }

        // ── 6. Docker : Build & démarrer services (main → prod) ───────────────
        stage('Services Deploy PROD') {
            when { branch 'main' }
            steps {
                sh """
                    cd /var/lib/docker/volumes/jenkins_home/_data/workspace/${env.JOB_NAME}
                    export \$(grep -v '^#' /etc/kabutare/.env | xargs)
                    docker compose -f docker-compose.yml pull 2>/dev/null || true
                    docker compose -f docker-compose.yml up -d --build
                    docker exec auth-service-prod node seed.js 2>/dev/null || true
                    docker exec db-service-prod  node seed.js 2>/dev/null || true
                """
            }
        }

        // ── 7. Docker : Build & démarrer services (dev) ───────────────────────
        stage('Services Deploy DEV') {
            when { branch 'dev' }
            steps {
                sh """
                    cd /var/lib/docker/volumes/jenkins_home/_data/workspace/${env.JOB_NAME}
                    export \$(grep -v '^#' /etc/kabutare/.env | xargs)
                    docker compose -f docker-compose.dev.yml pull 2>/dev/null || true
                    docker compose -f docker-compose.dev.yml up -d --build
                    docker exec auth-service-dev node seed.js 2>/dev/null || true
                    docker exec db-service-dev  node seed.js 2>/dev/null || true
                """
            }
        }

        // ── 8. Healthcheck ────────────────────────────────────────────────────
        stage('Healthcheck') {
            steps {
                script {
                    if (env.BRANCH_NAME == 'main') {
                        sh """
                            sleep 5
                            curl -sf https://auth.lucaslopvet.fr/health || (echo 'auth-service PROD KO' && exit 1)
                            curl -sf https://DB.lucaslopvet.fr/health   || (echo 'db-service PROD KO'  && exit 1)
                            echo 'Tous les services PROD sont opérationnels'
                        """
                    } else if (env.BRANCH_NAME == 'dev') {
                        sh """
                            sleep 5
                            curl -sf https://dev.auth.lucaslopvet.fr/health || (echo 'auth-service DEV KO' && exit 1)
                            curl -sf https://dev.DB.lucaslopvet.fr/health   || (echo 'db-service DEV KO'  && exit 1)
                            echo 'Tous les services DEV sont opérationnels'
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                def env_label = (env.BRANCH_NAME == 'main') ? 'PRODUCTION' : 'DEV'
                echo "✅ Pipeline ${env_label} terminé avec succès — branche: ${env.BRANCH_NAME}"
            }
        }
        failure {
            echo "❌ Pipeline échoué — branche: ${env.BRANCH_NAME}"
        }
    }
}
