# Audit du volume de données — Flux de premier accès GMAO Kabutare

> **Type** : audit performance réseau **en lecture seule** (aucun fichier de code/config modifié).
> **Cible** : déploiement **dev** `https://dev.app.lucaslopvet.fr`.
> **Date** : 2026-06-21 · **Finalité** : optimisation bas-débit (Hôpital de Kabutare, Rwanda — connexion lente, facturée au volume).
> **Profils** : `admin` (mesuré, pire cas en volume) · `hospitalStaff` (estimé, voir §4).

---

## 1. Résumé exécutif

- **Volume du premier accès ≈ 11,2 Mo** (profil admin, navigateur Chrome). Réparti : **bundle web 96,4 %**, **payloads API du login 3,6 %**.
- **3 plus gros postes** : `chromium/canvaskit.wasm` **5,42 Mo** (48,6 %), `main.dart.js` **5,18 Mo** (46,4 %), `GET /api/equipment` **0,40 Mo** (3,5 %).
- **Cause n°1 du surpoids** : la config nginx déployée **ne compresse PAS** le JavaScript ni le WebAssembly (seul `index.html` est gzippé). Les deux plus gros fichiers partent bruts.
- **Gain total réaliste ≈ 7,5 Mo (−68 %)** en activant simplement gzip sur JS+WASM (bundle) et sur l'API — **sans toucher au code applicatif**, uniquement la config nginx/serveur.
- **Aggravant accès répétés** : le bundle est servi en `Cache-Control: no-store` → les **~11 Mo sont re-téléchargés à CHAQUE visite**. Un cache long ramènerait les visites suivantes à ~0 Mo.

---

## 2. Méthodologie & URLs découvertes (Étape 0)

Mesure de référence par `curl` (octets réellement transférés), recoupée avec les URLs **bakées dans le bundle** (`main.dart.js`) — les bases d'API n'ont **pas** été supposées mais vérifiées empiriquement.

**Commandes types :**
```bash
# Octets transférés (avec négociation de compression)
curl -s -o /dev/null -w "%{size_download}" -H "Accept-Encoding: gzip, br" <url>
# Octets bruts (sans compression)
curl -s -o /dev/null -w "%{size_download}" <url>
# En-têtes compression/cache
curl -sI -H "Accept-Encoding: gzip, br" <url>
# Token Direct Grant Keycloak (mot de passe non journalisé)
curl -s -X POST "<KC_TOKEN_URL>" -d grant_type=password -d client_id=flutter-app \
     -d username=<u> --data-urlencode password=<masqué>
# Endpoint authentifié
curl -s -o body -w "%{size_download}" -H "Authorization: Bearer <token>" <url>
```

**Découverte des bases réelles** — le même-origine `/db`, `/auth`, `/keycloak` retombe sur le SPA (`index.html`, 8961 o, `text/html`) : il **n'est pas** l'API. Les vraies bases (confirmées par `/health` JSON et par grep des URLs dans `main.dart.js`) :

| Base | URL réelle (injectée via `--dart-define` au build Jenkins) | Preuve |
|---|---|---|
| App / bundle | `https://dev.app.lucaslopvet.fr` | HTTP 200, `index.html` |
| **db-service** | `https://dev.db.lucaslopvet.fr` | `/health` → `{"service":"db-service"...}` |
| **auth-service** | `https://dev.auth.lucaslopvet.fr` | `/health` → `{"service":"auth-service"...}` |
| **Keycloak** | `https://keycloak.lucaslopvet.fr/realms/kabutare-hospital/...` (instance **partagée**, non préfixée `dev.`) | well-known → JSON ; grep `main.dart.js` |

> ⚠️ **Écart repo vs déploiement** : la config versionnée `nginx/conf.d/dev-app.conf` annonce `gzip_types ... application/javascript` (ligne 32) et `expires 1h` (l. 26-29). Le serveur **déployé** renvoie au contraire `Content-Encoding: none` sur le JS et `Cache-Control: no-cache, no-store` — la config live ne correspond pas au fichier du repo. Les chiffres ci-dessous reflètent le **déploiement réel** (ce que subit l'utilisateur rwandais).

---

## 3. Poste A — Bundle web (téléchargé avant tout login)

Renderer effectif : **CanvasKit**, variante **chromium** sur navigateurs Chromium (cas réaliste hôpital). Polices **tree-shakées** (MaterialIcons réduit à 40 Ko). Manifeste réel = `AssetManifest.bin.json` (258 o) ; `AssetManifest.json` n'existe pas (renvoie le fallback SPA).

| Ressource | Type | Taille brute | Transférée (actuel) | Compression | Remarque |
|---|---|---:|---:|---|---|
| `chromium/canvaskit.wasm` | wasm | 5 686 836 | 5 686 836 | **none** | gzip atteindrait 2 161 642 (**−62 %**) |
| `main.dart.js` | js | 5 436 231 | 5 436 231 | **none** | gzip atteindrait 1 519 022 (**−72 %**) |
| `canvaskit.js` (loader) | js | 86 859 | 86 859 | **none** | gzip ~30 Ko |
| `MaterialIcons-Regular.otf` | font | 40 008 | 40 008 | none | tree-shakée, OK |
| `flutter_bootstrap.js` | js | 9 975 | 9 975 | **none** | — |
| `flutter.js` | js | 9 553 | 9 553 | **none** | — |
| `index.html` | html | 8 961 | **3 590** | **gzip** | seule ressource compressée |
| `favicon.png` | png | 2 625 | 2 625 | none | déjà compressé |
| `CupertinoIcons.ttf` | font | 2 736 | 2 736 | none | — |
| `flutter_service_worker.js` | js | 2 380 | 2 380 | **none** | — |
| `manifest.json` | json | 949 | 949 | none | — |
| `AssetManifest.bin.json` | bin | 258 | 258 | none | — |
| `FontManifest.json` | json | 208 | 208 | none | — |
| `version.json` | json | 110 | 110 | none | — |
| **Total Poste A (Chrome)** | | **11 299 982** | **11 282 318 ≈ 10,76 Mo** | | quasi tout non compressé |

- **Variantes CanvasKit présentes** : standard `canvaskit.wasm` **6,82 Mo** (navigateurs non-Chromium → pire cas, total ~12,16 Mo), chromium **5,42 Mo** (cas mesuré), `skwasm.wasm` **3,39 Mo** (renderer alternatif, non utilisé par défaut).
- **Statut compression `.wasm` : tranché → NON compressé** (`Content-Encoding: none`, `Content-Type: application/wasm`). C'est le plus gros gisement d'économie.
- **Cache** : `Cache-Control: no-cache, no-store, must-revalidate`, `Expires: 0` sur **toutes** les ressources → **aucune mise en cache navigateur**. Chaque ouverture de l'app re-télécharge l'intégralité du bundle.

**Poste A après gzip (estimé)** : ≈ **3,59 Mo** → économie **7,17 Mo (−67 %)** par simple activation de la compression serveur.

---

## 4. Poste B — Payloads API au login

API servie **non compressée** (ni gzip nginx sur `dev-db.conf`/`dev-auth.conf`, ni middleware `compression` côté Node) → « transféré » = « brut ». Colonne « gzip simulé » = compression locale du corps de réponse (gain atteignable). **Token** access ≈ 1507 o, réponse token complète **2498 o**.

### 4.1 Profil `admin` (mesuré)

| Endpoint | Rôle requis | Octets (brut = servi) | gzip simulé | Remarque |
|---|---|---:|---:|---|
| `GET /api/equipment` | tous | **414 760** | 24 106 | **parc complet, 385 équipements, 42 colonnes/objet, sans pagination** — 97,7 % du Poste B |
| `GET /api/users` | admin | 3 104 | 892 | admin-only |
| `GET /api/issues` | tous | 2 412 | 729 | — |
| `GET /api/inventory` | tous | 1 528 | 452 | — |
| `GET /api/roles` | admin | 1 457 | 396 | admin-only |
| `GET /api/auth/me` | tous | 491 | 321 | session |
| `GET /api/feature-flags` | tous | 348 | 239 | — |
| `GET /api/users/me/notifications` | sup/tech/admin | 214 | 171 | — |
| `GET /api/notifications/vapid-key` | tous | 103 | 103 | push |
| `GET /api/sidebar/config` ×6 rôles | tous | **210** (27+32+43+35+38+35) | — | **6 requêtes HTTP** émises au login (cf. `data_service.dart:171`) |
| `GET /api/locations` | tous | 2 | — | tableau vide `[]` |
| `GET /api/users/department-requests` | admin | 2 | — | tableau vide `[]` |
| **Sous-total data** | | **424 631 ≈ 415 KB** | **~27,6 KB** | |
| Réponse token (login) | — | 2 498 | — | access_token 1507 o |
| **Total Poste B admin** | | **427 129 ≈ 417 KB** | **~29,4 KB** | gzip API : **−93 %** |

- **Surcoût des 6 requêtes sidebar** : en volume **négligeable (210 o cumulés)**, mais **6 allers-retours HTTP** là où **1** suffirait. Sur une liaison à fort RTT (satellite/3G Rwanda), ce sont **5 RTT inutiles** (latence, pas octets) → fusion recommandée pour le temps de réponse perçu.
- **Taille du token** : 1507 o (access), renvoyé une fois (réponse 2498 o), puis ré-émis en en-tête `Authorization` sur **chaque** requête (~1,5 Ko/requête montant).
- **ETag présent** sur `/api/equipment` (`W/"65428-..."`) mais **aucun `Cache-Control`**, et le client Flutter **n'envoie pas** `If-None-Match` → le parc complet est re-téléchargé à chaque login (cf. §6, benchmark 3).

### 4.2 Profil `hospitalStaff` (estimé)

> **Méthode d'estimation** : mesures admin **moins** les endpoints admin-only (`/api/users` 3104 o, `/api/roles` 1457 o, `/api/users/department-requests` 2 o) **et** `/api/users/me/notifications` (réservé sup/tech/admin, 214 o). Les 6 requêtes sidebar **sont bien émises pour `hospitalStaff` aussi** (`data_service.dart:169-181` boucle sur les 6 rôles quel que soit l'utilisateur connecté).

- **Total Poste B hospitalStaff ≈ 419 854 o data + 2498 token ≈ 412 KB.** Quasi identique à l'admin : `GET /api/equipment` domine (98 %), les endpoints admin-only ne pèsent que ~4,6 Ko. **Étiqueté « estimé ».**

---

## 5. Total agrégé du premier accès

| Poste | admin (Chrome) | hospitalStaff (estimé) | % du total |
|---|---:|---:|---:|
| **A — Bundle web** | 10,76 Mo | 10,76 Mo | **96,4 %** |
| **B — API login** | 0,41 Mo | 0,40 Mo | **3,6 %** |
| **TOTAL** | **≈ 11,17 Mo** | **≈ 11,16 Mo** | 100 % |

**Camembert textuel (admin) :**
```
chromium/canvaskit.wasm  ██████████████████████████  48,6 %  (5,42 Mo)
main.dart.js             █████████████████████████    46,4 %  (5,18 Mo)
/api/equipment           ██                            3,5 %  (0,40 Mo)
canvaskit.js loader      ▌                             0,7 %  (0,08 Mo)
MaterialIcons + reste    ▏                             0,7 %  (0,08 Mo)
```

- **Top 3 postes d'économie** : (1) gzip de `main.dart.js` −3,74 Mo, (2) gzip du `.wasm` −3,36 Mo, (3) gzip + pagination de `/api/equipment` −0,38 Mo.
- **Total réaliste après gzip JS+WASM+API : ≈ 3,6 Mo → gain ≈ 7,5 Mo (−68 %).**
- **Pire cas** (navigateur non-Chromium, canvaskit standard 6,82 Mo) : ~12,6 Mo bruts.

---

## 6. Benchmark marché — pratiques GMAO bas-débit

| Pratique | État actuel de l'app | Gain potentiel estimé | Effort |
|---|---|---|---|
| **1. Pagination / lazy-load** | `GET /api/equipment` charge **tout le parc (385 obj, 405 Ko)** au login, sans pagination (`db_api_service.dart:18`). Idem issues/inventory (ici petits). | 1ʳᵉ page de 50 objets = **73 Ko** (complet) ou **8 Ko** (light) au lieu de 405 Ko → **−330 à −395 Ko** sur le 1ᵉʳ écran *(estimé)*. Marge réduite si gzip activé (405→24 Ko), mais bénéfice mémoire/latence conservé. | M |
| **2. Payloads « light » pour listes** | Objet équipement = **42 colonnes, 1457 o**, dont arrays imbriqués `maintenanceHistory`, `futureMaintenance`, `tags`. Champs réellement utiles en liste (id/nom/statut/catégorie/lieu/SN/service) = **163 o**. | **Ratio utile = 11,2 %** → 88,8 % d'octets transférés inutilement. Liste « light » du parc = **61 Ko** vs 405 Ko → **−344 Ko** *(estimé)*. Détail chargé à l'ouverture d'une fiche. | M |
| **3. Sync delta / offline-first** | **ETag présent** côté `db-service` mais **`Cache-Control` absent** ; `ApiClient` n'envoie **aucun** en-tête conditionnel (`api_client.dart:54`). Bundle en `no-store`. | Sur **accès répété** sans changement : API → `304` (~few hundred o au lieu de 405 Ko) **et** bundle cacheable → ~0 Mo au lieu de 11 Mo. **Quasi-totalité du volume évitée dès la 2ᵉ visite** *(estimé)*. | M |

---

## 7. Recommandations priorisées (triées par rapport gain/effort)

| # | Recommandation | Poste | Gain estimé | Effort | Risque |
|---|---|---|---:|---|---|
| **1** | **Activer gzip (ou brotli) sur JS + WASM** : ajouter `application/javascript application/wasm` à `gzip_types` et `gzip_comp_level 5` dans la config nginx du front (`dev-app.conf`). | A | **−7,2 Mo (−67 % bundle)** | **S** | Faible |
| **2** | **Cache long + immutable** sur les assets hashés ; supprimer `no-store` du bundle (garder `no-cache` sur `index.html` seul). | A | **~−11 Mo dès la 2ᵉ visite** | **S** | Faible |
| **3** | **Compresser l'API** : `gzip on` + `gzip_types application/json` dans `dev-db.conf`/`dev-auth.conf` **ou** middleware `compression` côté Express. | B | **−0,39 Mo (−93 % API)** ; `/api/equipment` 405→24 Ko | **S** | Faible |
| **4** | **Pagination / lazy-load** de `GET /api/equipment` (puis issues/inventory) au lieu du parc complet au login. | B | −0,33 à −0,40 Mo *(estimé)* | M | Moyen |
| **5** | **Payload « light »** pour les listes (exclure `maintenanceHistory`/`futureMaintenance`/`tags`, détail à l'ouverture). | B | ~−0,34 Mo *(estimé)* | M | Moyen |
| **6** | **Fusionner les 6 requêtes sidebar** en un seul appel (retour de tous les rôles, ou du rôle courant uniquement). | B | volume ~0 ; **−5 allers-retours (latence)** | **S** | Faible |
| **7** | **Sync conditionnelle** : envoyer `If-None-Match`/`If-Modified-Since` depuis `ApiClient`, gérer `304`. | B | −0,40 Mo/accès répété *(estimé)* | M | Moyen |
| **8** | *(Optionnel)* Renderer plus léger (skwasm 3,39 Mo) ou découpage différé du moteur de rendu. | A | jusqu'à ~−2,0 Mo brut *(estimé)* | L | Moyen |

> **Quick wins immédiats (#1, #2, #3, #6)** : uniquement de la configuration serveur/nginx, **aucune modification du code applicatif**, gain cumulé **≈ 7,5 Mo (−68 %)** au premier accès et quasi-suppression du volume aux accès suivants.

---

## 8. Limites de l'audit

- Mesure sur l'environnement **dev** uniquement ; le parc dev compte **385 équipements** (en prod, `/api/equipment` croît linéairement → l'argument pagination se renforce).
- Profil `hospitalStaff` **estimé** (non mesuré) : extrapolation documentée à partir des mesures admin (§4.2).
- Gains gzip du `.wasm`/JS = compression **locale `gzip -6`** (reproductible), proche du rendu nginx ; brotli ferait mieux encore.
- Hors scope : uploads (photos/PDF), navigation post-login au-delà du 1ᵉʳ écran, APK Android, environnement prod.

---

*Audit en lecture seule — aucun fichier de code/config applicatif modifié. Seul livrable écrit : ce rapport.*
