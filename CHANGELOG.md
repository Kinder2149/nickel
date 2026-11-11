# CHANGELOG — Nickel

## 2026-11-10 — Nouvelle vérification : Marché à police maximum (lot 5, R10)
- [CHECK] Autre IA, émulateur, maison jetable (supprimée) : Marché à police max réussi, la fenêtre d'objet défile et un objectif a été posé depuis elle ; fiche, Équipe, Quêtes, Collection sans coupure ; Marché à police normale sain. Détail et captures : Methode_pilotage_v2\CONSTAT_T2.md.

## 2026-11-10 — Police au maximum, étape 4 (fenêtre d'objet du Marché)
- [FIX] FicheObjet (widgets_objet.dart) rendue défilable : à grande police la fenêtre ne déborde plus, prix et « En faire mon objectif » restent atteignables ; test à x1.0 / x1.5 / x2.0 (échoue avant, vert après). Rendu inchangé quand le contenu tient.

## 2026-11-10 — Vérification finale : police au maximum (lot 5)
- [CHECK] Vérification à l'écran sur émulateur, maison jetable : fiche, Équipe, Quêtes, Collection réussis ; Marché partiel (la fenêtre de détail d'un objet est coupée à police max : bouton de prix coupé, « En faire mon objectif » hors écran). Détail et captures : Methode_pilotage_v2\CONSTAT_T2.md.

## 2026-11-10 — Jeu 1-3 : police au maximum, étape 3 (Équipe, Quêtes, menu du bas)
- [FIX] Carte membre et menu du bas extraits dans widgets_equipe.dart, test à police x1.0 / x1.5 / x2.0 (carte membre échoue avant, vert après) ; à grande police : les 3 chiffres s'empilent et les badges passent sous le nom ; bouton « RÉCUPÉRER » de la quête en hauteur minimale. Rendu à police normale inchangé.

## 2026-11-10 — Jeu 1-3 : police au maximum, étape 2 (fiche)
- [FIX] Fiche (Mon profil) : blocs extraits dans widgets_fiche.dart et test à police x1.0 / x1.5 / x2.0 (échoue avant, vert après) ; à grande police : actions regroupées en un menu et titre qui se réduit, 4 statistiques en 2 × 2, badges l'un sous l'autre, cases de hauteur minimale (84 et 46), ligne de succès qui se replie. Rendu à police normale inchangé.

## 2026-11-10 — Jeu 1-3 : police au maximum, étape 1 (Marché)
- [FIX] Détecteur de coupure (test/detecteur_coupure.dart) et test à police x1.0 / x1.5 / x2.0 sur le Marché (étiquettes, boutons, filtre, objectif, cadeau, collection) ; corrigé : hauteurs minimales au lieu de fixes, plus de limite de lignes qui coupe, grille en 1 colonne à police agrandie, filtre et cadeau qui se replient. Rendu à police normale inchangé.

## 2026-11-10 — Jeu 1-3 : plan de la réparation « police au maximum » (lot 5)
- [DOC] Plan en 3 étapes cadré dans le bloc STATUT (PHASE « 5 Plan à valider »), base git `main` → branche `nickel-police-maximum`. Aucun code touché, aucune branche créée.

## 2026-11-10 — Tri des projets (lot 6)
- [DOC] « Publication Play Store » seule mission active ; « Jeu, missions 1 à 3 » En attente (1) (reste ouverte, défaut police déjà noté) ; « Vérifications terrain » En attente (2). Critère de l'étape 2 écrit d'après la fiche de publication. Branche `publication-test-ferme` non fusionnée, rien touché. `PROMPT_PEAUFINAGE_V2.md` déplacé dans `docs\` (limite de 5 fichiers .md ; aucun renvoi dans les autres fichiers).

## 2026-11-10 — Validation sur émulateur (t2)
- [DOC] Retour d'usage n°5 : mission Close, validée sur émulateur le 2026-11-10 (réserve : essai téléphone de Kinder à sa convenance). Réf. Methode_pilotage_v2CONSTAT_T2.md §6.2.
- [DOC] Jeu, missions 1 à 3 : reste ouverte (police au maximum échouée : boutons coupés au Marché, titre et libellés coupés sur la fiche) ; réparation notée dans PROJET_CONTEXTE.md (« Réparation à planifier »), mission à part après la Revue. Aucune branche touchée ni fusionnée.

- 2026-11-11 — Clôture lot 5 : vérification finale réussie après l'étape 4 ; branche `nickel-police-maximum` envoyée en ligne (non fusionnée) ; mission « En attente de ma capture ».
