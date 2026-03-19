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
                    // Restitue la propriété de build/ au user Jenkins.
                    // stat tourne DANS le conteneur (où /app est monté),
                    // pas sur l'hôte Jenkins où /app n'existe pas.
                    sh """
                        docker run --rm \
                            -v ${HOST_WORKSPACE}/flutter-app:/app \
                            alpine \
                            sh -c 'OWNER=\$(stat -c "%u:%g" /app) && chown -R \$OWNER /app/build 2>/dev/null || true'
                    """
                }
            }
        }

        // ── 4. Flutter : Build & Deploy (main → prod) ─────────────────────────
        // La copie se fait via Docker (root sur l'hôte) car le conteneur
        // Jenkins ne monte pas /var/www et n'a pas les droits d'y écrire.
        stage('Flutter Build & Deploy PROD') {
            when { branch 'main' }
            steps {
                sh """
                    docker run --rm \
                        -v ${HOST_WORKSPACE}/flutter-app:/app \
                        -e PUB_CACHE=/app/.pub-cache \
                        -w /app \
                        ${FLUTTER_IMAGE} \
                        flutter build web --release \
                            --dart-define=AUTH_URL=https://auth.lucaslopvet.fr \
                            --dart-define=DB_URL=https://DB.lucaslopvet.fr

                    docker run --rm \
                        -v ${HOST_WORKSPACE}/flutter-app/build/web:/src \
                        -v ${DEPLOY_DIR_PROD}:/dst \
                        alpine \
                        sh -c "rm -rf /dst/* && cp -r /src/. /dst/ && chown -R 1000:1000 /dst"
                """
            }
        }

        // ── 5. Flutter : Build & Deploy (dev → dev) ───────────────────────────
        stage('Flutter Build & Deploy DEV') {
            when { branch 'dev' }
            steps {
                sh """
                    docker run --rm \
                        -v ${HOST_WORKSPACE}/flutter-app:/app \
                        -e PUB_CACHE=/app/.pub-cache \
                        -w /app \
                        ${FLUTTER_IMAGE} \
                        flutter build web --release \
                            --dart-define=AUTH_URL=https://dev.auth.lucaslopvet.fr \
                            --dart-define=DB_URL=https://dev.DB.lucaslopvet.fr

                    docker run --rm \
                        -v ${HOST_WORKSPACE}/flutter-app/build/web:/src \
                        -v ${DEPLOY_DIR_DEV}:/dst \
                        alpine \
                        sh -c "rm -rf /dst/* && cp -r /src/. /dst/ && chown -R 1000:1000 /dst"
                """
            }
        }

        // ── 6. Docker : Build & démarrer services (main → prod) ───────────────
        stage('Services Deploy PROD') {
            when {
                allOf {
                    branch 'main'
                    expression { fileExists("${WORKSPACE}/docker-compose.yml") }
                }
            }
            steps {
                sh """
                    [ -f /etc/kabutare/.env ] && export \$(grep -v '^#' /etc/kabutare/.env | xargs) || true
                    docker-compose -p gestion-equipement-medical-prod -f ${WORKSPACE}/docker-compose.yml pull 2>/dev/null || true
                    docker-compose -p gestion-equipement-medical-prod -f ${WORKSPACE}/docker-compose.yml up -d --build
                    docker exec auth-service-prod node seed.js 2>/dev/null || true
                    docker exec db-service-prod  node seed.js 2>/dev/null || true
                """
            }
        }

        // ── 7. Docker : Build & démarrer services (dev) ───────────────────────
        stage('Services Deploy DEV') {
            when {
                allOf {
                    branch 'dev'
                    expression { fileExists("${WORKSPACE}/docker-compose.dev.yml") }
                }
            }
            steps {
                sh """
                    [ -f /etc/kabutare/.env ] && export \$(grep -v '^#' /etc/kabutare/.env | xargs) || true
                    docker-compose -p gestion-equipement-medical-dev -f ${WORKSPACE}/docker-compose.dev.yml pull 2>/dev/null || true
                    docker-compose -p gestion-equipement-medical-dev -f ${WORKSPACE}/docker-compose.dev.yml up -d --build
                    docker exec auth-service-dev node seed.js 2>/dev/null || true
                    docker exec db-service-dev  node seed.js 2>/dev/null || true
                """
            }
        }

        // ── 8. Healthcheck ────────────────────────────────────────────────────
        stage('Healthcheck') {
            when {
                expression {
                    fileExists("${WORKSPACE}/docker-compose.yml") ||
                    fileExists("${WORKSPACE}/docker-compose.dev.yml")
                }
            }
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
