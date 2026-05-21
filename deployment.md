[Machine dev] [Serveur Ubuntu]
│ │
├── ./build_and_push.sh │
│ └── push 3 images Docker Hub │
│ │
│ scp / git clone le projet ─────────►│
│ ├── sudo bash setup_ubuntu.sh
│ │ 1. apt Docker
│ │ 2. détecte IP publique
│ │ 3. openssl → ssl/cert.pem
│ │ 4. crée .env
│ │ 5. docker run flutter build web
│ │ 6. docker compose pull
│ │ 7. docker compose up -d
│ │ 8. kcadm configure-realm
│ │
│ https://<IP>/ ← Application
│ https://<IP>/keycloak/admin/ ← Admin KC
