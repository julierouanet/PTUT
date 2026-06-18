---
name: rapport-stage
description: Apporte des modifications au rapport de stage FIE4 de Lucas LOPVET (Kabutare District Hospital, Rwanda), rédigé en anglais. Édite les chapitres source dans "rapport s2/travail/", régénère le .docx et le PDF de contrôle, vérifie le volume et la forme, et maintient la cohérence inter-parties via un journal de modifications. Utiliser ce skill dès que l'utilisateur veut corriger, réécrire, ajuster, ré-noter ou compléter une partie du rapport de stage (abstract, introduction, cadre, réalisations, conclusions, pages introductives, biblio, annexes).
---

# Skill — Modification du rapport de stage FIE4 (Kabutare)

Ce skill encadre toute modification du rapport de stage de 4ᵉ année de **Lucas LOPVET**
(Kabutare District Hospital, Huye, Rwanda), rédigé **en anglais**. Le travail se fait sur des
fichiers Markdown source, puis un script assemble le `.docx`. **Ne jamais éditer le `.docx` à la
main** pour des changements de fond : éditer les sources et régénérer.

## 0. Avant toute chose — lire le contexte

À chaque invocation, lire dans l'ordre :

1. `E:\stage rwanda fichier\rapport s2\travail\_a_modifier.md`
   — **journal des modifications à répercuter** (incohérences inter-parties en attente). Si la
   demande de l'utilisateur correspond à un item en attente, le traiter et le marquer ✅.
2. `E:\stage rwanda fichier\rapport s2\travail\00_avancement.md`
   — état du projet, décisions prises, ce qui reste à la charge de Lucas.
3. La (les) source(s) du chapitre concerné (voir cartographie ci-dessous).

## 1. Cartographie des fichiers

Tout est dans `E:\stage rwanda fichier\rapport s2\` :

| Élément | Fichier source |
|---|---|
| Introduction (ch. 1) | `travail/10_introduction.md` |
| Cadre et objectifs (ch. 2) | `travail/11_cadre_objectifs.md` |
| Réalisations (ch. 3) | `travail/12_realisations.md` |
| Conclusions (ch. 4) | `travail/13_conclusions.md` |
| Pages intro / biblio / annexes (texte de référence FR) | `travail/14_pages_intro.md`, `travail/15_biblio_annexes.md` |
| **Couverture, fiche signalétique, résumé/abstract, remerciements, glossaire, biblio, annexes** | **codés en dur dans `travail/_build_docx.py`** (sections « FRONT PAGES », « BIBLIOGRAPHY », « APPENDICES ») |
| Notation vs consignes | `travail/16_notation_consignes.md` |
| Journal inter-parties | `travail/_a_modifier.md` |
| Figures (génération) | `travail/_gen_figures.py` → PNG dans `travail/figures/` |
| Assemblage du livrable | `travail/_build_docx.py` |
| Comptage pages + contrôle tirets | `travail/_compte_pages.py` |
| **Livrable final** | `Rapport_stage_FIE4_Kabutare.docx` |
| Versions françaises archivées | `travail/fr_backup/` |
| Inventaire physique réel (logistique) | `C:\Users\Perso\ShadowDrive\Lucas perso\INVENTORY combined october.xlsx` |

> Les chapitres du **corps** (1-4) sont dans les `.md` ; les **pages introductives, la bibliographie
> et les annexes** sont générées par `_build_docx.py` (chaînes en dur). Selon ce qu'on modifie, éditer
> le `.md` OU le script.

## 2. Règles absolues (NE JAMAIS enfreindre)

- **Anglais** : tout le corps et les pages (sauf le **Résumé** français, qui reste en double FR + EN).
- **Aucun tiret long** « — » : le build les remplace déjà (`" — "`→`" - "`), mais ne pas en introduire.
- **Aucune invention** : tout fait/chiffre vient d'une source. Si une info manque, mettre un
  placeholder `[TO BE COMPLETED: ...]` (≥ 12 caractères → surligné en jaune automatiquement).
- **Traçabilité** : pour tout chiffre cité, garder/mettre sa source dans la section
  « Notes de relecture » en bas du `.md` (hors rapport, non rendue).
- **Pronoms** : « I » pour le travail du stage, « we » uniquement pour le PTUT (travail d'équipe).
- **Volume cible** : corps (Introduction → avant Bibliography) = **20 pages ± 2**. Toute coupe/ajout
  significatif doit être suivi d'un recomptage (étape 4).
- **Marqueurs figures/tableaux** dans les `.md` : `**[FIGURE n: titre]**` / `**[TABLE n: titre]**`
  (deux-points, jamais de tiret). Les figures 1-6 existent ; 7-8 sont des placeholders (captures).
- **Dates** : stage du **4 mai au 10 juillet 2026** (10 semaines). Le PTUT s'achève en **avril 2026**.

## 3. Workflow d'une modification

1. **Lire** `_a_modifier.md` + `00_avancement.md` + la source concernée (étape 0).
2. **Clarifier le périmètre** : la demande touche-t-elle une seule partie ou plusieurs ? Lucas valide
   **partie par partie** — ne pas modifier une autre partie sans accord explicite.
3. **Éditer** la (les) source(s) avec l'outil `Edit` (ou `_build_docx.py` pour les pages générées).
4. **Détecter les impacts inter-parties** : si la modif crée une incohérence ailleurs (un chiffre, une
   affirmation « réalisé » vs « en cours », un cadrage), **NE PAS corriger l'autre partie tout de
   suite** → ajouter un item dans `_a_modifier.md` (statut 🔴 ou 🟡) décrivant l'origine, l'incohérence
   et l'action à prévoir.
5. **Mettre à jour** la section « Notes de relecture » du `.md` édité (placeholders, sources).
6. **Régénérer** (étape 4 ci-dessous).
7. **Mettre à jour** `00_avancement.md` (1-2 lignes) et, si la modif change un point noté,
   `16_notation_consignes.md`.

## 4. Régénérer et vérifier le livrable

Depuis n'importe quel dossier (chemins absolus dans les scripts) :

```powershell
# (si des figures ont changé)
python -X utf8 "E:\stage rwanda fichier\rapport s2\travail\_gen_figures.py"

# assembler le .docx
python -X utf8 "E:\stage rwanda fichier\rapport s2\travail\_build_docx.py"

# mettre à jour les champs (TOC, pagination) + exporter le PDF de contrôle, via Word COM
$word = New-Object -ComObject Word.Application; $word.Visible = $false
try {
  $doc = $word.Documents.Open("E:\stage rwanda fichier\rapport s2\Rapport_stage_FIE4_Kabutare.docx")
  $doc.Repaginate(); $null = $doc.Fields.Update()
  foreach ($toc in $doc.TablesOfContents) { $toc.Update() }
  $doc.Save()
  $doc.ExportAsFixedFormat("E:\stage rwanda fichier\rapport s2\travail\_controle.pdf", 17)
  "Pages : " + $doc.ComputeStatistics(2); $doc.Close($false)
} finally { $word.Quit() }

# compter les pages du corps + vérifier l'absence de tirets longs
python -X utf8 "E:\stage rwanda fichier\rapport s2\travail\_compte_pages.py"
```

> LibreOffice n'est pas installé : la conversion PDF et la mise à jour des champs passent **par Word
> (COM)**. Si Word est indisponible, le `.docx` est quand même produit par `_build_docx.py` ; signaler
> alors que le PDF de contrôle et la TOC n'ont pas pu être rafraîchis.

**Contrôles attendus après régénération :**
- corps = 20 pages ± 2 (sortie de `_compte_pages.py`) ;
- « pages contenant un tiret long : aucune » ;
- rendre 1-2 pages modifiées en image (`fitz`/PyMuPDF, dpi 80-90) et **les relire visuellement** ;
- vérifier que les placeholders restants sont bien surlignés et listés.

Rendu d'une page de contrôle :
```powershell
python -X utf8 -c "import fitz; d=fitz.open(r'E:\stage rwanda fichier\rapport s2\travail\_controle.pdf'); d[N].get_pixmap(dpi=90).save(r'E:\stage rwanda fichier\rapport s2\travail\figures\_ctl.png')"
```
(remplacer `N` par l'index 0-based de la page).

## 5. Mémo des choix éditoriaux déjà validés par Lucas

- Rapport **en anglais** (consignes ISIS : autorisé pour les stages à l'étranger) ; **Résumé bilingue**.
- **Réalisation maîtresse** : « du prototype au système en production » (déploiement, IAM Keycloak, import inventaire).
- **Récit central du recueil terrain** : le **technicien d'infrastructure** (multi-techniciens, incidents par lieu, redirection inter-métiers).
- **IA assistée** assumée et analysée (conventions CLAUDE.md, revue de prompts, vérification + tests).
- **Projet professionnel** : dispositifs médicaux + logiciel de DM, double expertise réglementaire/informatique, **double diplôme ISIS (Castres) – ISIFC (Besançon)**.
- **Cadrage** (depuis correction abstract) : système **multi-modules**, projet centré sur le **module équipement médical** ; déploiement **local en cours**, accès distant **à venir** ; inventaire biomédical (340) importé, **inventaire logistique complet à intégrer**.

## 6. Reste à la charge de Lucas (placeholders connus)

Logo ISIS · année de promotion · fiche signalétique (adresse, tél, email, création, effectifs,
coordonnées de Fabien Nshimiyimana et des techniciens) · captures d'écran (figures 7-8 + annexe A) ·
schéma DB (annexe D) · signature de l'autorisation (annexe F) · second « manque » de formation (§4.2) ·
points avec l'encadrement (§3.1.3) · difficultés non techniques (§3.6) · relecture orthographique finale.
