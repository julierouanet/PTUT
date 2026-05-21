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
                script {
                    def commitCount = sh(script: 'git rev-list --count HEAD', returnStdout: true).trim()
                    def appVersion  = "1.0.${commitCount}"
                    echo "Version PROD : ${appVersion}"
                    sh """
                    docker run --rm \
                        -v ${HOST_WORKSPACE}/flutter-app:/app \
                        -e PUB_CACHE=/app/.pub-cache \
                        -w /app \
                        ${FLUTTER_IMAGE} \
                        flutter build web --release \
                            --dart-define=AUTH_URL=https://auth.lucaslopvet.fr \
                            --dart-define=DB_URL=https://DB.lucaslopvet.fr \
                            --dart-define=KC_TOKEN_URL=https://keycloak.lucaslopvet.fr/realms/kabutare-hospital/protocol/openid-connect/token \
                            --dart-define=APP_VERSION=${appVersion}

                    # ── Fusion push_sw.js dans le SW Flutter généré ───────────────────
                    # Flutter génère flutter_service_worker.js et appelle skipWaiting(),
                    # ce qui écrase push_sw.js. On injecte nos handlers push directement
                    # dans le SW Flutter pour que les notifications arrivent même appli fermée.
                    docker run --rm \
                        -v ${HOST_WORKSPACE}/flutter-app:/app \
                        alpine \
                        sh -c 'printf "\\n/* === Web Push Handlers (injecté par CI) === */\\n" >> /app/build/web/flutter_service_worker.js && cat /app/web/push_sw.js >> /app/build/web/flutter_service_worker.js'

                    docker run --rm \
                        -v ${HOST_WORKSPACE}/flutter-app/build/web:/src \
                        -v ${DEPLOY_DIR_PROD}:/dst \
                        alpine \
                        sh -c "rm -rf /dst/* && cp -r /src/. /dst/ && chown -R 1000:1000 /dst"
                """
                }
            }
        }

        // ── 5. Flutter : Build & Deploy (dev → dev) ───────────────────────────
        stage('Flutter Build & Deploy DEV') {
            when { branch 'dev' }
            steps {
                script {
                    def commitCount = sh(script: 'git rev-list --count HEAD', returnStdout: true).trim()
                    def appVersion  = "1.0.${commitCount}-dev"
                    echo "Version DEV : ${appVersion}"
                    sh """
                    docker run --rm \
                        -v ${HOST_WORKSPACE}/flutter-app:/app \
                        -e PUB_CACHE=/app/.pub-cache \
                        -w /app \
                        ${FLUTTER_IMAGE} \
                        flutter build web --release \
                            --dart-define=AUTH_URL=https://dev.auth.lucaslopvet.fr \
                            --dart-define=DB_URL=https://dev.DB.lucaslopvet.fr \
                            --dart-define=KC_TOKEN_URL=https://keycloak.lucaslopvet.fr/realms/kabutare-hospital/protocol/openid-connect/token \
                            --dart-define=APP_VERSION=${appVersion}

                    # ── Fusion push_sw.js dans le SW Flutter généré ───────────────────
                    docker run --rm \
                        -v ${HOST_WORKSPACE}/flutter-app:/app \
                        alpine \
                        sh -c 'printf "\\n/* === Web Push Handlers (injecté par CI) === */\\n" >> /app/build/web/flutter_service_worker.js && cat /app/web/push_sw.js >> /app/build/web/flutter_service_worker.js'

                    docker run --rm \
                        -v ${HOST_WORKSPACE}/flutter-app/build/web:/src \
                        -v ${DEPLOY_DIR_DEV}:/dst \
                        alpine \
                        sh -c "rm -rf /dst/* && cp -r /src/. /dst/ && chown -R 1000:1000 /dst"
                """
                }
            }
        }

        // ── 6. Docker Hub : Build & Push images (main uniquement) ───────────────
        // Pré-requis Jenkins : credential de type "Username with password"
        //   ID = dockerhub-credentials  (Jenkins → Credentials → Global)
        stage('Docker Hub Push') {
            when { branch 'main' }
            steps {
                script {
                    def commitCount = sh(script: 'git rev-list --count HEAD', returnStdout: true).trim()
                    def versionTag  = "1.0.${commitCount}"

                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_PASS'
                    )]) {
                        sh """
                            echo "\$DOCKERHUB_PASS" | docker login -u "\$DOCKERHUB_USER" --password-stdin

                            for SERVICE in auth-service db-service keycloak; do
                                IMAGE="\$DOCKERHUB_USER/kabutare-\${SERVICE}"
                                docker build --platform linux/amd64 \
                                    -t "\${IMAGE}:latest" \
                                    -t "\${IMAGE}:${versionTag}" \
                                    ./\${SERVICE}
                                docker push "\${IMAGE}:latest"
                                docker push "\${IMAGE}:${versionTag}"
                                echo "✓ \${IMAGE}:latest et :\${versionTag} poussés"
                            done

                            docker logout
                        """
                    }
                }
            }
        }

        // ── 7. Docker : Build & démarrer services (main → prod) ───────────────
        stage('Services Deploy PROD') {
            when {
                allOf {
                    branch 'main'
                    expression { fileExists("${WORKSPACE}/docker-compose.yml") }
                }
            }
            steps {
                sh """
                    # Copie /etc/kabutare/.env (host) dans le workspace via Docker
                    docker run --rm \
                        -v /etc/kabutare:/kabutare:ro \
                        -v ${HOST_WORKSPACE}:/out \
                        alpine sh -c "cp /kabutare/.env /out/.env.kabutare.tmp"
                    docker-compose -p gestion-equipement-medical-prod -f ${WORKSPACE}/docker-compose.yml --env-file ${WORKSPACE}/.env.kabutare.tmp down --remove-orphans 2>/dev/null || true
                    docker-compose -p gestion-equipement-medical-prod -f ${WORKSPACE}/docker-compose.yml --env-file ${WORKSPACE}/.env.kabutare.tmp pull 2>/dev/null || true
                    docker-compose -p gestion-equipement-medical-prod -f ${WORKSPACE}/docker-compose.yml --env-file ${WORKSPACE}/.env.kabutare.tmp up -d --build --force-recreate
                    # Attendre que Keycloak PROD soit prêt (jusqu'à 120s)
                    timeout 120 sh -c 'until docker exec keycloak-prod sh -c "exec 3<>/dev/tcp/localhost/9000 && echo -e \"GET /health/ready HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n\" >&3 && cat <&3 | grep -q UP" 2>/dev/null; do sleep 5; done' || true
                    # Thème email + options realm (forgot password, loginWithEmail)
                    docker exec keycloak-prod bash /opt/keycloak/scripts/configure-realm.sh 2>/dev/null || true
                    # Configuration SMTP Brevo via API REST (kcadm ne supporte pas smtpServer)
                    BREVO_HOST=\$(grep '^BREVO_SMTP_HOST=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    BREVO_PORT=\$(grep '^BREVO_SMTP_PORT=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    BREVO_LOGIN=\$(grep '^BREVO_SMTP_LOGIN=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    BREVO_PASS=\$(grep '^BREVO_SMTP_PASSWORD=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    BREVO_FROM=\$(grep '^BREVO_FROM_EMAIL=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    BREVO_NAME=\$(grep '^BREVO_FROM_NAME=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    KC_ADMIN_USER_VAL=\$(grep '^KC_ADMIN_USER=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    KC_ADMIN_PASS_VAL=\$(grep '^KC_ADMIN_PASSWORD=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    KC_TOKEN=\$(docker run --rm --network host curlimages/curl:latest -sf \
                        --data "client_id=admin-cli&username=\${KC_ADMIN_USER_VAL}&password=\${KC_ADMIN_PASS_VAL}&grant_type=password" \
                        'http://localhost:8080/realms/master/protocol/openid-connect/token' \
                        | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
                    [ -n "\$KC_TOKEN" ] && docker run --rm --network host curlimages/curl:latest -sf -X PUT \
                        -H "Authorization: Bearer \$KC_TOKEN" \
                        -H 'Content-Type: application/json' \
                        --data-raw "{\"smtpServer\":{\"host\":\"\$BREVO_HOST\",\"port\":\"\$BREVO_PORT\",\"from\":\"\$BREVO_FROM\",\"fromDisplayName\":\"\$BREVO_NAME\",\"replyTo\":\"\$BREVO_FROM\",\"auth\":\"true\",\"starttls\":\"true\",\"ssl\":\"false\",\"user\":\"\$BREVO_LOGIN\",\"password\":\"\$BREVO_PASS\"}}" \
                        'http://localhost:8080/admin/realms/kabutare-hospital' \
                        && echo '[KC-SMTP] SMTP Brevo configuré.' || echo '[KC-SMTP] AVERTISSEMENT: SMTP non configuré'
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

        // ── 8. Docker : Build & démarrer services (dev) ───────────────────────
        stage('Services Deploy DEV') {
            when {
                allOf {
                    branch 'dev'
                    expression { fileExists("${WORKSPACE}/docker-compose.dev.yml") }
                }
            }
            steps {
                sh """
                    # Copie /etc/kabutare/.env (host) dans le workspace via Docker
                    docker run --rm \
                        -v /etc/kabutare:/kabutare:ro \
                        -v ${HOST_WORKSPACE}:/out \
                        alpine sh -c "cp /kabutare/.env /out/.env.kabutare.tmp"
                    docker rm -f auth-service-dev db-service-dev 2>/dev/null || true
                    docker-compose -p gestion-equipement-medical_dev -f ${WORKSPACE}/docker-compose.dev.yml --env-file ${WORKSPACE}/.env.kabutare.tmp down --remove-orphans 2>/dev/null || true
                    docker-compose -p gestion-equipement-medical_dev -f ${WORKSPACE}/docker-compose.dev.yml --env-file ${WORKSPACE}/.env.kabutare.tmp pull 2>/dev/null || true
                    docker-compose -p gestion-equipement-medical_dev -f ${WORKSPACE}/docker-compose.dev.yml --env-file ${WORKSPACE}/.env.kabutare.tmp up -d --build --force-recreate
                    # Attendre que Keycloak soit prêt avant d'initialiser le realm
                    timeout 120 sh -c 'until docker exec keycloak-dev sh -c "exec 3<>/dev/tcp/localhost/9000 && echo -e \"GET /health/ready HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n\" >&3 && cat <&3 | grep -q UP" 2>/dev/null; do sleep 5; done' || true
                    # Thème email + options realm (forgot password, loginWithEmail)
                    docker exec keycloak-dev bash /opt/keycloak/scripts/configure-realm.sh 2>/dev/null || true
                    # Configuration SMTP Brevo via API REST (kcadm ne supporte pas smtpServer)
                    # curlimages/curl avec --network host atteint localhost:8081 du VPS
                    BREVO_HOST=\$(grep '^BREVO_SMTP_HOST=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    BREVO_PORT=\$(grep '^BREVO_SMTP_PORT=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    BREVO_LOGIN=\$(grep '^BREVO_SMTP_LOGIN=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    BREVO_PASS=\$(grep '^BREVO_SMTP_PASSWORD=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    BREVO_FROM=\$(grep '^BREVO_FROM_EMAIL=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    BREVO_NAME=\$(grep '^BREVO_FROM_NAME=' ${WORKSPACE}/.env.kabutare.tmp | cut -d= -f2-)
                    KC_TOKEN=\$(docker run --rm --network host curlimages/curl:latest -sf \
                        --data 'client_id=admin-cli&username=admin&password=admin&grant_type=password' \
                        'http://localhost:8081/realms/master/protocol/openid-connect/token' \
                        | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
                    [ -n "\$KC_TOKEN" ] && docker run --rm --network host curlimages/curl:latest -sf -X PUT \
                        -H "Authorization: Bearer \$KC_TOKEN" \
                        -H 'Content-Type: application/json' \
                        --data-raw "{\"smtpServer\":{\"host\":\"\$BREVO_HOST\",\"port\":\"\$BREVO_PORT\",\"from\":\"\$BREVO_FROM\",\"fromDisplayName\":\"\$BREVO_NAME\",\"replyTo\":\"\$BREVO_FROM\",\"auth\":\"true\",\"starttls\":\"true\",\"ssl\":\"false\",\"user\":\"\$BREVO_LOGIN\",\"password\":\"\$BREVO_PASS\"}}" \
                        'http://localhost:8081/admin/realms/kabutare-hospital' \
                        && echo '[KC-SMTP] SMTP Brevo configuré.' || echo '[KC-SMTP] AVERTISSEMENT: SMTP non configuré'
                    # Initialisation idempotente du realm Keycloak (no-op si déjà configuré)
                    docker exec auth-service-dev \
                        sh -c 'KC_ADMIN_URL=http://keycloak-dev:8081 KC_ADMIN_USER=admin KC_ADMIN_PASSWORD=admin KC_CLIENT_SECRET_AUTH=\$KC_CLIENT_SECRET node scripts/keycloak-init.js' 2>/dev/null || true
                    # Seed des comptes de démonstration dans Keycloak (idempotent)
                    docker exec auth-service-dev \
                        sh -c 'KC_ADMIN_URL=http://keycloak-dev:8081 KC_ADMIN_USER=admin KC_ADMIN_PASSWORD=admin node scripts/keycloak-seed.js' 2>/dev/null || true
                """
            }
        }

        // ── 9. Healthcheck ────────────────────────────────────────────────────
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
        always {
            // Supprime le fichier .env temporaire copié en début de deploy
            sh "rm -f ${WORKSPACE}/.env.kabutare.tmp || true"
        }
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
