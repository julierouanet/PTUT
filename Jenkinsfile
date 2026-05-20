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
                        -v ${HOST_WORKSPACE}:/ws \
                        alpine \
                        sh -c 'OWNER=\$(stat -c "%u:%g" /ws) && chown -R \$OWNER /ws && rm -rf /ws/flutter-app/build /ws/flutter-app/.pub-cache'
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
                            --dart-define=DB_URL=https://DB.lucaslopvet.fr \
                            --dart-define=KC_TOKEN_URL=https://keycloak.lucaslopvet.fr/realms/kabutare-hospital/protocol/openid-connect/token

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
                            --dart-define=DB_URL=https://dev.DB.lucaslopvet.fr \
                            --dart-define=KC_TOKEN_URL=https://keycloak.lucaslopvet.fr/realms/kabutare-hospital/protocol/openid-connect/token

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
                    docker-compose -p gestion-equipement-medical-prod -f ${WORKSPACE}/docker-compose.yml down --remove-orphans 2>/dev/null || true
                    docker-compose -p gestion-equipement-medical-prod -f ${WORKSPACE}/docker-compose.yml pull 2>/dev/null || true
                    docker-compose -p gestion-equipement-medical-prod -f ${WORKSPACE}/docker-compose.yml up -d --build --force-recreate
                    # Attendre que Keycloak PROD soit prêt (jusqu'à 120s)
                    timeout 120 sh -c 'until docker exec keycloak-prod sh -c "exec 3<>/dev/tcp/localhost/9000 && echo -e \"GET /health/ready HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n\" >&3 && cat <&3 | grep -q UP" 2>/dev/null; do sleep 5; done' || true
                    # Initialisation idempotente du realm Keycloak (no-op si déjà configuré)
                    docker exec \
                        -e KC_ADMIN_URL=http://keycloak-prod:8080 \
                        -e KC_ADMIN_USER=\${KC_ADMIN_USER:-admin} \
                        -e KC_ADMIN_PASSWORD=\${KC_ADMIN_PASSWORD} \
                        auth-service-prod \
                        node scripts/keycloak-init.js 2>/dev/null || true
                    # Seed des comptes de démonstration dans Keycloak (idempotent)
                    docker exec \
                        -e KC_ADMIN_URL=http://keycloak-prod:8080 \
                        -e KC_ADMIN_USER=\${KC_ADMIN_USER:-admin} \
                        -e KC_ADMIN_PASSWORD=\${KC_ADMIN_PASSWORD} \
                        auth-service-prod \
                        node scripts/keycloak-seed.js 2>/dev/null || true
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
                    docker rm -f auth-service-dev db-service-dev 2>/dev/null || true
                    docker-compose -p gestion-equipement-medical_dev -f ${WORKSPACE}/docker-compose.dev.yml down --remove-orphans 2>/dev/null || true
                    docker-compose -p gestion-equipement-medical_dev -f ${WORKSPACE}/docker-compose.dev.yml pull 2>/dev/null || true
                    docker-compose -p gestion-equipement-medical_dev -f ${WORKSPACE}/docker-compose.dev.yml up -d --build --force-recreate
                    # Attendre que Keycloak soit prêt avant d'initialiser le realm
                    timeout 120 sh -c 'until docker exec keycloak-dev sh -c "exec 3<>/dev/tcp/localhost/9000 && echo -e \"GET /health/ready HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n\" >&3 && cat <&3 | grep -q UP" 2>/dev/null; do sleep 5; done' || true
                    # Initialisation idempotente du realm Keycloak (no-op si déjà configuré)
                    docker exec auth-service-dev \
                        sh -c 'KC_ADMIN_URL=http://keycloak-dev:8081 KC_ADMIN_USER=admin KC_ADMIN_PASSWORD=admin KC_CLIENT_SECRET_AUTH=\$KC_CLIENT_SECRET node scripts/keycloak-init.js' 2>/dev/null || true
                    # Seed des comptes de démonstration dans Keycloak (idempotent)
                    docker exec auth-service-dev \
                        sh -c 'KC_ADMIN_URL=http://keycloak-dev:8081 KC_ADMIN_USER=admin KC_ADMIN_PASSWORD=admin node scripts/keycloak-seed.js' 2>/dev/null || true
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
