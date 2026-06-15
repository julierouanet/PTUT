---
name: feature-to-prompt
description: >
  Transforme une idée de feature pour la GMAO Kabutare en un prompt Claude Code prêt à copier-coller,
  via un pipeline en 6 phases : lecture du contexte, brainstorm interactif, ébauche de prompt,
  comparaison aux GMAO du marché, notation KPI /100, puis prompt final ré-noté livré en .md.
  Utiliser ce skill dès que l'utilisateur veut « préparer un prompt pour implémenter une feature »,
  « cadrer une fonctionnalité avant de coder », ou « transformer une idée en prompt Claude Code ».
  Ce skill NE code PAS la feature : il produit le prompt qui servira à la coder.
---

# Feature → Prompt — GMAO Kabutare

Pipeline qui prend en **entrée une feature à implémenter** et produit en **sortie un prompt
Claude Code optimisé** (fichier `.md` à copier-coller), spécifique à la stack du projet
(Flutter / Node.js Express / SQLite better-sqlite3 / Keycloak).

> ⚠️ **Ce skill ne génère AUCUN code applicatif.** Son unique livrable est un prompt.
> L'implémentation se fera plus tard, en collant le prompt produit dans une session Claude Code.

## Règles transverses

- **Tout en français** : dialogue, contenu du skill et prompt final livré.
- **Questions une à la fois** : pendant les phases de brainstorm (Phase 1) et de comparaison
  marché (Phase 3), poser **une seule question à la fois** en texte conversationnel, attendre
  la réponse, puis enchaîner. Ne jamais grouper un lot de questions. S'arrêter de questionner
  dès que le périmètre est assez clair pour avancer.
- **Ancrage projet obligatoire** : tout prompt produit référence les fichiers réels en
  `fichier:ligne`, les conventions de `CLAUDE.md` et les schémas de `contexte/context.md`.
  Jamais de prompt générique « hors-sol ».
- **Ne rien inventer sur le code** : si une table, une route ou un écran est cité dans le
  prompt, il doit exister (vérifier par Read/Grep) ou être explicitement marqué « À CRÉER ».
- **Proposer avant d'écrire le fichier final** : montrer le prompt v3 dans le chat, puis
  l'écrire dans `prompts/`.

## Phase 0 — Lecture du contexte (obligatoire, silencieuse)

Avant toute interaction, lire dans l'ordre :

1. `CLAUDE.md` — conventions, commandes, pièges critiques, processus de clôture.
2. `contexte.md` — métier, architecture, rôles/permissions, schémas DB résumés.
3. `contexte/context.md` — schémas DB complets + tous les endpoints API.
4. `contexte/resume_need_software_kabutare.md` — cahier des charges original.
5. Si la feature touche un standard d'accréditation : `audit/rapport_accreditation_RHAS_2026-06-12.md`.
6. Cibler le code concerné par la feature (`Grep`/`Glob` sur les routes, écrans, modèles
   pertinents) pour ancrer le prompt sur des `fichier:ligne` réels.

Ne pas narrer cette lecture en détail ; enchaîner directement sur la Phase 1.

## Phase 1 — Brainstorm interactif (questions une à la fois)

Objectif : transformer une idée floue en spécification implémentable. Reformuler d'abord
la feature comprise en 2-3 phrases, puis poser **une question à la fois** jusqu'à lever les
ambiguïtés. Couvrir au minimum :

- **Périmètre** : ce qui est dans / hors scope. Module 1 uniquement ?
- **Couche(s) touchée(s)** : DB (nouvelle table/colonne ?), backend (auth-service / db-service,
  nouvel endpoint ?), Flutter (nouvel écran / widget / service ?), i18n, notifications.
- **Rôles & permissions** : quels rôles Keycloak ont accès ? Nouvelle permission applicative ?
- **Données** : quels champs, quels enums/whitelists, quelles contraintes (IDs TEXT, UUID Keycloak,
  migrations idempotentes) ?
- **RBAC & sécurité** : `verifyToken` + `requireRole`, audit trail `logAction`, CORS.
- **UX** : responsive (<600 / 600-799 / ≥800), navigation (`ScreenType` vs `MaterialPageRoute`).
- **Critères de succès** : comment saura-t-on que c'est fini et correct ? Tests attendus.
- **Contraintes d'accréditation** : la feature vise-t-elle un gap du rapport RHAS (ex. `resolved_at`,
  near miss, plan de remplacement, fréquence PM hebdo) ?

Clore la phase par une **synthèse de spécification** validée par l'utilisateur (1 court paragraphe
+ liste à puces des couches touchées).

## Phase 2 — Ébauche de prompt v1

Rédiger une **première version** du prompt Claude Code à partir de la spécification validée.
Structure imposée (balises de section explicites, exploitant la littéralité de Claude 4.x) :

```
# Tâche : <titre de la feature>

## Contexte projet
<stack + rappel des conventions clés CLAUDE.md applicables + fichiers concernés en fichier:ligne>

## Objectif
<1-2 phrases : le quoi et le pourquoi>

## Périmètre
- Dans le scope : ...
- Hors scope : ...

## Spécification détaillée
<DB / backend / Flutter / i18n / notifications — chaque couche avec ses fichiers cibles>

## Contraintes et garde-fous
<règles CLAUDE.md applicables : migrations idempotentes, RBAC, logAction, ApiClient,
i18n FR+EN, pas de secret en dur, pièges critiques pertinents>

## Étapes attendues
1. ... 2. ... 3. ...

## Critères de succès / vérification
- npm test (service concerné) OU flutter analyze --no-fatal-infos passe
- python -X utf8 scripts/log_feature.py --nom "..." --desc "..."
- mise à jour de contexte.md / contexte/context.md si feature majeure

## Étape finale obligatoire
Une fois la feature implémentée et vérifiée, lancer `/simplify` sur le code créé/modifié
pour nettoyer (réutilisation, simplification, efficacité, altitude) avant de clore la tâche.
```

> ⚠️ La section **« Étape finale obligatoire »** demandant de lancer `/simplify` sur le code
> créé doit **toujours** figurer à la fin de chaque prompt produit (v1, v2 et v3).

Afficher v1 dans le chat. Ne pas encore l'écrire sur disque.

## Phase 3 — Comparaison aux GMAO du marché (questions une à la fois)

Comparer la feature spécifiée avec la façon dont les **GMAO du marché** la traitent, pour
identifier les éléments différenciants réalistes pour un **hôpital de district** (ne pas
sur-spécifier). Références : **Maximo, Infor EAM, CARL Source, Dimo Maint, Fiix, UpKeep**.

Pour la feature concernée, expliciter :

- Ce que ces systèmes font en standard sur ce type de feature (champs, workflows, KPIs associés).
- Les **GMAO KPIs** pertinents : MTTR, MTBF, taux de conformité PM, taux de disponibilité,
  criticité ABC, coût de maintenance, backlog — lesquels cette feature alimente ou devrait alimenter.
- Les **manques** de la v1 au regard de ces standards, formulés comme des améliorations possibles.

Poser ensuite **une question à la fois** pour arbitrer : « le marché fait X — le veut-on, ou
est-ce trop lourd pour Kabutare ? ». À partir des réponses, produire le **prompt v2** (v1 enrichie),
affiché dans le chat.

## Phase 4 — Notation KPI du prompt v2 (/100, grille exigeante à 12 domaines)

> Cette phase est **délibérément sévère**. Un prompt « correct mais générique » doit plafonner
> autour de 70. Le 90+ se mérite : ancrage `fichier:ligne` réel, critères mesurables et chiffrés,
> cas limites traités, zéro contradiction. **On ne distribue pas de points par défaut** — un domaine
> part de 0 et gagne des points sur preuve.

### Phase 4bis — Passe adversariale (red-team) AVANT de noter

Avant d'attribuer le moindre point, jouer le rôle d'un **Claude implémenteur hostile / distrait**
qui lit le prompt v2 et cherche à le mal interpréter. Lister explicitement (3 à 6 items) :

- Les **ambiguïtés exploitables** (« rien n'interdit de faire X au lieu de Y »).
- Les **cas limites non couverts** (valeur `null`, liste vide, 0 résultat, doublon, conflit, offline,
  rôle non prévu, id inexistant, migration déjà appliquée).
- Les **contradictions internes** (une section dit A, une autre dit non-A).
- Les **hypothèses tacites** sur le code (table/route/écran supposés sans `fichier:ligne`).

Ces trouvailles **alimentent directement** la notation des domaines D5, D9, D11 et D12. Un prompt
qui survit mal au red-team ne peut pas dépasser 80.

### Grille KPI — Qualité d'un prompt Claude Code (barème /100, 12 domaines)

Pour **chaque domaine** : noter sur le barème, et **justifier tout point perdu par une preuve**
(citation du prompt, `fichier:ligne` manquant, item red-team non traité). Pas de demi-justification.

| # | Domaine | Pts | Plein score (ancre haute) | Score nul (ancre basse) |
|---|---|---:|---|---|
| D1 | **Clarté & directivité** | 10 | Verbes impératifs, une seule lecture possible, aucune inférence requise. | Formulations vagues (« gérer », « améliorer »), passif, intentions implicites. |
| D2 | **Ancrage projet** | 12 | Stack + conventions `CLAUDE.md` citées ET ≥ 5 `fichier:ligne` réels vérifiés + schémas `context.md`. | Aucun chemin réel, références génériques « le service backend ». |
| D3 | **Structure & format de sortie** | 8 | Sections balisées + format de sortie attendu décrit (JSON/signature/diff). | Bloc de texte continu, sortie non spécifiée. |
| D4 | **Spécificité & périmètre** | 10 | In-scope ET out-of-scope explicites, tâche décomposée, zéro zone grise. | Périmètre flou, pas de « hors scope ». |
| D5 | **Critères de succès mesurables** | 12 | Cibles **chiffrées/binaires** (test Jest nommé, `flutter analyze` 0 erreur, scénarios clic→écran), `log_feature.py`, doc. | « Vérifier que ça marche » sans test nommé ni cible. |
| D6 | **Exemples & références** | 8 | Payloads réels, signatures attendues, ≥ 1 fichier de référence à imiter cité. | Aucun exemple, aucun pattern à copier. |
| D7 | **Contraintes & garde-fous (Do/Don't)** | 10 | Liste « ne pas faire » explicite (RBAC, migrations idempotentes, i18n FR+EN, ApiClient, secrets, pièges `CLAUDE.md`). | Contraintes absentes ou purement génériques. |
| D8 | **Raisonnement & plan** | 7 | Exige un plan avant code + « proposer avant d'agir » sur tout changement d'architecture. | Demande de coder directement. |
| D9 | **Robustesse & cas limites** | 8 | Traite explicitement les items du red-team (null/vide/erreur/conflit/offline/rôle). | Ignore tout cas non nominal. |
| D10 | **Rôle & cadrage** | 5 | Rôle/posture donné à l'implémenteur + audience/intention métier claire. | Aucun cadrage de rôle ni de finalité. |
| D11 | **Efficacité & hygiène de contexte** | 5 | Dense et autosuffisant, zéro remplissage, ancrages utiles seulement. | Verbeux, redondant, bruit qui noie l'instruction. |
| D12 | **Cohérence & autosuffisance** | 5 | Aucune contradiction interne ; collable seul, sans dépendre d'un contexte de chat absent. | Contradictions, renvois à « comme dit plus haut » hors du fichier. |

**Total = Σ D1…D12 sur 100.** (Dimensions volontairement orthogonales : ne pas créditer deux fois la même qualité.)

Verdict (seuils relevés) : **≥ 90 Excellent · 75–89 Bon · 60–74 Moyen · < 60 À refaire.**

> Fondements (recherche bonnes pratiques de prompting & notation, juin 2026) :
> - *Anthropic — Prompt engineering overview & best practices* : clair et direct, exemples (multishot),
>   laisser réfléchir (chain-of-thought), balises XML, rôle/system prompt, chaînage ; cadrage
>   « définir des critères de succès **mesurables et chiffrés** → construire des évals → itérer ».
> - *Rubric-based eval / LLM-as-a-judge* (Braintrust, Maxim, Medium A. Masood) : critères avec
>   **ancres explicites** par niveau de score, dimensions **orthogonales**, scoring par composant
>   plutôt qu'un « note la qualité » global.
> - *Skills Claude Code open-source* : `prompt-optimizer-skill` (red-teaming adversarial + score 0-100
>   clarté/spécificité/robustesse), `prompt-architect` (CO-STAR/RISEN/TIDD-EC, do/don't, rôle/format),
>   `auto-prompt-creator` (3-4 dimensions pondérées, ancres 5/5 vs 1/5, boucle d'itération),
>   `homework-grader` (rubrique YAML à poids + descriptions d'ancrage).

## Phase 5 — Prompt v3 final (ré-noté)

Corriger **chaque point perdu** en Phase 4 ET **chaque item de la passe adversariale (4bis)** pour
produire le **prompt v3**. Re-noter avec la même grille à 12 domaines et viser **≥ 90/100**.
Si < 90, itérer encore (jusqu'à 2 boucles supplémentaires) avant de livrer ; au-delà, livrer en
expliquant précisément les points résiduels et pourquoi ils sont acceptés. Présenter un tableau
**avant/après** (score v2 → v3 par domaine, 12 lignes) + un rappel des items red-team désormais couverts.

## Phase 6 — Livrable

1. Écrire le prompt v3 dans `prompts/feature_<slug>_<AAAA-MM-JJ>.md` (créer le dossier `prompts/`
   s'il n'existe pas). Le fichier contient **uniquement le prompt à coller** (pas la notation),
   précédé d'un court bloc d'en-tête (titre, date, score final).
2. Afficher dans le chat : le chemin du fichier + le score final + le tableau avant/après.
3. Rappeler à l'utilisateur que ce prompt est à coller dans une **nouvelle session Claude Code**
   pour l'implémentation, et que la clôture (test + `log_feature.py` + doc) fait partie du prompt.

## Ordre d'exécution (récapitulatif)

```
0. Lire le contexte (CLAUDE.md, contexte.md, context.md, resume, code ciblé)
1. Brainstorm — questions UNE À LA FOIS → synthèse de spec validée
2. Ébauche prompt v1 (structure imposée) — affichée dans le chat
3. Comparaison GMAO marché — questions UNE À LA FOIS → prompt v2
4bis. Passe adversariale red-team sur v2 (ambiguïtés, cas limites, contradictions)
4. Notation KPI v2 /100 (grille exigeante D1–D12, points perdus justifiés par preuve)
5. Prompt v3 corrigé (points perdus + items red-team) + ré-noté (cible ≥ 90) + tableau avant/après
6. Écrire prompts/feature_<slug>_<date>.md + récap dans le chat
```
