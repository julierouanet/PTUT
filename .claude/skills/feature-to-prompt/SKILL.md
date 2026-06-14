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
```

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

## Phase 4 — Notation KPI du prompt v2 (/100)

Noter le prompt v2 avec la grille ci-dessous. **Chaque point perdu exige une justification**
(rubric-based / explicable). Donner le score par domaine + total + verdict.

### Grille KPI — Qualité d'un prompt Claude Code (barème /100)

| # | Domaine | Pts | Ce qui est évalué |
|---|---|---:|---|
| D1 | **Clarté & directivité** | 15 | Instructions explicites et impératives, zéro ambiguïté, exploite la littéralité de Claude 4.x (dire exactement quoi faire, ne pas compter sur l'inférence). |
| D2 | **Ancrage projet** | 15 | Stack rappelée, fichiers cibles en `fichier:ligne` réels, conventions `CLAUDE.md` citées, schémas `contexte/context.md` référencés. |
| D3 | **Structure & format** | 10 | Sections balisées (titres markdown / XML), séparation nette contexte / tâche / contraintes / sortie. |
| D4 | **Spécificité & périmètre** | 15 | Périmètre in/out of scope explicite, tâche décomposée en étapes, pas de zone grise. |
| D5 | **Critères de succès & vérification** | 15 | Définition de « fini », tests à faire passer (`npm test` / `flutter analyze`), `log_feature.py`, mise à jour doc. |
| D6 | **Exemples & références** | 10 | Patterns de code attendus, fichiers de référence à imiter, exemples de payloads / schémas. |
| D7 | **Contraintes & garde-fous** | 10 | Règles de sécurité, pièges critiques pertinents, liste explicite « ne pas faire » (RBAC, migrations, i18n, ApiClient, secrets). |
| D8 | **Raisonnement & plan** | 10 | Demande un plan / réflexion avant code, ordre d'exécution, « proposer avant d'agir » sur tout changement d'architecture. |

**Total = Σ D1…D8 sur 100.**
Verdict : **≥ 85 Excellent · 70–84 Bon · 50–69 Moyen · < 50 À refaire.**

> Fondements (recherche bonnes pratiques de prompting) :
> - *Anthropic* : être clair et direct, exemples (multishot), laisser réfléchir (chain-of-thought),
>   balises XML, rôle/system prompt, chaînage ; cadrage « définir le succès → tester → itérer ».
> - *Prompt evaluation* : rubric-based scoring explicable (clarté, spécificité, cohérence,
>   correction/fidélité, mesurabilité des critères de succès).

## Phase 5 — Prompt v3 final (ré-noté)

Corriger chaque point perdu en Phase 4 pour produire le **prompt v3**. Re-noter avec la même
grille et viser **≥ 85/100**. Si < 85, itérer une fois de plus avant de livrer (et expliquer
les points résiduels). Présenter un tableau **avant/après** (score v2 → v3 par domaine).

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
4. Notation KPI v2 /100 (grille D1–D8, points perdus justifiés)
5. Prompt v3 corrigé + ré-noté (cible ≥ 85) + tableau avant/après
6. Écrire prompts/feature_<slug>_<date>.md + récap dans le chat
```
