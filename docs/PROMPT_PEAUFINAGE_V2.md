# Prompt à coller dans une nouvelle conversation Claude Code

CONTEXTE — projet Nickel, peaufinage V2

Le cadrage V2 est terminé et le périmètre indispensable est construit,
déployé et testé (voir `PROJET_CONTEXTE.md`, section 13-14 : étapes V2-1 à
V2-8). La maison officielle "Chez nous" existe, vide de membres, prête à
être rejointe par Val, Sam et Yo avec le code `3WS3NG`.

Un audit complet a été fait le 2026-09-08 (fin de la conversation
précédente). Il a identifié 8 points faibles réels, pas des suppositions.
Ta mission ici : les traiter un par un, dans l'ordre ci-dessous, avec la
même méthode que tout ce projet.

---

MÉTHODE DE TRAVAIL — impérative, ne pas dévier

- Une mission à la fois, testée manuellement (capture d'écran) avant la
  suivante — jamais deux points du plan en parallèle.
- Cadrage avant exécution sur tout point qui implique un choix (pas
  seulement un correctif mécanique) : UNE option avec sa justification,
  jamais une liste à arbitrer. Poser UNE question si un point est
  bloquant.
- Ne jamais supposer, ne jamais compléter un blanc sans demander.
- Modifier l'existant avant d'en créer du nouveau.
- Ne JAMAIS toucher à la V1 (`public/`, collections `habitants` /
  `taches` / `realisations`) — elle reste en observation réelle par le
  foyer pilote. Tout se passe dans `public/v2/` et les collections
  `maisons` et sous-collections.
- Après chaque point traité : déployer (`firebase deploy`), tester
  toi-même dans le navigateur (créer/rejoindre une maison de test si
  besoin, PUIS LA SUPPRIMER après coup comme dans les étapes précédentes),
  consigner le résultat dans `PROJET_CONTEXTE.md` (nouvelle sous-section
  sous une section 15 "PEAUFINAGE V2", même format que les étapes V2-1 à
  V2-8 : Objectif / Résultat attendu / Critères de validation / Statut).
- Toujours en français, termes fonctionnels.

---

LES 8 POINTS À TRAITER, DANS CET ORDRE

## 1. PWA installable — le plus urgent

**Constat de l'audit** : `/v2/index.html` n'a ni manifest, ni service
worker, ni icône. Val/Sam/Yo devront ouvrir un navigateur et taper une URL
à chaque fois — exactement le point de friction que la V1 avait résolu
(§ 5 et § 11 du contexte, PWA installable sur écran d'accueil).

**À faire** : donner à `/v2/` le même traitement PWA que la V1 —
manifest.webmanifest propre à V2, service worker, icônes (réutiliser
celles de `public/icons/` si le design convient, sinon cadrer une
variante), meta theme-color, apple-touch-icon. Vérifier l'installation
sur écran d'accueil (au moins en émulation mobile dans le navigateur ;
Kinder validera ensuite sur les vrais téléphones).

**Cadrage nécessaire** : le nom affiché sous l'icône ("Nickel" tout court
entrerait en conflit visuel si un jour V1 et V2 coexistent sur le même
téléphone). Proposer une option de nommage distinct et la justifier.

## 2. Retirer un autre membre — l'interface manque

**Constat** : V2-D5 ("droits identiques, un membre peut en retirer un
autre") n'a jamais eu d'écran. Testé une fois via script, jamais dans
l'app.

**À faire** : sur l'écran d'accueil d'une maison, ajouter un moyen de
retirer un membre autre que soi (ex. bouton discret à côté de chaque nom,
sauf le sien). Doit rester cohérent avec "pas de rôle propriétaire" :
n'importe quel membre peut le faire sur n'importe quel autre.

**Cadrage nécessaire** : faut-il une confirmation avant de retirer
quelqu'un (voir point 4) ? Trancher avec le point 4, pas séparément.

## 3. Modifier / supprimer une Pièce ou une Tâche

**Constat** : seule la création existe. Une faute de frappe ou un
ajustement oblige à tout réexporter/réimporter dans une nouvelle maison
(perte du code d'invitation partagé).

**À faire** : ajouter modification (nom, fréquence, produit, astuce) et
suppression d'une Tâche ; modification (nom) et suppression d'une Pièce.

**Cadrage nécessaire** : que devient une Tâche si on supprime sa Pièce ?
(V2-D12 : une tâche appartient obligatoirement à une pièce — supprimer une
pièce qui contient des tâches est donc soit interdit, soit doit
proposer de réassigner les tâches ailleurs. Choisir UNE option et la
justifier, ne pas laisser un état incohérent possible.)
Que devient l'historique (Réalisations) d'une Tâche supprimée ? (Rappel :
une Réalisation n'est jamais modifiée ni supprimée — donc l'historique
doit rester lisible même si la Tâche source a disparu ; l'écran Historique
gère déjà ce cas ("Tâche supprimée") pour les tâches manquantes, vérifier
que ça tient.)

## 4. Confirmation avant les actions à conséquence

**Constat** : "Quitter cette maison", "Fait" (cocher), et le futur
"Retirer un membre" (point 2) sont des actions immédiates et sans
confirmation. La V1 avait déjà identifié ce risque pour cocher sans le
traiter (§ 10, RISQUE IDENTIFIÉ — pas d'annulation).

**À faire** : ajouter une confirmation simple (pas un système
d'annulation complexe) avant : quitter une maison, retirer un membre,
supprimer une pièce ou une tâche. NE PAS ajouter de confirmation avant
"cocher une tâche" — cadrer d'abord : est-ce que ça vaut le coup d'ajouter
de la friction sur le geste central (la boucle qu'on veut la plus fluide
possible), ou est-ce que ça mérite plutôt une action d'annulation de
quelques secondes après coup (piste déjà identifiée en V1 § 10) ? Poser
la question à Kinder plutôt que trancher seul — c'est exactement le genre
d'arbitrage ergonomique qui doit remonter.

## 5. Dette Firestore résiduelle — recherche par code

**Constat** : un client authentifié écrit à la main pourrait lister tous
les noms et codes d'invitation de toutes les maisons (la recherche par
code exige un accès liste sur `maisons`). Documenté dans
`firestore.rules`, mais réel.

**À faire** : évaluer si une réduction du risque est possible sans
casser le parcours "rejoindre par code" (ex. limiter les champs lisibles
en liste à un strict minimum, ou introduire une fonction Cloud pour la
recherche par code plutôt qu'une requête client directe — évaluer le
coût/bénéfice, le plan Firebase actuel est Spark/gratuit, voir si une
Cloud Function reste dans ce plan). Si le coût est disproportionné par
rapport au risque réel (peu de maisons, foyer de confiance), le dire
clairement et ne rien changer plutôt que d'ajouter de la complexité pour
un risque théorique — mais la décision doit être explicite, pas un
oubli.

## 6. Fragilité de l'identité — profil lié à l'appareil

**Constat** : vider les données du navigateur ou réinstaller l'app fait
perdre l'accès sans recours automatique (cohérent avec V2-D2, mais pas
un détail).

**À faire** : rien de structurel à changer ici (V2-D2 reste la décision
validée — pas d'email obligatoire). Mais ajouter un rappel visible dans
l'app : quelque part dans l'écran "Membres" ou dans un écran d'aide,
un texte qui explique que le code d'invitation doit être conservé
quelque part (ex. "notez ce code, il vous permettra de revenir si vous
changez de téléphone"). C'est un correctif d'information, pas de code
complexe.

## 7. Régression visuelle par rapport à la V1

**Constat** : la V1 a une direction artistique aboutie ("le registre
d'entretien", § 11 du contexte — emoji par tâche avec cadre signifiant,
typographie soignée). La V2 réutilise la palette et les polices mais
reste sommaire.

**À faire** : reprendre le travail visuel de la V1 pour l'appliquer aux
écrans V2 (liste des tâches, historique, gestion des pièces). Décider
si l'emoji par tâche revient (et son mécanisme d'attribution — voir
`scripts/seed-emoji.mjs` de la V1 comme référence, mais pas à copier
tel quel puisque V2 a des tâches créées dynamiquement par les
utilisateurs, pas une liste figée de 35 tâches connues à l'avance).

**Cadrage nécessaire** : proposer une option pour l'attribution d'emoji
en V2 (ex. l'utilisateur en choisit un à la création de la tâche, dans
une liste restreinte, plutôt qu'une attribution automatique impossible
à deviner pour une tâche inventée par l'utilisateur) et la justifier
avant de coder.

## 8. Aucune automatisation de test

**Constat** : toute la validation repose sur des vérifications manuelles
ponctuelles. Cohérent avec la méthode du projet (validation manuelle par
capture d'écran, testable par Kinder sans lire de code) — donc PAS un
défaut à corriger par des tests automatisés classiques (ça ajouterait une
couche que Kinder ne peut pas vérifier lui-même).

**À faire** : rien de nouveau à coder. Simplement, à la fin du
peaufinage, repasser manuellement par le test complet de bout en bout
(comme la vérification "les 3 peuvent rejoindre" de la session
précédente) pour s'assurer qu'aucun des 7 points précédents n'a cassé
quelque chose d'autre.

---

À LA FIN

Mettre à jour `PROJET_CONTEXTE.md` avec un bilan de peaufinage (section
15), sur le même modèle que le bilan V2 de la section 14. Ne pas
proposer de nouvelle extension de périmètre à ce stade — le peaufinage
s'arrête aux 8 points listés ici, pas au-delà, sauf si Kinder en
redemande explicitement (même discipline de périmètre que tout le
projet : § 6 « Faisons un point », § RÈGLES NON NÉGOCIABLES).
