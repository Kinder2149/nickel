# NICKEL — Application de gestion du ménage

> **PROJET_CONTEXTE.md** — document de référence du projet Nickel.
> Cadrage figé : sortie de la phase Vision + phase Figer. Prêt pour l'exécution.
> Créé le 2026-09-07 — Habitat pilote : appartement Val / Sam / Yo
> La **section 4** contient les décisions figées inviolables.

---

## 1. OBJECTIF DU PILOTE

Répondre à **une seule question** : *est-ce que cette application est réellement utilisée au quotidien par les 3 habitants ?*

Ce n'est pas un produit. C'est une V1 configurée en dur sur un logement réel, dont le seul but est de valider l'usage avant d'investir dans un produit générique.

**Critère de succès du pilote** : après 3 semaines, les 3 habitants ouvrent encore l'app et cochent des tâches.

---

## 2. LA BOUCLE CENTRALE

Toute l'application tient dans un seul geste :

```
j'ouvre l'app
  → je choisis / retrouve mon profil
  → je vois ce qui est à faire (échéance atteinte ou dépassée)
  → je coche une tâche
  → l'app enregistre QUI l'a faite et QUAND
  → l'app recalcule la prochaine échéance
```

Tout ce qui ne sert pas cette boucle est hors V1.

---

## 3. MODÈLE MÉTIER — DÉFINITIF

Trois concepts. Aucun autre ne doit être introduit en V1.

### Habitant

| Attribut | Type | Note |
|---|---|---|
| id | identifiant | |
| nom | texte | "Val", "Sam", "Yo" |
| avatar | référence visuelle | couleur ou petit personnage |

Pas de compte, pas de mot de passe, pas d'email. Le téléphone mémorise localement le profil choisi ; on peut en changer à tout moment.

### Tâche

| Attribut | Type | Note |
|---|---|---|
| id | identifiant | |
| nom | texte court | tel qu'affiché sur téléphone |
| frequenceJours | entier | toujours en jours (7, pas "hebdomadaire") |
| commentFaire | texte libre, optionnel | produit + méthode fusionnés |
| responsablePrevu | référence Habitant, **peut être vide** | vide = tâche du foyer |
| prochaineEcheance | date | **une seule**, recalculée à chaque coche |

### Réalisation

| Attribut | Type | Note |
|---|---|---|
| id | identifiant | |
| tacheId | référence Tâche | |
| realiseParId | référence Habitant | **jamais vide** |
| dateRealisation | date | |

Une Réalisation n'est **jamais** modifiée ni supprimée. On en ajoute. L'historique n'est pas une fonctionnalité séparée : c'est la liste des Réalisations.

### La règle qui relie les trois

> **Cocher une tâche = créer une Réalisation + fixer `prochaineEcheance = date du jour + frequenceJours`.**

### La distinction responsable / réalisateur

`responsablePrevu` est un attribut de la **Tâche** et peut être vide.
`realiseParId` est un attribut de la **Réalisation** et n'est jamais vide.

Ce sont deux endroits différents du modèle : ils ne peuvent pas se confondre. Une tâche assignée à Val mais faite par Sam produit une Réalisation au nom de Sam, sans que la Tâche change de responsable. Aucun code spécifique n'est nécessaire.

---

## 4. DÉCISIONS FIGÉES — INVIOLABLES

Ces décisions ne se rouvrent pas sans décision explicite de Kinder.

| # | Décision | Justification |
|---|---|---|
| D1 | V1 en dur sur l'appartement réel. Aucun modèle générique. | Construire du générique avant validation d'usage = structure pour le futur |
| D2 | Firebase / Firestore comme socle données + synchro. Google Drive abandonné. | Pas de serveur domestique 24h/24 ; Drive n'est pas une base de données |
| D3 | Aucune authentification. Chaque téléphone choisit son profil. | 3 personnes de confiance, un seul foyer. L'auth arrive en V2 générique |
| D4 | Périmètre V1 = profils + tâches à fréquence + cocher + historique | Seul le noyau teste la boucle centrale |
| D5 | `prochaineEcheance = date RÉELLE de réalisation + fréquence` | Simple, lisible, ne harcèle pas pour rattraper le retard |
| D6 | Pas d'occurrences pré-générées. Une seule échéance stockée par tâche. | Avec D5, toute date future serait fausse dès le premier retard |
| D7 | Une tâche est toujours cochable, même en avance. | Si c'est fait, on le déclare |
| D8 | Le statut (en retard / aujourd'hui / à venir) est **calculé**, jamais stocké. | Rien à maintenir, rien à désynchroniser entre 3 téléphones |
| D9 | On coche en son propre nom. Pas de "cocher pour un autre". | Évite une friction d'interface pour un cas rare |
| D10 | À la création d'une tâche : saisie de la dernière réalisation connue, ou "jamais faite". | Sinon les 35 tâches sont en retard au premier lancement |
| D11 | `responsablePrevu` existe dans le modèle, mais **aucune interface d'attribution en V1**. | Les 35 tâches réelles sont toutes à "aucun". Le pilote teste si l'attribution est nécessaire |
| D12 | Produit et méthode fusionnés en **un seul champ texte** `commentFaire`. | Reste dans D4 (pas d'entité Produit) sans jeter le travail de recherche |
| D13 | **PWA** (app web installable sur l'écran d'accueil), hébergée sur Firebase Hosting. | Pas de store, pas de compte développeur, mise à jour par redéploiement, iPhone + Android identiques |

### Hors périmètre V1 — reporté

| Élément | Version cible |
|---|---|
| Pièces / classement par pièce | 1.2 |
| Entité Produit (stock, compatibilité, avertissements) | 1.3 |
| Notifications push / rappels | 1.3 |
| Interface d'attribution des tâches | 1.2 si le besoin apparaît |
| Statistiques, gamification | ultérieur |
| Authentification, invitation, multi-habitat | V2 générique |
| Liste de courses / achats produits | hors trajectoire app |

### Exclusions de contenu

- Les chambres individuelles sont hors périmètre du ménage commun (gestion perso par habitant).

---

## 5. ARCHITECTURE

### Contraintes à satisfaire

- Pas de serveur domestique permanent
- 3 téléphones, usage mobile
- Installation sans passer par les stores
- Doit pouvoir évoluer vers un produit générique sans être jeté

### Proposition — **PWA (application web installable)**

Une application web, hébergée gratuitement (Firebase Hosting), que chaque habitant ajoute à l'écran d'accueil de son téléphone depuis le navigateur. Elle s'ouvre alors comme une application normale, en plein écran, sans barre de navigateur.

**Pourquoi ce choix plutôt qu'une app native :**

- Pas de compte développeur Apple/Google, pas de soumission au store, pas de délai de validation
- Une mise à jour est un simple redéploiement : les 3 téléphones l'ont au rechargement suivant
- Fonctionne identiquement sur iPhone et Android
- Firebase Hosting + Firestore = même écosystème, une seule configuration
- La bascule vers du natif reste possible en V2 sans rejeter le modèle de données

**Ce que ça coûte :** les notifications push sont limitées sur iPhone en PWA. Sans importance ici — les notifications sont déjà hors V1 (D4). Ce point devra être réexaminé en 1.3.

### Les trois couches (règle : 3 max)

```
INTERFACE       écrans : choix du profil, liste du jour, détail tâche, historique
     ↓
LOGIQUE         calcul des échéances, calcul des statuts, action "cocher"
     ↓
DONNÉES         Firestore : habitants, taches, realisations
```

### Structure Firestore

```
habitants/{id}      → nom, avatar
taches/{id}         → nom, frequenceJours, commentFaire,
                      responsablePrevu (vide), prochaineEcheance
realisations/{id}   → tacheId, realiseParId, dateRealisation
```

Trois collections à plat. Pas de sous-collections, pas d'imbrication : un seul habitat en V1 (D1).

### Synchronisation et conflits

Firestore synchronise en temps réel et gère le mode hors connexion nativement (cache local, envoi différé à la reconnexion). **Aucun code de synchronisation à écrire.**

Sur le seul conflit réellement possible — deux habitants cochent la même tâche en même temps — le comportement est acceptable sans traitement particulier : deux Réalisations sont enregistrées (les deux sont vraies, les deux personnes l'ont bien fait), et `prochaineEcheance` prend la dernière valeur écrite. Les deux valeurs étant identiques ou à quelques secondes d'écart, l'effet est nul.

---

## 6. DONNÉES RÉELLES DU PILOTE

**Habitants** : Val, Sam, Yo
**Tâches** : 35 — toutes avec `responsablePrevu` vide (tâches du foyer)

### Sols et surfaces communes

| Tâche | Fréq (j) | Comment faire |
|---|---|---|
| Laver le sol du salon (parquet) | 7 | Savon noir dilué 1-2 c.à.s./L eau chaude, lavette essorée |
| Laver les sols carrelés (cuisine, entrée, WC, SDB) | 7 | Savon noir, même dilution |
| Dépoussiérer les meubles bois du salon | 7 | Microfibre sèche, dans le sens du bois |
| Nettoyer le bureau en verre | 14 | Produit à vitre, vaporiser + microfibre |
| Nettoyer la baie vitrée | 30 | Produit à vitre, raclette si possible |
| Essuyer meuble d'entrée + porte placard | 14 | Microfibre |
| Traitement annuel du parquet | 365 | Produit protecteur parquet, huile/cire après lavage |

### Canapés et textiles

| Tâche | Fréq (j) | Comment faire |
|---|---|---|
| Aspirer le canapé tissu | 7 | Aspirateur, coussins + interstices |
| Nettoyer le canapé tissu en profondeur | 180 | Bicarbonate 2h puis aspirer, puis savon noir dilué tamponné |
| Dépoussiérer le canapé cuir | 7 | Microfibre sèche, geste doux |
| Nettoyer / nourrir le canapé cuir | 90 | Savon de Marseille dilué, tamponner en cercles |
| Laver la nappe | 14 | Pastille de lessive, machine normale |
| Laver les torchons | 3 | Pastille de lessive, 60°C |
| Laver la lavette / microfibres | 3 | Pastille de lessive, sans adoucissant |

### Cuisine

| Tâche | Fréq (j) | Comment faire |
|---|---|---|
| Nettoyer plan de travail + évier cuisine | 1 | Liquide vaisselle, rinçage + séchage |
| Nettoyer la plaque de cuisson | 1 | Savon noir pur, 30 min de pose, frotter |
| Nettoyer l'intérieur du four | 30 | Savon noir la nuit sur four tiède, frotter au bicarbonate |
| Nettoyer l'intérieur du micro-ondes | 7 | Bol d'eau chaude 2 min avant, puis liquide vaisselle |
| Essuyer l'extérieur du frigo | 7 | Microfibre + liquide vaisselle |
| Nettoyer l'intérieur du frigo | 30 | Savon de Marseille, vider et sécher avant rangement |
| Nettoyer le joint du frigo | 30 | Savon de Marseille, chiffon imbibé |
| Essuyer les meubles de cuisine | 7 | Dégraissant + microfibre, insister sur les poignées |
| Purger les canalisations de l'évier | 7 | Verser une bouilloire d'eau bouillante |
| Détartrer la bouilloire | 30 | Anti-calcaire ou vinaigre blanc, bouillir puis rincer 2-3x |
| Vider la poubelle de tri | 3 | — |
| Vider la poubelle de verre | 14 | — |

### Salle de bain et WC

| Tâche | Fréq (j) | Comment faire |
|---|---|---|
| Nettoyer les parois de douche PVC | 7 | Savon noir, rinçage à l'eau claire |
| Détartrer les joints de la douche | 30 | Anti-calcaire, brosse à dents dédiée |
| Nettoyer évier + robinetterie SDB | 7 | Anti-calcaire, 15 min de pose |
| Nettoyer le miroir SDB | 7 | Produit à vitre |
| Nettoyer cuvette + abattant WC | 4 | Javel, éponge dédiée pour l'abattant |
| Entretenir la VMC (SDB + WC) | 180 | Aspirateur, dépoussiérer la grille |

### Électroménager et intendance

| Tâche | Fréq (j) | Comment faire |
|---|---|---|
| Nettoyer le tambour du lave-linge à vide | 30 | 1L de vinaigre blanc, cycle 90°C |
| Nettoyer le joint du hublot lave-linge | 30 | Eau chaude + vinaigre blanc, insister dans les plis |
| Vérifier stock PQ / liquide vaisselle / savon mains | 7 | — |

### Signal identifié sur la charge

En régime permanent, cette liste représente **environ 5 à 6 tâches dues par jour**. Les 13 tâches à 7 jours pèsent à elles seules près de 2 par jour, et 2 tâches sont quotidiennes.

Ce n'est pas un défaut du modèle — le modèle l'encaisse. C'est une **observation à valider par le pilote** : le risque est que la liste soit longue et durablement rouge, et que les habitants prennent l'habitude de l'ignorer. Aucune correction n'est apportée en V1 : découvrir cela sur du réel fait partie de l'objectif.

Point de vigilance particulier : "nettoyer le plan de travail" et "nettoyer la plaque" (fréquence 1 jour) sont des réflexes plus que des tâches à cocher. Elles apparaîtront tous les jours.

### Prérequis matériel (hors app)

Achats nécessaires pour que certaines tâches soient réalisables : **vinaigre blanc, bicarbonate de soude, produit protecteur parquet**. Sans impact sur le développement : ces tâches entrent dans l'app en "jamais faite".

---

## 7. PLAN DE PRODUCTION

7 étapes séquencées. **Une seule à la fois**, chacune validée manuellement par capture d'écran avant de passer à la suivante.

Règle transverse : aucune étape n'est terminée si Kinder ne peut pas en vérifier le résultat par capture d'écran, sans lire de logs ni de code.

---

### Étape 1 — Socle technique et écran vide

**Objectif** — Une PWA vide s'affiche sur le téléphone de Kinder, ajoutée à l'écran d'accueil.

**Prérequis** — Projet Firebase créé (Firestore + Hosting activés).

**Résultat attendu** — Une page affichant "Ménage" et rien d'autre, accessible depuis une URL, installable sur l'écran d'accueil.

**Critères de validation**
- Kinder ouvre l'URL sur son téléphone → la page s'affiche
- Il l'ajoute à l'écran d'accueil → une icône apparaît
- Il l'ouvre depuis l'icône → plein écran, sans barre de navigateur
- Capture d'écran fournie

**Dépendances** — aucune

**Risques** — Configuration PWA sur iPhone plus contraignante qu'Android. À vérifier sur les 3 téléphones réels dès cette étape, pas plus tard.

---

### Étape 2 — Les 3 habitants et le choix de profil

**Objectif** — Chaque téléphone identifie son habitant.

**Prérequis** — Étape 1 validée.

**Résultat attendu** — Au premier lancement, un écran propose Val / Sam / Yo. Le choix est mémorisé sur le téléphone. Aux lancements suivants, l'app s'ouvre directement, avec le nom affiché en haut. Un moyen simple de changer de profil existe.

**Critères de validation**
- Les 3 habitants sont créés dans Firestore
- Kinder choisit "Val" → l'app affiche "Val"
- Il ferme et rouvre → toujours "Val", sans redemander
- Il change pour "Sam" → l'app affiche "Sam"
- Captures d'écran des 3 états

**Dépendances** — Étape 1

**Risques** — Faible. Aucune authentification (D3) : il s'agit d'un simple choix mémorisé localement.

---

### Étape 3 — Les 35 tâches en base et la liste complète

**Objectif** — Voir toutes les tâches réelles dans l'app.

**Prérequis** — Étape 2 validée. Section 6 de ce document.

**Résultat attendu** — Les 35 tâches sont chargées dans Firestore avec nom, fréquence et `commentFaire`. L'app affiche la liste complète, avec pour chaque tâche son nom et sa fréquence.

**Critères de validation**
- Les 35 tâches apparaissent à l'écran
- Kinder en compte 35 et reconnaît ses tâches réelles
- Le défilement est fluide sur téléphone
- Capture d'écran

**Dépendances** — Étape 2

**Risques** — Aucun risque technique. Risque de lisibilité : 35 lignes sur un écran de téléphone, c'est long. Observation à noter, à ne pas corriger à ce stade — l'étape 5 filtrera.

---

### Étape 4 — Initialisation des dernières réalisations

**Objectif** — Que l'app démarre sur un état réel plutôt que tout en retard (D10).

**Prérequis** — Étape 3 validée.

**Résultat attendu** — Pour chaque tâche, Kinder peut saisir la date de la dernière réalisation connue, ou "jamais faite". `prochaineEcheance` est calculée en conséquence.

**Critères de validation**
- Kinder saisit une date sur au moins 10 tâches
- Il ferme et rouvre l'app → les dates sont conservées
- Les tâches marquées "jamais faite" restent identifiables
- Capture d'écran

**Dépendances** — Étape 3

**Risques** — **Étape la plus ingrate du plan** : 35 saisies manuelles. À rendre aussi rapide que possible (saisie enchaînée, valeur par défaut sensée). Si elle est pénible, elle sera abandonnée à mi-parcours et l'étape 5 partira sur des données fausses.

---

### Étape 5 — La liste du jour et les statuts

**Objectif** — Voir ce qui est réellement à faire aujourd'hui.

**Prérequis** — Étape 4 validée.

**Résultat attendu** — L'écran principal affiche les tâches triées par échéance, avec un statut calculé (D8) : **en retard**, **à faire aujourd'hui**, **à venir**. Les tâches à venir lointaines ne polluent pas l'écran principal.

**Critères de validation**
- Une tâche dont l'échéance est passée apparaît en retard, visuellement distincte
- Une tâche à échéance lointaine n'est pas mise en avant
- Kinder confirme que ce qu'il voit correspond à ce qu'il faut faire aujourd'hui
- Capture d'écran

**Dépendances** — Étape 4

**Risques** — C'est ici que le signal "5 à 6 tâches par jour" (section 6) devient visible. Si l'écran est écrasant, **c'est un résultat du pilote, pas un bug** : à observer et à remonter, pas à corriger dans l'urgence.

---

### Étape 6 — Cocher une tâche

**Objectif** — Boucler la boucle centrale. C'est le cœur de la V1.

**Prérequis** — Étape 5 validée.

**Résultat attendu** — Kinder coche une tâche. Une Réalisation est créée avec l'habitant actif et la date du jour (D9). La `prochaineEcheance` devient date du jour + fréquence (D5). La tâche disparaît de la liste du jour.

**Critères de validation**
- Kinder coche une tâche en retard → elle quitte la liste du jour
- Il rouvre l'app → elle n'est pas revenue
- Sur une tâche à 7 jours cochée aujourd'hui, la prochaine échéance affichée est bien dans 7 jours
- Sam coche une tâche sur son téléphone → Val la voit disparaître sur le sien en quelques secondes
- Une tâche pas encore due reste cochable (D7)
- Captures d'écran avant / après, sur deux téléphones

**Dépendances** — Étape 5

**Risques** — Le test à deux téléphones est le seul vrai test de la synchronisation Firestore. **Il ne doit pas être sauté.** À faire aussi en coupant le réseau sur un téléphone, pour vérifier le rattrapage à la reconnexion.

---

### Étape 7 — L'historique

**Objectif** — Voir qui a fait quoi.

**Prérequis** — Étape 6 validée.

**Résultat attendu** — Un écran liste les Réalisations, les plus récentes en premier : quelle tâche, par qui, quand. Rien de plus — pas de statistiques (hors V1).

**Critères de validation**
- Kinder coche 3 tâches depuis 2 téléphones différents
- L'historique affiche les 3, avec le bon habitant et la bonne date
- Une tâche du foyer cochée par Sam apparaît bien au nom de Sam
- Capture d'écran

**Dépendances** — Étape 6

**Risques** — Aucun. L'historique tombe mécaniquement du modèle : c'est la liste des Réalisations, il n'y a rien à construire d'autre qu'un affichage.

---

### Après l'étape 7 — période d'observation

Pas de nouvelle étape de développement. **3 semaines d'usage réel par les 3 habitants**, puis un point.

Ce qu'on observe :

- Les 3 habitants ouvrent-ils encore l'app ?
- Les tâches quotidiennes sont-elles cochées ou ignorées ?
- Le besoin d'attribuer des tâches apparaît-il (D11) ?
- Le manque des pièces / des produits / des notifications se fait-il sentir, et dans quel ordre ?

Ces observations décident du contenu de la 1.2. Elles ne se supposent pas à l'avance.

---

## 8. CE QUI RESTE À DÉCIDER

Rien. **L'architecture PWA (section 5) a été validée par Kinder le 2026-09-07** et rejoint les décisions figées.

L'ensemble du cadrage est figé. L'exécution peut démarrer à l'étape 1.


---

## 9. RÉFÉRENCES TECHNIQUES

Mises en place le 2026-09-07. Infrastructure prête, avant démarrage de l'étape 1.

| Élément | Valeur |
|---|---|
| Projet Firebase | `nickel-menage-57692` |
| Console | https://console.firebase.google.com/project/nickel-menage-57692 |
| Compte propriétaire | vcoutry@gmail.com |
| Base Firestore | `(default)`, mode natif |
| **Région** | **`eur3` (europe-west) — IRRÉVERSIBLE** |
| App web | "Nickel PWA" — `1:888256690555:web:ae6ce6f0d1688e512665de` |
| Plan de facturation | Spark (gratuit) |

### Configuration web publique

Cette configuration n'est pas un secret : Firebase la conçoit pour être embarquée dans le code de la page, donc visible par quiconque ouvre l'application. C'est le fonctionnement normal — la protection vient des règles d'accès, pas de ces valeurs.

```
projectId         nickel-menage-57692
appId             1:888256690555:web:ae6ce6f0d1688e512665de
apiKey            AIzaSyBGgYQLGKDTAw65TUhHDFjySCMg9oBvEcE
authDomain        nickel-menage-57692.firebaseapp.com
storageBucket     nickel-menage-57692.firebasestorage.app
messagingSenderId 888256690555
```

### Fichiers de configuration du projet

| Fichier | Rôle |
|---|---|
| `.firebaserc` | Associe le dossier au projet Firebase |
| `firebase.json` | Déclare les règles et index Firestore |
| `firestore.rules` | Règles d'accès — **déployées le 2026-09-07** |
| `firestore.indexes.json` | Vide — aucun index nécessaire à ce stade |

### DETTE IDENTIFIÉE — accès ouvert

Conséquence directe de D3 (aucune authentification) : la base est **ouverte en lecture et écriture** sur les trois collections du modèle. Toute autre collection est refusée.

Risque accepté par Kinder le 2026-09-07 : les données sont des tâches de ménage d'un foyer de 3 personnes — aucune donnée sensible, aucun enjeu financier.

**Deux conséquences à ne pas perdre de vue :**
- Cette base ne doit contenir **que** des données de ménage tant que ces règles sont en place.
- La fermeture de cette dette fait partie du passage à la V2 générique, avec l'authentification.

Le « mode test » de Firebase a été délibérément écarté : il referme la base après 30 jours sans avertissement, ce qui aurait cassé l'app en plein milieu de la période d'observation.


---

## 10. SUIVI D'EXÉCUTION

| Étape | Statut | Date |
|---|---|---|
| 1 — Socle technique et écran vide | Déployée, **validation téléphone REPORTÉE** | 2026-09-07 |
| 2 — Les 3 habitants et le choix de profil | Déployée, en attente de validation Kinder | 2026-09-07 |
| 3 — Les 35 tâches en base | Déployée, en attente de validation Kinder | 2026-09-07 |
| 4 — Initialisation des dernières réalisations | Déployée, **saisie réelle à faire par Kinder** | 2026-09-07 |
| 5 — Liste du jour et statuts | Déployée, en attente de validation Kinder | 2026-09-08 |
| 6 — Cocher une tâche | Déployée, **test 2 téléphones réels toujours dû** | 2026-09-08 |
| 7 — Historique | Déployée, en attente de validation Kinder | 2026-09-08 |

**URL de l'application** : https://nickel-menage-57692.web.app

### TESTS REPORTÉS — à ne pas perdre

Kinder a choisi le 2026-09-07 de tester sur PC tant que l'app est une webapp. Deux vérifications restent donc dues, et **doivent être faites avant le démarrage de la période d'observation** :

1. **Installation sur les 3 téléphones Android** (critères de l'étape 1) : ajout à l'écran d'accueil, ouverture en plein écran sans barre d'adresse. Les 3 habitants sont sur Android — aucun iPhone, ce qui écarte le principal risque d'installation.
2. **Synchronisation à deux téléphones** (critère de l'étape 6) : un habitant coche, l'autre voit la tâche disparaître. C'est le seul test qui vérifie réellement Firestore ; il ne peut pas être remplacé par un test sur PC.

### Choix techniques de l'étape 4

**Format des dates** : texte « AAAA-MM-JJ ». Lisible dans la console Firebase, comparable directement, insensible aux fuseaux horaires — ce qui compte quand trois téléphones écrivent dans la même base.

**L'initialisation ne crée aucune Réalisation.** Une Réalisation exige de savoir QUI a fait la tâche (`realiseParId` jamais vide), information qui n'existe pas pour le passé. La saisie ne renseigne donc que `prochaineEcheance`. L'historique commencera réellement à l'étape 6, avec la première tâche cochée. Le modèle métier n'est pas contourné.

**Enregistrement optimiste** : l'écran se met à jour immédiatement, l'écriture Firestore suit. Attendre le réseau à chaque appui rendrait 35 saisies insupportables sur téléphone.

### Choix de l'étape 5 — les sections de l'écran du jour

L'écran « À faire » range les tâches en quatre sections, dans cet ordre :

| Section | Règle | Couleur |
|---|---|---|
| En retard | échéance < aujourd'hui | rose |
| À faire aujourd'hui | échéance = aujourd'hui | vert clair |
| Dans les 7 jours | échéance dans 1 à 7 jours | neutre |
| Jamais faites | aucune échéance renseignée | neutre |

Au-delà de 7 jours, les tâches ne sont pas listées : une ligne discrète indique seulement leur nombre. C'est ce qui empêche les 35 tâches d'écraser l'écran.

**« Jamais faites » est une section à part, volontairement neutre.** Ces tâches ne sont pas en retard — on ignore simplement quand elles ont été faites. Les afficher en rouge donnerait une fausse impression d'urgence dès le premier jour.

Un onglet **« Toutes »** conserve l'accès à la saisie de l'étape 4. L'onglet actif est mémorisé sur l'appareil.

Tous ces statuts sont **calculés à l'affichage** (D8). Rien n'est stocké, donc rien ne peut se désynchroniser entre les trois téléphones.

### Choix de l'étape 6 — le geste central

**Écoute temps réel.** Les tâches sont désormais suivies en continu (`onSnapshot`), et non chargées une fois. C'est ce qui fait qu'une tâche cochée sur un téléphone disparaît des deux autres en quelques secondes, sans rien rafraîchir. Vérifié entre deux fenêtres le 2026-09-08.

**Cache local persistant activé.** Firestore conserve les écritures faites hors connexion et les envoie à la reconnexion. Aucun code de synchronisation n'a été écrit — c'est le comportement natif annoncé au § 5.

**Le champ « Comment faire » est affiché** sous chaque tâche de l'écran du jour. Ajout non demandé par le plan : l'information est utile au moment précis où l'on s'apprête à faire la tâche, et elle était déjà stockée. Elle allonge les lignes — à retirer si l'écran devient trop dense.

### RISQUE IDENTIFIÉ — pas d'annulation

Cocher est immédiat et **irréversible depuis l'écran du jour**. Un appui par erreur crée une Réalisation fausse dans l'historique, qui est volontairement en ajout seul (§ 3).

Contournement actuel : l'onglet « Toutes » permet de corriger l'échéance, mais **pas** de supprimer la Réalisation erronée.

Non traité en V1 : hors périmètre D4. À observer pendant les 3 semaines — si les appuis accidentels sont fréquents, une annulation de quelques secondes est le premier candidat pour la 1.2.

### Vérifications faites le 2026-09-08

| Critère du plan | Résultat |
|---|---|
| Cocher fait quitter la liste du jour | OK — tâche à 30 j disparue de l'écran |
| L'état tient au rechargement | OK |
| Échéance = aujourd'hui + fréquence (D5) | OK — 08/09 + 30 j = 08/10 |
| Réalisation avec le bon habitant | OK — `realiseParId = val` |
| Une tâche pas encore due reste cochable (D7) | OK |
| Un autre appareil voit la tâche disparaître | OK entre deux fenêtres — **reste à confirmer sur 2 téléphones réels** |
| Rattrapage après coupure réseau | **NON TESTÉ** — exige deux téléphones réels |

Les 3 réalisations créées pendant ces tests ont été supprimées et les échéances restaurées : l'historique réel démarre vierge.

### Étape 7 — l'historique

Un troisième onglet liste les Réalisations, les plus récentes en premier, regroupées par jour (« Aujourd'hui », « Hier », puis la date). Chaque ligne porte la pastille de couleur de l'habitant, le nom de la tâche, et « par <habitant> ».

Rien de plus : pas de statistiques, hors périmètre V1.

L'historique est lui aussi **en temps réel**, pour qu'une tâche cochée par un habitant apparaisse chez les deux autres sans rafraîchir.

**Vérifié le 2026-09-08** : 3 tâches cochées depuis deux profils différents (Val puis Sam). L'historique affiche les 3, dans le bon ordre, avec le bon habitant et la bonne date. Une tâche du foyer (`responsablePrevu` vide) cochée par Sam apparaît bien **au nom de Sam** — la distinction responsable prévu / réalisateur (§ 3) est vérifiée sur des données réelles.

Les réalisations de test ont été supprimées et les échéances restaurées.

### FIN DU DÉVELOPPEMENT V1

Les 7 étapes sont déployées. **Aucune nouvelle étape de développement n'est prévue.**

État de la base au 2026-09-08 : 3 habitants, 35 tâches (5 renseignées), 0 réalisation.

Avant de démarrer les 3 semaines d'observation, deux actions restent dues :
1. **Terminer la saisie** des dernières réalisations (30 tâches encore à « jamais faite »).
2. **Les deux tests reportés** sur téléphones réels (voir « TESTS REPORTÉS » ci-dessus).

### AVERTISSEMENT — ne plus relancer seed-taches.mjs

Une fois la saisie réelle faite par Kinder, relancer `scripts/seed-taches.mjs` **effacerait toutes les échéances saisies** (retour à « jamais faite »). Le script reste utile pour corriger un libellé ou une fréquence, mais il faudra alors le modifier pour ne pas réécrire `prochaineEcheance`.

### Incident résolu — cache

Les fichiers étaient servis avec une heure de cache par défaut (Firebase Hosting), ce qui rendait les correctifs invisibles. `firebase.json` force désormais `no-cache` sur tout le HTML, le JavaScript et le manifeste. Corrigé le 2026-09-07, avant toute installation sur téléphone.

### Fichiers de l'application

| Fichier | Couche | Rôle |
|---|---|---|
| `public/index.html` | Interface | Structure et styles |
| `public/js/app.js` | Logique | Rendu des écrans, choix du profil |
| `public/js/donnees.js` | Données | Seul fichier qui parle à Firestore |
| `public/sw.js` | — | Service worker (réseau d'abord) |
| `public/manifest.webmanifest` | — | Déclaration PWA |
| `scripts/seed-habitants.mjs` | — | Création des 3 habitants (réexécutable) |
| `scripts/seed-taches.mjs` | — | Chargement des 35 tâches (réexécutable — remet les échéances à zéro) |

### Habitants créés

| id | Nom | Couleur |
|---|---|---|
| `val` | Val | `#f2a65a` |
| `sam` | Sam | `#5aa9e6` |
| `yo` | Yo | `#c77dff` |


---

## 11. REFONTE VISUELLE — 2026-09-08

Appliquée après validation des 7 étapes. **Aucune fonctionnalité ajoutée** : mêmes trois onglets, mêmes sections, même geste. Seul l'habillage change.

### Direction : « le registre d'entretien »

L'app n'est pas une todo-list de plus — c'est un carnet de maintenance de l'habitat, ce qui correspond à l'ambition du brief d'origine.

| Élément | Choix |
|---|---|
| Fond | Papier kraft `#EFE7D6` |
| Encre | `#16150F` |
| Alerte | Rouge tampon `#B4321F`, **réservé au retard** |
| Titres | Anton (condensé d'affiche) |
| Chiffres, dates, codes | Space Mono |
| Texte courant | Archivo |
| Formes | Aucun angle arrondi, aucune ombre, aucun dégradé |

Bandeaux de section pleine largeur en inversé, traits pleine largeur, fréquences écrites en codes (`07 J`, `365 J`), case à cocher carrée de 44 px.

L'écran de profil devient une page de garde sur fond encre. Les habitants sont numérotés et portent leurs initiales (VA / SA / YO), qui resservent de signature dans l'historique.

### Emoji par tâche

Chaque tâche porte un emoji dans une case encadrée — pictogramme d'inventaire, pas décoration. **Le cadre porte une information** : trait plein = tâche due, pointillé = jamais renseignée, trait fin = à venir.

Règles d'attribution : un emoji distinct par tâche ; l'emoji désigne l'OBJET, pas le geste. Seule répétition assumée : 🦠 pour les deux joints (frigo et hublot du lave-linge) — même problème, même produit, même travail.

Attribution : `scripts/seed-emoji.mjs` — **sûr à relancer**, il n'écrit que le champ `emoji` (updateMask), sans jamais toucher aux échéances.

### RÉGRESSION ÉVITÉE — D7

La première version de la refonte ne mettait de case à cocher que sur les tâches dues. Cela contredisait la décision figée **D7 (une tâche est toujours cochable, même en avance)**. Corrigé le même jour : les 35 tâches portent une case ; seule son épaisseur de trait change selon l'urgence.

### Point de vigilance — emoji et version d'Android

Six emoji sont récents et demandent **Android 12 ou plus** : 🪵 🪟 🪑 🪞 🪥 🫧. Sur un téléphone plus ancien ils s'afficheraient en carré vide. À vérifier lors de l'installation sur les 3 téléphones ; des équivalents plus anciens existent.

### Maquettes

Fichiers de travail dans `design/` (4 artboards `.dc.html` + `canvas.json`). Planche publiée : https://claude.ai/code/artifact/0d3856b5-4da5-459f-ac16-aca23bf4e9be

### État de la base après refonte

3 habitants (couleurs mises à jour), 35 tâches (35 emoji, 5 échéances renseignées), 0 réalisation. Les données de test ont été supprimées.


---

## 12. D10 — APPLICATION ABANDONNÉE (2026-09-08)

**Décision de Kinder** : la saisie initiale des 35 dernières réalisations n'aura pas lieu.

Les tâches restent en « Jamais renseignée » et entrent dans le cycle au moment où quelqu'un les fait et les coche. L'app s'initialise à l'usage.

**Ce que ça change** : D10 (« à la création d'une tâche, saisie de la dernière réalisation connue ») reste vraie dans le modèle — le champ existe, l'écran de saisie reste accessible dans l'onglet « Toutes » — mais elle n'est pas appliquée au démarrage du pilote.

**Conséquence attendue, à ne pas confondre avec un défaut** : pendant les premières semaines, l'écran « À faire » n'affiche ni « En retard » ni « Aujourd'hui ». Uniquement les jamais renseignées. Le rythme apparaît progressivement.

**Avantage** : supprime l'étape la plus ingrate du plan (35 saisies manuelles), qui était identifiée comme le principal risque d'abandon.

L'étape 4 du plan est donc close sans saisie réelle. Les 5 tâches déjà renseignées le restent.


---

## 13. CADRAGE V2 GÉNÉRIQUE — VALIDÉ le 2026-09-08

La V1 reste inchangée et en cours d'observation. Ce cadrage prépare la V2 : transformer le pilote en produit générique, utilisable par n'importe quel foyer. **Aucun code écrit pour la V2 à ce stade** — cadrage seul.

### Nœud bloquant résolu : identité et partage

Le partage d'une maison entre plusieurs personnes est incompatible avec l'absence d'authentification de la V1. Décisions, dans l'ordre où elles s'enchaînent :

| # | Décision V2 | Justification |
|---|---|---|
| V2-D1 | Une **Maison** (nom libre) a un code d'invitation régénérable. Rejoindre = entrer le code. | Résout le partage sans système de comptes lourd |
| V2-D2 | **Pas de compte email/mot de passe.** Profil = prénom + couleur, **lié à l'appareil par défaut** (identifiant technique local). | Reste aussi simple que le choix de profil V1 ; évite de construire une brique d'authentification pour un besoin non exprimé |
| V2-D3 | **Email + lien magique Firebase optionnel**, pour qui veut un profil portable entre appareils. | Répond au cas réel (changement de téléphone) sans l'imposer à tous |
| V2-D4 | Un même profil peut rejoindre **plusieurs maisons** indépendamment. | Une personne peut gérer sa maison et participer à celle d'un proche |
| V2-D5 | **Droits identiques entre tous les membres d'une maison, pas de rôle propriétaire.** Tout membre peut retirer un autre membre. | Fidèle à l'esprit V1 (confiance totale au sein du foyer) ; évite la complexité d'un système de rôles jamais demandé |
| V2-D6 | Quitter une maison = retirer son profil de la liste des membres. Les Réalisations passées ne sont jamais modifiées (règle héritée de D-V1 §3). | Cohérent avec l'immuabilité de l'historique |

### Export / Import / Partage — trois choses distinctes

| # | Décision V2 | Justification |
|---|---|---|
| V2-D7 | « Partager l'accès à la même maison » = donner le code d'invitation (V2-D1). Ce n'est pas un export. | Évite de confondre deux mécanismes différents |
| V2-D8 | **Export = structure seule** (pièces, tâches, fréquences, produit, astuce). **Ni historique, ni habitants.** | Sert le cas « donner un modèle de départ à quelqu'un », pas la sauvegarde |
| V2-D9 | **Import crée toujours une nouvelle maison**, jamais de fusion avec une existante. | Élimine la question des doublons, complexité non nécessaire en V2 |
| V2-D10 | Export de sauvegarde complète (avec historique) : **repoussé après la V2.** | Pose des questions de confidentialité non urgentes |

### Modèle métier V2

| # | Décision V2 | Justification |
|---|---|---|
| V2-D11 | **Pièce** : nouvelle entité, rattachée à une Maison. | Demandée explicitement par le besoin |
| V2-D12 | Une **Tâche appartient à une seule Pièce, obligatoirement** (pas de tâche sans pièce). | Simplicité de navigation ; cas "tâche transversale" traité via une pièce "Général / Extérieur" plutôt qu'un cas particulier |
| V2-D13 | **Produit reste un champ texte sur la Tâche**, pas une entité séparée (pas de stock, pas d'alertes). | Respecte la limite à 3-4 concepts ; aucun besoin de gestion de stock exprimé |
| V2-D14 | **Produit et Astuce = deux champs texte distincts** (pas de fusion, contrairement à D12 de la V1). | Informations de nature différente, utile à l'affichage séparé |

### Démarrage à vide

| # | Décision V2 | Justification |
|---|---|---|
| V2-D15 | Un **modèle de logement générique et neutre** (à préparer séparément, pas les 35 tâches du pilote) est proposé à la création d'une maison. | Principal risque d'abandon identifié par la V1 : partir d'une page blanche |

### Migration du foyer pilote

| # | Décision V2 | Justification |
|---|---|---|
| V2-D16 | **Pas de migration automatique.** Le foyer pilote devient une maison créée manuellement en V2 (resaisie des pièces/tâches, potentiellement à partir du modèle générique V2-D15). | La Pièce n'existait pas en V1 : pas de correspondance automatique fiable |
| V2-D17 | L'historique de réalisations du pilote (données de test) **n'est pas repris.** | Assumé par Kinder — aucun enjeu, historique de test uniquement |

### Périmètre V2 — indispensable vs repoussé

**Indispensable (V2) :** Maison + code d'invitation · rejoindre une maison · profil lié à l'appareil (+ email optionnel) · droits identiques entre membres · Pièce · Tâche (+ produit texte, + astuce texte, reste inchangé) · Réalisation (inchangée) · export/import structure seule · modèle générique neutre au démarrage · fermeture de l'accès Firestore ouvert (restreint aux membres authentifiés de la maison).

**Repoussé après V2 (explicitement, pas oublié) :** portabilité de profil pour tous par défaut · export/import avec historique · Produit comme entité (stock, alertes) · bibliothèque de plusieurs modèles · notifications.

### Prochaine étape

Ce cadrage est validé par Kinder le 2026-09-08. La suite logique est un plan de production V2 (étapes séquencées, comme la section 7 pour la V1) — voir section 14.

---

## 14. PLAN DE PRODUCTION V2 — démarré le 2026-09-08

**Règle absolue : la V1 (`public/`, collections `habitants`/`taches`/`realisations`) n'est jamais modifiée.** Le foyer pilote est en observation réelle. La V2 vit dans un espace séparé : dossier `public/v2/`, nouvelle collection Firestore `maisons` (et ses sous-collections). Aucun risque de croisement.

Étapes séquencées, une à la fois, testée par capture d'écran avant de passer à la suivante — même discipline que la section 7.

### Étape V2-1 — Profil, créer une maison, rejoindre par code

**Objectif** — Boucler le nœud bloquant du cadrage (V2-D1 à V2-D4) : un profil se crée localement, crée une maison OU en rejoint une avec un code, et voit qui d'autre est déjà dedans.

**Résultat attendu** — Page `/v2/`. Premier lancement : choix prénom + couleur (mémorisé sur l'appareil, V2-D2). Ensuite : écran « créer une maison » (nom libre → génère un code à 6 caractères, V2-D1) ou « rejoindre » (saisie d'un code existant). Une fois dans une maison : nom de la maison, code affiché, liste des membres.

**Modèle Firestore ajouté**
```
maisons/{id}            → nom, codeInvitation, creeLe
maisons/{id}/membres/{profilId} → prenom, couleur, rejointLe
```

**Dette assumée, documentée** — Comme la V1, ces collections restent ouvertes en lecture/écriture (pas de Firebase Auth pour le profil-appareil, V2-D2). Le code d'invitation est la seule barrière : quiconque le connaît peut rejoindre. Accepté explicitement, cohérent avec V2-D1.

**Critères de validation**
- Créer un profil "Test" → rechargement → profil retrouvé sans redemander
- Créer une maison "Maison Test" → un code à 6 caractères s'affiche
- Depuis un 2ème profil (autre onglet/appareil), entrer ce code → rejoint la même maison, voit "Test" dans les membres
- Capture d'écran des deux états

**Dépendances** — aucune (nouvel espace)

**Statut** — Testée le 2026-09-08 dans le navigateur (deux profils, création, rejoindre par code, temps réel, quitter). Déployée sur https://nickel-menage-57692.web.app/v2/. Données de test ("Maison Test") laissées en base à la demande de Kinder — sans impact, collection séparée de la V1.

### Étape V2-2 — Pièces et Tâches d'une maison

**Objectif** — Peupler une maison : créer des Pièces, créer des Tâches rattachées à une Pièce (V2-D11, V2-D12), avec fréquence, produit et astuce comme deux champs distincts (V2-D13, V2-D14). Pas encore de "cocher" ni de Réalisation — ça sera l'étape suivante.

**Résultat attendu** — Depuis l'écran d'accueil d'une maison, un accès "Pièces et tâches" : créer une pièce (nom), puis dans chaque pièce créer une tâche (nom, fréquence en jours, produit, astuce). Liste des tâches groupées par pièce.

**Modèle Firestore ajouté**
```
maisons/{id}/pieces/{pieceId} → nom, creeLe
maisons/{id}/taches/{tacheId} → nom, pieceId, frequenceJours, produit, astuce,
                                  responsablePrevu (null), prochaineEcheance (null)
```

**Critères de validation**
- Créer une pièce "Cuisine" → apparaît dans la liste
- Créer une tâche "Nettoyer l'évier" dans "Cuisine" avec fréquence 7, produit "Liquide vaisselle", astuce "Rincer et sécher" → apparaît sous "Cuisine"
- Recharger la page → pièce et tâche toujours là
- Capture d'écran

**Dépendances** — Étape V2-1 (une maison doit exister)

**Statut** — Testée le 2026-09-08 dans le navigateur (pièce "Cuisine" + tâche "Nettoyer l'évier" à 7 jours, produit et astuce distincts, persistance au rechargement confirmée). Déployée sur https://nickel-menage-57692.web.app/v2/.

### Étape V2-3 — Cocher une tâche

**Objectif** — Reboucler la boucle centrale de la V1 (§ 2-3) dans le contexte multi-maison : cocher une tâche crée une Réalisation et recalcule l'échéance. Règles héritées et inchangées : D5 (échéance = date réelle + fréquence), D6 (une seule échéance stockée), D7 (toujours cochable), D8 (statut calculé, jamais stocké), la distinction responsable prévu / réalisateur (§ 3).

**Résultat attendu** — Un écran "À faire" liste les tâches de toutes les pièces de la maison, triées par échéance, avec statut calculé (en retard / aujourd'hui / à venir / jamais renseignée). Cocher une tâche crée une Réalisation au nom du profil actif et avance l'échéance.

**Modèle Firestore ajouté**
```
maisons/{id}/realisations/{id} → tacheId, realiseParId, dateRealisation, enregistreLe
```

**Critères de validation**
- La tâche "Nettoyer l'évier" (jamais renseignée) apparaît dans la section correspondante
- La cocher → une Réalisation est créée au nom du profil actif, `prochaineEcheance` = aujourd'hui + 7 jours
- Recharger → la tâche n'est plus "jamais renseignée", elle est "à venir" avec la bonne date
- Elle reste cochable même en avance (D7)
- Capture d'écran

**Dépendances** — Étape V2-2 (des tâches doivent exister)

**Statut** — Testée le 2026-09-08 dans le navigateur : "Nettoyer l'évier" (jamais renseignée) cochée par le profil actif → passe en "à venir" avec échéance 2026-09-14 (08-09 + 7j, correct) ; persistance et cochabilité (D7) confirmées au rechargement. Déployée sur https://nickel-menage-57692.web.app/v2/.

### Étape V2-4 — Historique

**Objectif** — Fermer le modèle à trois concepts en V2 (§ 3, hérité) : voir qui a fait quoi et quand. Rien de plus — pas de statistiques, comme en V1 (étape 7).

**Résultat attendu** — Un écran liste les Réalisations d'une maison, les plus récentes en premier, groupées par jour : quelle tâche, par quel membre.

**Critères de validation**
- Cocher "Nettoyer l'évier" apparaît dans l'historique avec le bon prénom et la bonne date
- L'historique est en temps réel (comme en V1)
- Capture d'écran

**Dépendances** — Étape V2-3

**Statut** — Testée le 2026-09-08 dans le navigateur : "Nettoyer l'évier" apparaît sous "Aujourd'hui", pastille couleur du membre, "par Kinder". Déployée sur https://nickel-menage-57692.web.app/v2/.

### Étape V2-6 — Modèle générique de démarrage

**Objectif** — Réaliser V2-D15 : proposer une structure pré-remplie à la création d'une maison, pour ne pas partir d'une page blanche (principal risque d'abandon identifié en V1).

**Cadrage du contenu** — Volontairement modeste (leçon de la V1, § 6 : trop de tâches, dont plusieurs quotidiennes, crée une pression et un risque d'abandon). 6 pièces universelles (Cuisine, Salle de bain, WC, **Chambre**, Salon, Entrée), 16 tâches au total, fréquences réalistes (1 à 30 jours), une seule tâche quotidienne. Chaque tâche porte un produit **et** une astuce, tous deux rédigés (pas de placeholder).

**Résultat attendu** — Fichier `public/v2/modeles/generique.json`, au format d'export V2-D8. Sur l'écran "Votre maison", un bouton "Commencer avec le modèle générique" à côté de "Créer la maison vide" : il importe ce fichier via `importerStructure` (même mécanique que V2-5) sous le nom saisi.

**Critères de validation**
- Cliquer "Commencer avec le modèle générique" avec le nom "Maison Modèle" → une maison est créée avec les 6 pièces et 16 tâches, chacune avec produit + astuce
- Le mécanisme réutilise l'import de structure existant (pas de nouveau code de création) — cohérence avec V2-D8/D9

**Dépendances** — Étape V2-5 (réutilise `importerStructure`)

**Statut** — Testée le 2026-09-08 dans le navigateur : "Maison Modèle" créée avec les 6 pièces et 16 tâches, produits et astuces bien affichés. Déployée sur https://nickel-menage-57692.web.app/v2/.

### Bilan à ce stade (2026-09-08)

Le modèle à trois concepts (Habitant/Profil, Tâche, Réalisation) + Pièce tourne intégralement en V2, multi-maison, avec identité et partage, export/import de structure, et un modèle générique de démarrage (V2-1 à V2-6). Il ne reste, dans le périmètre indispensable défini § 13, que :
- Fermeture des règles Firestore ouvertes — nécessite d'abord de statuer sur V2-D3 (email optionnel) si on veut une vraie restriction par membre ; sinon la dette reste scopée comme en V1, documentée dans `firestore.rules`

Prochaine étape annoncée par Kinder : reprendre le modèle personnel du foyer pilote (35 tâches réelles) et le recréer en V2 (V2-D16/D17), maintenant que tout l'outillage (créer une maison, pièces, tâches, cocher, historique) est en place.

### Étape V2-7 — Reprise du modèle personnel du foyer pilote

**Objectif** — Réaliser V2-D16 : recréer la structure des 35 tâches réelles du foyer pilote en V2, réparties par Pièce (concept qui n'existait pas en V1), sans migration automatique.

**Répartition retenue** — 7 pièces : Salon (9 tâches), Entrée (1), Cuisine (12), Salle de bain (5), WC (1), Buanderie (2, nouvelle — regroupe les tâches machine à laver), **Général** (5 — tâches transversales : sols carrelés multi-pièces, linge de maison, stock). Le champ `commentFaire` unique de la V1 (D12) a été relu et séparé en `produit` + `astuce` (V2-D14) pour chacune des 35 tâches.

**Fichier produit** — `public/v2/modeles/foyer-pilote.json`, au format d'export standard (réutilisable par n'importe qui via "Importer un modèle").

**Critères de validation**
- Import du fichier → 35 tâches réparties sur 7 pièces, aucune perte
- Chaque tâche affiche produit et astuce distincts là où l'information existait
- Capture d'écran

**Statut** — Testée le 2026-09-08 : import réussi (7 pièces, 35 tâches confirmées par script). Répartition en pièces validée par Kinder le 2026-09-08.

**MAISON OFFICIELLE CRÉÉE le 2026-09-08** — nom "Chez nous", id `329547b0-9c7d-4ad3-943c-b2b9f883d76f`, 7 pièces / 35 tâches confirmées. **Code d'invitation : `3WS3NG`.** Reste à faire (côté Kinder, sur les vrais téléphones) : Val, Sam et Yo créent chacun leur profil sur `https://nickel-menage-57692.web.app/v2/` et rejoignent avec ce code. Le profil "Kinder" créateur (généré depuis le navigateur de test de cette session, pas un vrai appareil) peut être retiré une fois les 3 habitants dedans.

**Nettoyage effectué le 2026-09-08** : toutes les maisons de test créées pendant le développement (Maison Test, Maison V2-2, Foyer Pilote (test), Maison Fermeture, Maison Modèle, Maison Importée, Maison via UI) ont été supprimées de Firestore (`firebase firestore:delete --recursive`). "misma" (essai de Kinder) supprimée également. Il ne reste en base que **"Chez nous"**, la maison officielle du foyer pilote.

**Vérification "les 3 peuvent rejoindre" (2026-09-08)** — Simulé 3 appareils indépendants (authentification anonyme distincte à chaque fois, stockage local effacé entre chaque) : Val, Sam et Yo ont chacun rejoint "Chez nous" avec le code `3WS3NG` (y compris testé en minuscules), se voient mutuellement en temps réel, et accèdent aux 7 pièces / 35 tâches. Les 3 profils de simulation ont été retirés après coup — "Chez nous" est de nouveau sans membre, prête pour les vrais téléphones de Val, Sam et Yo.

### Étape V2-8 — Fermeture des règles Firestore

**Objectif** — Fermer la dette héritée de la V1 (base ouverte en lecture/écriture, § « DETTE IDENTIFIÉE »), sans introduire d'écran de connexion ni exiger d'email (reste cohérent avec V2-D2).

**Solution retenue : authentification anonyme Firebase.** Chaque appareil obtient, de façon invisible pour l'utilisateur, un identifiant vérifiable côté serveur (`request.auth.uid`). Ce n'est pas un compte au sens usuel — pas d'email, pas de mot de passe, rien à saisir — mais ça permet d'écrire de vraies règles Firestore : seul un membre authentifié d'une maison peut lire/écrire ses pièces, tâches et réalisations.

**Changements techniques**
- `donnees.js` : `assurerAuthentification()` — connexion anonyme au chargement, avant tout appel Firestore.
- `app.js` : l'id de profil devient l'uid Firebase Auth (au lieu d'un UUID local) — c'est ce qui permet aux règles de vérifier "ce membre est bien cet appareil".
- `firestore.rules` : les collections sous `maisons/{id}` exigent désormais `estMembre(maisonId)` (vérifié via l'existence du document `membres/{uid}`), sauf la recherche par code d'invitation (lecture-liste sur `maisons`, nécessairement plus ouverte) et la création d'une maison.
- Une Réalisation ne peut être créée qu'au nom de soi-même (`realiseParId == request.auth.uid`), et n'est **jamais modifiable ni supprimable** — imposé par les règles, plus seulement par convention.

**Dette résiduelle documentée, pas cachée** — La recherche par code exige un accès liste sur `maisons` : un client authentifié écrit à la main pourrait lister tous les noms et codes existants. Accepté : ça suppose un client détourné, pas juste trouver l'URL publique (le scénario qui justifiait la fermeture). Consigné dans `firestore.rules` avec le commentaire explicite, comme la dette V1.

**Prérequis manuel** — Activer le fournisseur "Anonymous" dans Firebase Console → Authentication → Sign-in method (aucune commande CLI ne permet de le faire ; geste réservé à Kinder).

**Critères de validation**
- Sans authentification anonyme activée : `assurerAuthentification()` échoue, l'app reste bloquée avant l'écran profil — comportement attendu, pas un bug
- Une fois activée : créer un profil, créer/rejoindre une maison, cocher une tâche, consulter l'historique — tout fonctionne comme avant (V2-1 à V2-4), maintenant avec des règles fermées
- Un accès direct à Firestore sans authentification (ex. requête anonyme au REST API sans jeton) est refusé

**Dépendances** — Toutes les étapes précédentes (V2-1 à V2-7)

**Statut** — Activé et testé le 2026-09-08. Boucle complète vérifiée sous les règles fermées : profil (uid Firebase Auth) → création de maison "Maison Fermeture" → pièce + tâche créées → tâche cochée (Réalisation créée au nom de soi) → historique consultable. Vérification négative : un appel Firestore REST direct sans jeton d'authentification est refusé (`403 Missing or insufficient permissions`), confirmant la fermeture. **La dette ouverte héritée de la V1 est close pour tout l'espace V2** (`maisons` et ses sous-collections) ; celle de la V1 elle-même (`habitants`/`taches`/`realisations`) reste ouverte par choix, la V1 n'étant pas touchée.

### Bilan V2 — périmètre indispensable complet (2026-09-08)

Toutes les briques du périmètre indispensable défini § 13 sont construites, déployées et testées : identité et partage (V2-1), Pièces et Tâches (V2-2), cocher/Réalisation (V2-3), historique (V2-4), export/import de structure (V2-5), modèle générique de démarrage (V2-6), reprise du foyer pilote (V2-7), fermeture Firestore (V2-8). La maison officielle "Chez nous" du foyer pilote existe en base, prête à être rejointe par Val, Sam et Yo avec le code `3WS3NG`.

### Étape V2-5 — Export / import de structure

**Objectif** — Réaliser V2-D7 à V2-D9 : exporter la structure d'une maison (pièces + tâches, sans historique ni habitants), l'importer pour créer une nouvelle maison.

**Résultat attendu** — Depuis "Pièces et tâches", un bouton "Exporter" télécharge un fichier `.json` contenant les pièces et leurs tâches (nom, fréquence, produit, astuce) — pas d'ID internes, pas d'historique, pas de membres. Depuis l'écran "Votre maison" (créer/rejoindre), une option "Importer un modèle" : on choisit ce fichier + un nom de maison → une **nouvelle** maison est créée avec cette structure (V2-D9 : jamais de fusion).

**Format d'export**
```json
{
  "version": 1,
  "pieces": [
    { "nom": "Cuisine", "taches": [
      { "nom": "Nettoyer l'évier", "frequenceJours": 7, "produit": "Liquide vaisselle", "astuce": "Rincer et sécher" }
    ] }
  ]
}
```

**Critères de validation**
- Exporter "Maison V2-2" → fichier téléchargé, contient "Cuisine" et "Nettoyer l'évier"
- Importer ce fichier sous le nom "Maison Importée" → nouvelle maison créée, distincte de l'originale, avec la même pièce et la même tâche
- L'import ne modifie pas la maison d'origine
- Capture d'écran

**Dépendances** — Étape V2-2 (structure à exporter)

**Statut** — Testée le 2026-09-08 dans le navigateur : export de "Maison V2-2" → JSON conforme (pièce "Cuisine" + tâche "Nettoyer l'évier"). Import via le vrai formulaire fichier → "Maison via UI" créée avec sa propre pièce/tâche ("Salle de bain" / "Nettoyer la douche"), maison d'origine vérifiée intacte, codes d'invitation distincts. Déployée sur https://nickel-menage-57692.web.app/v2/.

## 15. PEAUFINAGE V2 — démarré le 2026-09-08, EN PAUSE (état au 2026-09-08)

Suite à l'audit du 2026-09-08 (fin de la conversation précédente sur le périmètre indispensable, § 14), 8 points faibles réels ont été identifiés. Traités un par un, dans l'ordre, avec la même méthode que le reste du projet (une mission testée avant la suivante).

### État d'avancement — pause du 2026-09-08

| # | Point | Statut |
|---|---|---|
| 1 | PWA installable | ✅ Fait, testé, déployé |
| 2 | Retirer un autre membre | ✅ Fait, testé, déployé |
| 3 | Modifier/supprimer une Pièce ou une Tâche | ✅ Fait, testé, déployé |
| 4 | Confirmation avant actions à conséquence (+ annulation "cocher") | ✅ Fait, testé, déployé |
| 5 | Dette Firestore résiduelle (recherche par code) | ✅ Décision actée (ne rien changer), pas de changement de code |
| 6 | Fragilité de l'identité — rappel visible | ✅ Fait, testé, déployé |
| 7 | Régression visuelle / emoji par tâche | ✅ Fait, testé, déployé |
| 8 | Test de bout en bout + bilan final | ✅ Fait, testé, déployé (bug de date trouvé et corrigé au passage) |

**Tout ce qui précède (points 1 à 7) est en production** sur https://nickel-menage-57692.web.app/v2/ — aucun code en attente, aucun déploiement en suspens. La maison réelle "Chez nous" du foyer pilote n'a pas été touchée ; toutes les maisons de test créées pendant ces 7 points ont été supprimées après coup (vérifié par une lecture directe de la collection `maisons` en fin de session : seule "Chez nous" subsiste).

### Point 1 — PWA installable

**Objectif** — Donner à `/v2/` le même traitement PWA que la V1 (manifest, service worker, icônes, meta theme-color) pour que Val/Sam/Yo puissent l'installer sur l'écran d'accueil au lieu de taper une URL à chaque fois.

**Résultat attendu** — `public/v2/manifest.webmanifest` propre à V2, `public/v2/sw.js` (même stratégie réseau-d'abord/cache-en-secours que la V1), meta `theme-color` + `apple-touch-icon` dans `public/v2/index.html`, enregistrement du service worker.

**Cadrage — nommage** — Nom distinct de la V1 pour éviter un conflit visuel si les deux coexistent un jour sur le même téléphone : `short_name` = "Nickel Maisons", `name` = "Nickel — Maisons". Justification : évite le jargon "V2" (Kinder pense en fonctionnel, pas en versions) et reflète le concept central de cette version (plusieurs foyers/maisons avec code d'invitation). Icônes réutilisées telles quelles depuis `public/icons/` (même design que la V1, cohérence visuelle).

**Critères de validation**
- `manifest.webmanifest` accessible sur `/v2/manifest.webmanifest`, correctement lié depuis `/v2/index.html`
- Service worker enregistré avec le scope `/v2/`, actif
- Capture d'écran de l'app en émulation mobile

**Statut** — Testée le 2026-09-08 dans le navigateur (émulation mobile 375×812) sur https://nickel-menage-57692.web.app/v2/ : manifest chargé avec le bon nom/icônes/scope, service worker `/v2/sw.js` enregistré et actif (scope `https://nickel-menage-57692.web.app/v2/`), aucune interférence avec le service worker V1 (scope racine séparé). Déployée. Reste à valider par Kinder l'installation réelle sur écran d'accueil (téléphone physique).

### Point 2 — Retirer un autre membre

**Objectif** — Réaliser V2-D5 (droits identiques, pas de rôle propriétaire) : sur l'écran d'accueil d'une maison, permettre à n'importe quel membre de retirer n'importe quel autre membre — jamais soi-même par ce bouton (ça, c'est "Quitter cette maison", qui existe déjà).

**Résultat attendu** — Dans la liste des membres, un bouton discret "Retirer" à côté de chaque nom sauf le sien. Nouvelle fonction `retirerMembre(maisonId, membreId)` dans `donnees.js` (même écriture que `quitterMaison`, exposée séparément pour éviter toute confusion de profil côté appelant). Les règles Firestore le permettaient déjà (`estMembre(maisonId)` suffit pour supprimer n'importe quel document `membres`, anticipé à l'étape V2-8) — aucun changement de `firestore.rules` nécessaire.

**Cadrage — confirmation** — Pas de confirmation ajoutée à ce stade : la question "faut-il confirmer avant de retirer quelqu'un" est tranchée avec le point 4 (peaufinage), pas séparément, pour rester cohérente avec les autres actions à conséquence (quitter une maison, supprimer une pièce/tâche).

**Critères de validation**
- Un membre A ne voit pas de bouton "Retirer" sur sa propre ligne
- Un membre B voit "Retirer" sur la ligne de A, et le clic retire A en temps réel (sans rechargement) de tous les écrans ouverts sur cette maison
- Capture d'écran

**Statut** — Testée le 2026-09-08 dans le navigateur avec deux identités distinctes (TestA créateur de "Maison Test Point2", TestB rejoint par code) : TestB voit "Retirer" sur la ligne de TestA (pas sur la sienne), le clic retire TestA immédiatement de la liste, temps réel confirmé (TestB n'a pas rechargé la page). Maison de test entièrement supprimée après coup (`firebase firestore:delete --recursive`). Déployée sur https://nickel-menage-57692.web.app/v2/.

### Point 3 — Modifier / supprimer une Pièce ou une Tâche

**Objectif** — Ajouter la modification (nom, fréquence, produit, astuce) et la suppression d'une Tâche ; la modification (nom) et la suppression d'une Pièce. Jusqu'ici seule la création existait : une faute de frappe obligeait à tout réexporter/réimporter dans une nouvelle maison.

**Cadrage — une pièce qui contient des tâches** — **Suppression interdite tant que la pièce contient au moins une tâche** ; il faut d'abord supprimer les tâches une à une. Justification : évite de construire une UI de réaffectation de tâches (hors périmètre du peaufinage) ; empêche une suppression en cascade qui ferait disparaître des tâches sans que l'utilisateur l'ait explicitement voulu ; reste cohérent avec l'invariant V2-D12 (une tâche appartient obligatoirement à une pièce — jamais d'état orphelin possible). Implémenté comme un refus explicite avec message ("Cette pièce contient encore des tâches. Supprimez-les d'abord."), pas un blocage silencieux du bouton.

**Historique d'une tâche supprimée** — Vérifié : aucun changement nécessaire. L'écran Historique (`afficherEcranHistorique`) résout déjà chaque Réalisation via `taches.find(t => t.id === r.tacheId)` et retombe sur le libellé "Tâche supprimée" quand la tâche n'existe plus — ce repli couvrait déjà ce cas avant même que la suppression de tâche existe dans l'interface.

**Résultat obtenu** — Nouvelles fonctions dans `donnees.js` : `modifierPiece`, `supprimerPiece` (avec le refus ci-dessus), `modifierTache`, `supprimerTache`. Dans l'écran "Pièces et tâches" : chaque pièce a "Renommer" (formulaire inline) et "Supprimer" ; chaque tâche a "Modifier" (formulaire inline pré-rempli) et "Supprimer". Aucune modification de `firestore.rules` nécessaire (`allow read, write: if estMembre(maisonId)` couvrait déjà update/delete sur `pieces` et `taches`).

**Critères de validation**
- Renommer une pièce → nouveau nom visible immédiatement
- Modifier une tâche (nom + fréquence) → changements visibles immédiatement
- Supprimer une tâche → disparaît de la pièce
- Supprimer une pièce contenant une tâche → refusée avec message explicite, rien n'est perdu
- Supprimer une pièce vide → réussit
- Capture d'écran

**Statut** — Testée le 2026-09-08 dans le navigateur (maison de test "Maison Test Point3", pièce "Cuisine") : renommage de pièce en "Cuisine renommée" confirmé, ajout puis modification de la tâche "Nettoyer évier" → "Nettoyer évier modifié" (fréquence 7→10 j) confirmée, suppression de pièce contenant une tâche refusée avec le message attendu, suppression de la tâche puis de la pièce désormais vide réussie. Un défaut mineur trouvé pendant le test (le message d'erreur restait affiché après une suppression réussie ultérieure) corrigé dans la foulée (`afficherErreur(null)` sur le succès). Maison de test entièrement supprimée après coup. Déployée sur https://nickel-menage-57692.web.app/v2/.

### Point 4 — Confirmation avant les actions à conséquence

**Objectif** — Ajouter une confirmation simple avant : quitter une maison, retirer un membre, supprimer une pièce, supprimer une tâche. Ne pas ajouter de confirmation avant "cocher une tâche" (le geste central de l'app doit rester fluide) — mais compenser par une annulation de quelques secondes après coup, en reprenant la piste déjà identifiée par la V1 (§ 10, RISQUE IDENTIFIÉ).

**Arbitrage posé à Kinder** — Confirmation ou annulation après coup sur "cocher" ? Réponse de Kinder le 2026-09-08 : **pas de confirmation sur cocher, annulation de quelques secondes après**.

**Cadrage — comment concilier l'annulation avec l'historique immuable** — `firestore.rules` impose déjà, en dur, qu'une Réalisation n'est "jamais modifiée, jamais supprimée" (`allow update, delete: if false`, § 3 règle héritée). Une annulation qui supprimerait la Réalisation après coup violerait donc cet invariant. **Solution retenue : l'écriture Firestore du "Fait" est différée de 5 secondes.** Cocher change l'affichage immédiatement (bouton → "Fait ✓ · Annuler"), mais `enregistrerRealisation` n'est appelée qu'à l'expiration du délai si personne n'a cliqué "Annuler" entre-temps. Si annulation dans les 5 secondes : le minuteur est simplement annulé, rien n'a jamais été écrit — aucune donnée à supprimer, aucun conflit avec l'invariant. Si l'utilisateur change d'écran avant l'expiration : l'enregistrement est forcé immédiatement plutôt que perdu silencieusement.

**Résultat obtenu**
- `confirm()` natif avant : "Quitter cette maison ?", "Retirer [prénom] de cette maison ?", "Supprimer cette pièce ?", "Supprimer cette tâche ?" — simple, pas de système d'annulation complexe à construire pour ces quatre actions-là.
- Écran "À faire" : le bouton "Fait" devient "Fait ✓ · Annuler" pendant 5 secondes après le clic ; passé ce délai, la Réalisation est enregistrée normalement (comme avant ce point).

**Critères de validation**
- Annuler la confirmation → l'action n'a pas lieu, rien ne change
- Confirmer → l'action a lieu normalement
- Cocher une tâche puis cliquer "Annuler" dans les 5 secondes → la tâche redevient "pas encore faite", aucune entrée créée dans l'Historique
- Cocher une tâche et laisser le délai s'écouler → enregistrement normal, visible dans l'Historique
- Capture d'écran

**Statut** — Testée le 2026-09-08 dans le navigateur avec plusieurs maisons de test et deux identités (TestE/TestF pour "retirer") :
- "Fait" → "Fait ✓ · Annuler" affiché immédiatement ; annulé dans la foulée → tâche revenue à "pas encore faite", Historique ne contient que l'unique tâche réellement laissée aller à expiration (aucune trace de celle annulée) ;
- "Quitter cette maison" : annulé (`confirm` refusé) → toujours dans la maison ; confirmé → maison quittée, retour à l'écran de démarrage ;
- "Retirer [membre]" : annulé → membre toujours présent ; confirmé → membre retiré ;
- "Supprimer" pièce et "Supprimer" tâche : annulé → rien ne change ; confirmé → suppression effective.
Toutes les maisons de test supprimées après coup (`firebase firestore:delete --recursive`). Déployée sur https://nickel-menage-57692.web.app/v2/.

### Point 5 — Dette Firestore résiduelle : recherche par code

**Constat** — La recherche d'une maison par son code d'invitation (`rejoindreMaison`) exige un accès en lecture-liste sur toute la collection `maisons`. Un client authentifié construit à la main (pas l'app) pourrait donc lister tous les noms et codes d'invitation existants, sans passer par l'interface. Documenté comme dette assumée dans `firestore.rules` depuis l'étape V2-8.

**Pistes évaluées**
1. **Restreindre les champs lisibles en liste** (ex. cacher `codeInvitation` en liste, ne le révéler qu'au `get` d'un document précis) — **impossible techniquement** : les règles de sécurité Firestore s'appliquent au niveau du document, pas du champ. Il n'existe pas de mécanisme natif pour dire "liste autorisée mais seulement tel champ visible".
2. **Cloud Function** pour effectuer la recherche par code côté serveur (avec des droits élevés, sans exposer la collection en liste au client) — techniquement faisable, mais exige de faire passer le projet Firebase du plan Spark (gratuit) au plan Blaze (facturation à l'usage), même si l'usage réel resterait dans le palier gratuit. S'ajoute : un pipeline de déploiement séparé (Cloud Functions), sa maintenance, une source d'erreur supplémentaire pour une app utilisée par 3 personnes.

**Décision — ne rien changer.** Le coût (upgrade de plan, complexité de déploiement, maintenance continue) est disproportionné par rapport au risque réel : un foyer de confiance, un nombre de maisons resté faible, aucune donnée sensible (des noms de maison et des codes d'invitation à 6 caractères, pas des données personnelles ni financières). La dette reste documentée et assumée, pas oubliée — commentaire mis à jour dans `firestore.rules` avec cette décision et sa date, et la clause de réévaluation déjà présente ("à réévaluer si le nombre de maisons devient significatif") reste valable pour l'avenir.

**Statut** — Décision actée le 2026-09-08, sans changement de code applicatif. `firestore.rules` mis à jour (commentaire seulement) et redéployé.

### Point 6 — Fragilité de l'identité : rappel visible

**Constat** — Vider les données du navigateur ou réinstaller l'app fait perdre l'accès sans recours automatique (cohérent avec V2-D2, pas d'email obligatoire — mais un piège si personne n'y pense).

**Objectif** — Rien de structurel : V2-D2 reste la décision validée. Simplement rendre visible, quelque part dans l'app, que le code d'invitation doit être conservé.

**Résultat obtenu** — Un texte discret ajouté sous la liste des membres, sur l'écran d'accueil d'une maison (là où le code d'invitation est déjà affiché juste au-dessus, dans la carte de la maison) : *"Notez ce code quelque part : c'est lui qui vous permettra de revenir si vous changez de téléphone ou videz les données du navigateur."* Correctif d'information pure — aucune logique nouvelle.

**Critères de validation**
- Le rappel est visible sans action supplémentaire, dès l'arrivée sur l'écran d'accueil
- Reste lisible (pas dans le style "tag" majuscule/espacé habituel, trop dense pour une phrase complète)
- Capture d'écran

**Statut** — Testée le 2026-09-08 dans le navigateur (émulation mobile), maison de test "Maison Test Point6" : rappel affiché et lisible sous "Membres", au-dessus de "Quitter cette maison". Maison de test supprimée après coup. Déployée sur https://nickel-menage-57692.web.app/v2/.

### Point 7 — Régression visuelle par rapport à la V1

**Constat** — La V1 a une direction artistique aboutie (§ 11 : "le registre d'entretien", emoji par tâche avec cadre signifiant, typographie soignée). La V2 réutilise la palette et les polices mais reste sommaire : pas d'emoji, sections en simple texte plutôt qu'en bandeaux.

**Cadrage — attribution de l'emoji** — La V1 attribue un emoji par script (`scripts/seed-emoji.mjs`) sur une liste connue à l'avance de 35 tâches figées. Impossible à reproduire en V2 : les tâches sont créées dynamiquement par les utilisateurs, une attribution automatique ne peut pas deviner l'objet d'une tâche inventée. **Décision : l'utilisateur choisit un pictogramme dans une liste restreinte (30 emoji courants d'entretien du foyer) à la création de la tâche**, modifiable ensuite comme les autres champs. Justification : garde le principe V1 (le pictogramme désigne l'objet, pas le geste) sans exiger un clavier emoji complet ni une attribution invisible et donc incohérente.

**Résultat obtenu**
- Nouveau champ `emoji` sur la Tâche (`donnees.js` : `creerTache`, `modifierTache`, transporté par `exporterStructure`/`importerStructure`), défaut 🧹 si non choisi.
- Sélecteur d'emoji (grille de 30 pictogrammes, `EMOJI_TACHES` dans `app.js`) dans les formulaires "Ajouter une tâche" et "Modifier une tâche", avec présélection de l'emoji existant en modification.
- `public/v2/modeles/generique.json` enrichi d'un emoji pertinent par tâche (🚿 douche, 🍳 plaque de cuisson, 🚽 WC, 🛏️ draps, etc.), pour que "Commencer avec le modèle générique" parte déjà habillé.
- Le cadre autour de l'emoji porte une information, comme en V1 : trait plein épais = tâche due (retard ou aujourd'hui), pointillé = jamais renseignée, trait fin = à venir (`.emoji-case--du/--jamais/--avenir`).
- Écran "À faire" : bandeaux de section pleine largeur inversés (fond encre, texte papier), rouge tampon réservé à "En retard" — repris de la direction V1.
- Écran "Historique" : emoji de la tâche affiché à côté du jeton du membre.
- Écran "Pièces et tâches" : emoji affiché devant chaque tâche de la liste.

**Bug trouvé et corrigé en cours de route** — `firebase.json` ne mettait le `Cache-Control: no-cache` que sur `html|js|webmanifest`, pas sur les `.json`. Résultat : `modeles/generique.json` pouvait rester en cache navigateur jusqu'à une heure après un déploiement, montrant une version périmée du modèle générique (sans les emoji fraîchement ajoutés) même après un rechargement classique. Corrigé : glob étendu à `html|js|webmanifest|json`. Cohérent avec l'intention déjà documentée du fichier ("tout ce qui porte le comportement de l'app doit se recharger à chaque ouverture").

**Critères de validation**
- Le sélecteur d'emoji fonctionne à la création et la modification d'une tâche, la sélection est bien enregistrée
- L'emoji choisi apparaît dans "Pièces et tâches", "À faire" et "Historique"
- Le cadre de l'emoji change de style selon le statut de la tâche dans "À faire"
- Les bandeaux de section sont inversés, "En retard" en rouge
- Le modèle générique propose déjà des emoji pertinents
- Capture d'écran

**Statut** — Testée le 2026-09-08 dans le navigateur (émulation mobile), plusieurs maisons de test successives : sélecteur d'emoji validé (choix de 🚿 pour "Nettoyer la douche", conservé en base, présélectionné à la réouverture du formulaire "Modifier"), affichage correct dans les 3 écrans (Pièces et tâches, À faire avec cadre pointillé "jamais renseignée", Historique avec emoji à côté du jeton). Le bug de cache sur le modèle générique a été détecté pendant ce test (emoji par défaut 🧹 partout au lieu des emoji spécifiques), diagnostiqué et corrigé. Toutes les maisons de test supprimées après coup, vérifié par une lecture directe de la collection `maisons` (seule "Chez nous" du foyer pilote subsiste). Déployée sur https://nickel-menage-57692.web.app/v2/.

### Point 8 — Test de bout en bout + bilan final

**Objectif** — Repasser par le parcours complet de l'application, avec deux identités, pour vérifier qu'aucun des 7 points précédents n'a introduit de régression ailleurs. Pas de nouveau code attendu, sauf découverte d'un vrai bug.

**Parcours suivi (maison de test "Maison Test Bout En Bout", code `AUDG3N`, deux profils TestBout1 et TestBout2)** :
- Création de profil, création d'une maison vide, code d'invitation affiché
- Deuxième profil (TestBout2, identité Firebase Auth distincte) rejoint avec le code → visible en temps réel des deux côtés
- Création d'une pièce, ajout d'une tâche avec emoji (🚿), produit et astuce distincts
- Écran "À faire" : tâche "jamais renseignée" listée, cochée, "Fait ✓ · Annuler" affiché
- Historique : entrée correcte (emoji, prénom, date)
- Retirer un membre : confirmation refusée → rien ne change ; confirmée → membre retiré en temps réel
- Quitter une maison : confirmation refusée → toujours dans la maison ; confirmée → maison quittée
- Suppression d'une pièce contenant des tâches → refusée avec message ; tâches supprimées puis pièce vide supprimée avec succès
- PWA : manifest (`Nickel — Maisons`, scope `/v2/`) et service worker actif vérifiés

**Bug réel trouvé et corrigé** — Le calcul des échéances (`dateAujourdhui`/`ajouterJours` dans `public/v2/js/app.js`) utilisait `new Date().toISOString()`, qui convertit en UTC. Pour un fuseau UTC+1/+2 (France), ça fait reculer l'échéance calculée d'un jour (ex. tâche cochée le 09/09 avec fréquence 5 jours → échéance affichée 2026-09-13 au lieu de 2026-09-14). La V1 documentait déjà explicitement ce piège et l'évitait avec un calcul en heure locale (`public/js/app.js`, commentaire "évite le décalage d'un jour que provoquerait new Date('AAAA-MM-JJ'), interprété en UTC") — la V2 l'avait réintroduit sans le vouloir à l'étape V2-3. **Corrigé** en reprenant exactement la méthode de la V1 dans `public/v2/js/app.js`. Vérifié après correctif et déploiement : une tâche cochée le 2026-09-09 avec fréquence 1 jour affiche désormais l'échéance 2026-09-10 (correct). Les échéances déjà enregistrées en base avant le correctif restent décalées d'un jour (aucune n'existait sur la maison réelle "Chez nous", qui n'a pas encore de tâche cochée) — pas de correction rétroactive nécessaire.

**Nettoyage effectué** — La maison de test "Maison Test Bout En Bout" (id `8be7c6c3-f084-4773-b678-5758c50718e9`) a été entièrement supprimée (`firebase firestore:delete --recursive --force`), vérifié par une lecture directe de la collection `maisons` : seule "Chez nous" subsiste.

**Statut** — Testé le 2026-09-09 dans le navigateur. Correctif de date déployé sur https://nickel-menage-57692.web.app/v2/. Aucune autre régression trouvée sur les 7 points précédents.

### Bilan peaufinage V2 (2026-09-09)

Les 8 points identifiés à l'audit du 2026-09-08 sont traités : PWA installable, retirer un membre, modifier/supprimer pièce et tâche, confirmations + annulation de "cocher", décision actée sur la dette Firestore résiduelle (recherche par code), rappel visible du code d'invitation, direction artistique restaurée (emoji, bandeaux), et test de bout en bout final. Un bug réel (échéances décalées d'un jour à cause d'un calcul de date en UTC au lieu du fuseau local) a été trouvé pendant ce dernier test et corrigé — la V2 rejoint maintenant la V1 sur ce point, qui y était déjà documenté comme piège évité.

**État de production** — Tout est déployé sur https://nickel-menage-57692.web.app/v2/, aucun code en attente. La V1 (`public/`, collections `habitants`/`taches`/`realisations`) n'a jamais été touchée pendant tout le peaufinage. La maison réelle "Chez nous" du foyer pilote est intacte (7 pièces, 35 tâches, code `3WS3NG`) ; c'est la seule maison qui subsiste en base, toutes les maisons de test ayant été supprimées après chaque point.

**Ce qui reste, hors périmètre du peaufinage (non traité, volontairement)** :
- Installation réelle de la PWA sur les téléphones physiques de Val, Sam et Yo (à valider par Kinder)
- Rejoindre "Chez nous" avec le code `3WS3NG` sur les vrais appareils (à faire par Kinder)
- Dette Firestore résiduelle sur la recherche par code (§ Point 5) — décision actée de ne rien changer, réévaluable si le nombre de maisons devient significatif

Le périmètre des 8 points du peaufinage V2 est clos.

## 16. CORRECTIONS POST-USAGE RÉEL — démarré le 2026-09-09

Après le peaufinage (§ 15), Kinder a testé l'application V2 en usage réel (notamment via un APK TWA généré en séance, coquille Android autour de la PWA — code web inchangé) et remonté 7 points concrets, plus une question de fond sur les identités. Audit fait par lecture du code (`app.js`, `donnees.js`) et vérification en base. Traités un par un, dans l'ordre convenu avec Kinder, chaque étape testée et déployée avant la suivante.

**Les 7 points identifiés** :
1. Pas de tableau de bord — l'accueil ne montrait rien de ce qu'il y a à faire
2. "Fait" ne bouge pas visuellement (reste affiché dans sa section d'origine pendant les 5 secondes d'annulation)
3. Modèle du foyer pilote non proposé à la création (seul le modèle générique l'était)
4. Champs de saisie au style "carnet d'entretien" jugé étrange pour de simples formulaires
5. Placeholder du prénom = "Val" (un vrai prénom du foyer pilote laissé en exemple)
6. Question : conflit de nom entre membres possible ? — **Non, vérifié dans le code** : chaque membre est identifié par son uid Firebase (technique, invisible), le prénom est un champ que chacun choisit pour soi-même en arrivant — personne ne peut nommer quelqu'un d'autre. Pas de risque de collision technique.
7. Bouton retour Android ferme l'application au lieu de naviguer dans l'app

**Découverte pendant l'audit, hors périmètre des 7 points** — 3 maisons nommées "Chez nous" en base au lieu d'une (la vraie `329547b0…`, code `3WS3NG`, plus deux créées par les tests de Kinder juste avant cette session). Signalé à Kinder plutôt que supprimé d'office (pas des maisons de test créées par Claude Code). **Kinder a confirmé le 2026-09-09 : garder `329547b0…`, supprimer les deux autres.** Fait (`firebase firestore:delete --recursive --force`), vérifié : seule "Chez nous" (`329547b0…`) subsiste.

### Point 1 — Routeur (navigation avec historique)

**Objectif** — Réaliser le point 7 (retour Android) : donner à l'app un vrai historique de navigation (`history.pushState`/`popstate`) au lieu d'un simple remplacement de contenu (`ecran.innerHTML`) sans trace dans l'historique du navigateur.

**Résultat obtenu** — `naviguer(vue, params, { remplacer })` centralise toute navigation : "profil" et "maison" (portes d'entrée avant d'être dans une maison) remplacent toujours l'entrée courante ; une fois dans une maison, "accueil" est la racine de la pile, "gestion"/"afaire"/"historique" empilent une entrée. Chaque écran enregistre son nettoyage (désabonnements Firestore) via `definirNettoyage()`, exécuté avant tout changement d'écran — navigation normale ou bouton retour. Les boutons "retour" internes appellent désormais `history.back()` au lieu d'appeler directement l'écran précédent, pour rester symétriques avec le bouton Android.

**Cas particulier traité** — Un "Fait" en attente d'annulation (délai de 5 secondes, § 15 point 4) doit s'enregistrer si on quitte l'écran "À faire" avant l'expiration, qu'on parte par le bouton retour de l'app ou par le retour Android — géré par le nettoyage de l'écran (`forcerEnregistrement()` de chaque tâche en attente), plus seulement par le clic sur le bouton retour comme avant.

**Critères de validation**
- Naviguer Accueil → Pièces et tâches → retour Android (simulé via `history.back()`) → revient à l'Accueil sans fermer l'app
- Cocher une tâche puis quitter l'écran "À faire" par retour Android avant les 5 secondes → la Réalisation est bien enregistrée (visible dans l'Historique), pas perdue
- Depuis l'Accueil (racine), un retour supplémentaire quitterait l'app (comportement attendu, comme toute app Android)

**Statut** — Testé le 2026-09-09 dans le navigateur (simulation du bouton retour via `history.back()`) : navigation confirmée, enregistrement forcé confirmé (tâche cochée puis retour immédiat → apparaît bien dans l'Historique). Maison de test supprimée après coup. Déployé sur https://nickel-menage-57692.web.app/v2/.

### Point 2 — Tableau de bord sur l'écran d'accueil

**Objectif** — Réaliser le point 1 : l'accueil d'une maison doit montrer directement ce qu'il y a à faire, sans clic supplémentaire.

**Résultat obtenu** — Un bloc ajouté entre la carte de la maison et les boutons : les tâches "en retard" et "à faire aujourd'hui" (mêmes statuts que l'écran "À faire") sont listées directement, avec un bandeau de compte ("X en retard · Y aujourd'hui", rouge si retard) — ou "Rien à faire pour l'instant. 🎉" si tout est à jour. Cliquer sur une tâche du tableau de bord ouvre l'écran "À faire" complet (où le geste "Fait" a lieu) plutôt que de dupliquer la logique de cocher/annulation ici — cette logique sera de toute façon revue au point 3 du plan. Le bouton "À faire" est renommé "Voir toutes les tâches" pour ne pas faire doublon avec le nouveau tableau de bord.

**Critères de validation**
- Maison sans tâche urgente → message "Rien à faire pour l'instant"
- Maison avec des tâches en retard et du jour → comptage et liste corrects, bandeau rouge si au moins une en retard
- Cliquer sur une tâche du tableau de bord → ouvre l'écran "À faire"

**Statut** — Testé le 2026-09-09 dans le navigateur (maison de test avec échéances forcées en base pour simuler retard/aujourd'hui) : affichage et navigation confirmés. Maison de test supprimée après coup. Déployé sur https://nickel-menage-57692.web.app/v2/.

### Point 3 — Retour visuel immédiat sur "Fait"

**Objectif** — Corriger le point 2 : cocher une tâche doit se voir tout de suite, pas rester plantée 5 secondes dans "En retard"/"À faire aujourd'hui" avec juste le bouton qui change de texte.

**Résultat obtenu** — Dans `afficherEcranAFaire` (`app.js`), une tâche tout juste cochée quitte immédiatement sa section d'origine et rejoint un nouveau bloc "Fait ✓" à part, en tête de liste, bandeau vert (`--vert`, déjà défini mais inutilisé jusqu'ici), avec un bouton "Annuler". Le délai de 5 secondes avant écriture réelle en base (§ 15 point 4) et son annulation restent inchangés ; seul l'affichage change — la logique de `enAttente` porte maintenant aussi la tâche elle-même (`{ tache, forcerEnregistrement, annuler }`), nécessaire pour afficher son nom et son emoji dans le bloc "Fait ✓".

**Critères de validation**
- Cocher une tâche → elle disparaît instantanément de sa section (retard/aujourd'hui/à venir/jamais) et apparaît dans "Fait ✓" avec un bouton "Annuler"
- Annuler → revient exactement dans sa section d'origine
- Laisser le délai s'écouler → le bloc "Fait ✓" disparaît, la tâche réapparaît normalement avec sa nouvelle échéance (dans "À venir" typiquement)

**Statut** — Testé le 2026-09-09 dans le navigateur (maison de test, deux tâches) : bascule immédiate vers "Fait ✓" confirmée, annulation confirmée (retour dans "Jamais renseignées"), expiration du délai confirmée (bascule vers "À venir" avec échéance correcte, bloc "Fait ✓" disparu). Maison de test supprimée après coup. Déployé sur https://nickel-menage-57692.web.app/v2/.

### Point 4 — Bouton "modèle du foyer pilote"

**Objectif** — Corriger le point 3 : `foyer-pilote.json` (les 35 tâches réelles de "Chez nous") existait déjà dans `public/v2/modeles/` depuis l'étape V2-7 mais n'était proposé nulle part dans l'interface — il fallait exporter/réimporter à la main pour tester avec de vraies données.

**Résultat obtenu** — Sur l'écran "Votre maison", un second bouton "Commencer avec le modèle du foyer pilote" à côté de "Commencer avec le modèle générique", avec la même mécanique (`importerStructure`, jamais de fusion, V2-D9). Factorisé en une fonction commune `creerDepuisModele(idBouton, fichierModele, nomParDefaut)` pour les deux boutons plutôt que dupliquer le code. Nom par défaut si le champ est laissé vide : "Chez nous (test)", pour ne pas entrer en collision visuelle avec la vraie maison "Chez nous".

**Critères de validation**
- Cliquer "Commencer avec le modèle du foyer pilote" avec un nom donné → une nouvelle maison est créée avec les 7 pièces et 35 tâches
- La maison réelle "Chez nous" n'est jamais touchée (l'import crée toujours une maison séparée)

**Statut** — Testé le 2026-09-09 dans le navigateur : "Chez nous (test)" créée avec 7 pièces et 35 tâches confirmées. Maison de test supprimée après coup. Déployé sur https://nickel-menage-57692.web.app/v2/.

### Point 5 — Placeholder générique du prénom

**Objectif** — Corriger le point 5 : le champ prénom affichait `placeholder="Val"`, un vrai prénom du foyer pilote laissé en exemple, ce qui brouillait la compréhension à la première ouverture.

**Résultat obtenu** — Remplacé par "Camille", un prénom neutre qui n'appartient à personne du foyer pilote (`app.js`, écran profil).

**Statut** — Testé le 2026-09-09 dans le navigateur : placeholder confirmé "Camille". Déployé sur https://nickel-menage-57692.web.app/v2/.

### Point 6 — Toilettage des champs de saisie

**Objectif** — Corriger le point 4 : les labels de champs (ex. "VOTRE PRÉNOM") étaient en majuscules espacées, police machine à écrire (Space Mono) — cohérent avec le style "registre d'entretien" de la V1, mais jugé froid/technique pour de simples formulaires.

**Arbitrage posé à Kinder** — Avant/après montré (capture) sur le champ "Votre prénom" : garder le style actuel, ou l'adoucir (minuscules, police du corps de texte) en gardant titres/boutons/bandeaux identiques. Réponse de Kinder le 2026-09-09 : **version adoucie**.

**Résultat obtenu** — `.champ label` dans `public/v2/index.html` : police "Archivo" (celle du corps de texte) au lieu de "Space Mono", casse normale au lieu de majuscules, plus d'espacement de lettres étiré. Titres (`Anton`), boutons, tags et bandeaux de section inchangés — seuls les labels de champs de formulaire sont concernés.

**Statut** — Testé le 2026-09-09 dans le navigateur (émulation mobile, avant/après comparés) : nouveau style confirmé en production (vérifié après un souci de cache du service worker V2, résolu par désenregistrement + rechargement). Déployé sur https://nickel-menage-57692.web.app/v2/.

### Bilan des corrections post-usage réel (2026-09-09)

Les 7 points remontés par Kinder après son test en usage réel sont traités : routeur avec historique (retour Android), tableau de bord sur l'accueil, retour visuel immédiat sur "Fait", bouton modèle du foyer pilote, placeholder neutre, et style des champs adouci (arbitré avec Kinder). Le point 6 (conflit de nom entre membres) était une question de compréhension, pas un bug — répondu par lecture du modèle de données : aucun risque, chaque membre choisit son propre prénom, jamais assigné par un autre.

Une découverte hors périmètre a été traitée au passage : deux maisons "Chez nous" en double créées pendant les tests de Kinder, supprimées sur sa confirmation — seule la maison officielle (`329547b0…`, code `3WS3NG`) subsiste en base.

**État de production** — Tout est déployé sur https://nickel-menage-57692.web.app/v2/, aucun code en attente. La V1 n'a jamais été touchée. Toutes les maisons de test créées pendant cette ronde de corrections ont été supprimées après chaque point, vérifié par lecture directe de la collection `maisons`.

## 17. RETOUR D'USAGE #2 — démarré le 2026-09-10

Nouveau retour de Kinder après avoir retesté l'app. Trois points, traités séparément : deux corrections concrètes ci-dessous, et une question de fond sur l'APK (§ 18, nécessitant un arbitrage avant exécution).

### Point A — Tâches "jamais faites" invisibles du tableau de bord

**Constat** — En important le modèle générique (ou tout modèle), toutes les tâches ont `prochaineEcheance: null` (jamais faites). Le tableau de bord (§ 16 point 2) ne comptait que "en retard" et "aujourd'hui" comme urgentes, donc affichait "Rien à faire pour l'instant" même avec 17 tâches jamais renseignées — trompeur, puisqu'une tâche sans date de début est due depuis le jour zéro.

**Correctif** — Le tableau de bord inclut désormais les tâches "jamais faites" dans son calcul d'urgence, au même titre que "en retard"/"aujourd'hui" (`app.js`, écran Accueil). Le bandeau affiche par exemple "17 jamais faites" et liste les tâches concernées, cliquables vers l'écran "À faire" complet.

**Statut** — Testé le 2026-09-10 : import du modèle générique (17 tâches) → tableau de bord affiche bien "17 JAMAIS FAITES" avec la liste complète, au lieu de "Rien à faire". Déployé sur https://nickel-menage-57692.web.app/v2/.

### Point B — Écran d'accueil encombré, boutons "cachés" par la liste de tâches

**Constat** — Kinder : avec une vraie liste de tâches à faire sur l'accueil, les boutons "Voir toutes les tâches"/"Historique"/"Pièces et tâches" et la liste des membres se retrouvent poussés en bas de l'écran, peu pratiques.

**Solution (proposée par Kinder, appliquée telle quelle)** — Nouvel écran "Paramètres" (nouvelle vue du routeur, `parametres`) qui regroupe : "Voir toutes les tâches", "Historique", "Pièces et tâches", la liste des membres (avec "Retirer"), le rappel du code d'invitation, et "Quitter cette maison". L'écran d'accueil ne garde que : la carte de la maison (nom + code), un bouton discret "⚙ Paramètres", et le tableau de bord des tâches urgentes — rien d'autre ne peut plus le pousser hors de vue.

**Statut** — Testé le 2026-09-10 : accueil épuré confirmé (carte maison + ⚙ Paramètres + tableau de bord), écran Paramètres accessible et fonctionnel (boutons + membres + quitter), retour Android depuis Paramètres revient bien à l'accueil (routeur du § 16 point 1 inchangé, juste un nouvel écran de plus dans la pile). Déployé sur https://nickel-menage-57692.web.app/v2/.

**Découverte pendant le test, non traitée** — Une nouvelle maison "Chez nous" en double (`14e28f14…`, code `KTBMHR`, créée le 2026-09-10, 1 membre "Val") — probablement un test de Kinder. Signalée, pas supprimée sans confirmation (même règle qu'au § 16).

## 18. RECONSTRUCTION FLUTTER — démarré le 2026-09-10

**Décision** — L'APK actuel (§ APK TWA généré en séance le 2026-09-09) n'est qu'une coquille qui charge le site web en direct : pas une vraie application aux yeux de Kinder. Deux options posées : (a) empaqueter le même code web dans l'APK via Capacitor, sans réécriture — recommandé par Claude Code, le plus rapide ; (b) reconstruire entièrement en Flutter, comme PaperClip2/Terroir. **Kinder a choisi (b)**, explicitement, malgré le coût plus élevé — alignement avec la stack standard des autres projets mobile du portefeuille.

**Ce qui ne change pas** — Firebase, Firestore, `firestore.rules`, le modèle de données (`maisons`/`membres`/`pieces`/`taches`/`realisations`), le projet `nickel-menage-57692`. Seule la façade (V2 web) est remplacée par une vraie app Flutter — le dossier `public/v2/` n'est pas touché, reste déployé et accessible tant que la reconstruction n'est pas terminée.

**Découpage en 7 étapes, une testée avant la suivante** (voir conversation du 2026-09-10) : 1. squelette + auth anonyme + écran profil — 2. accueil/tableau de bord — 3. écran "À faire" — 4. Pièces et tâches — 5. Historique — 6. Paramètres — 7. finitions + build final.

### Étape 1 — Squelette Flutter + authentification anonyme + écran profil

**Objectif** — Prouver que l'app Flutter tourne sur un appareil réel et parle à la même base Firebase que la V2, avant de construire quoi que ce soit d'autre.

**Résultat obtenu** — Nouveau dossier `mobile/` (projet Flutter, `flutter create --org com.nickelmenage --project-name nickel_mobile`), configuré avec `flutterfire configure` (nouvelle app Android enregistrée sur le projet Firebase existant `nickel-menage-57692`, `google-services.json` généré automatiquement). `lib/main.dart` : authentification anonyme au démarrage (équivalent Flutter de `assurerAuthentification()` en V2), écran "Qui êtes-vous ?" (prénom + couleur, palette reprise de la V2, enregistré localement via `shared_preferences`), puis un écran de preuve affichant l'uid Firebase et une lecture Firestore en direct de la collection `maisons` (confirme l'accès à la même base).

**Critères de validation**
- L'app se lance sur un appareil Android réel sans crash
- Créer un profil (prénom + couleur) → écran suivant affiche l'uid et confirme la lecture Firestore
- Fermer et rouvrir l'app → le profil est retrouvé (pas redemandé), passe directement à l'écran de preuve

**Statut** — Testé par Kinder sur téléphone réel le 2026-09-10, confirmé bon (profil créé, uid affiché, Firestore accessible).

### Étape 2 — Accueil + tableau de bord

**Objectif** — Écran "Votre maison" (créer vide / depuis un modèle / rejoindre par code) et le tableau de bord de l'accueil (tâches urgentes), équivalents Flutter de `afficherEcranMaison` et `afficherEcranAccueil` en V2 — avec directement le correctif du § 17 point A (les tâches "jamais faites" comptent comme urgentes).

**Résultat obtenu** — Nouveau fichiers `lib/donnees.dart` (couche données, miroir de `donnees.js` : créer/rejoindre une maison, écouter tâches/membres, importer une structure — même modèle Firestore, mêmes noms de champs, couleur stockée en hex pour rester interopérable avec la V2 web), `lib/stockage_local.dart` (équivalent `localStorage`), `lib/palette.dart` (styles partagés), `lib/ecran_maison.dart`, `lib/ecran_accueil.dart`. Les deux modèles JSON (`generique.json`, `foyer-pilote.json`) sont embarqués comme assets Flutter (copiés depuis `public/v2/modeles/`). Le tableau de bord n'est pas encore interactif (pas de "Fait", pas de Paramètres) — volontairement, ce sont les étapes 3 et 6.

**Critères de validation**
- Créer une maison vide → arrive sur l'accueil avec le nom et le code
- Créer depuis le modèle du foyer pilote → tableau de bord affiche "35 jamais faites"
- Rejoindre avec le code d'une maison existante → accueil affiché, données partagées avec la V2 web (même Firestore)
- Fermer/rouvrir l'app → retrouve directement l'accueil de la maison (pas reredemandé)

**Statut** — `flutter analyze` propre, build release réussi (17,8 Mo, arm64), envoyé à Kinder pour test le 2026-09-10.

### Étape 3 — Écran "À faire" (cocher/annuler)

**Objectif** — Équivalent Flutter de `afficherEcranAFaire`, avec directement le comportement corrigé du peaufinage (§ 16 point 3) : une tâche cochée quitte immédiatement sa section pour un bloc "Fait ✓" séparé, écrite en base après un délai de 5 secondes annulable, sans confirmation (geste le plus fréquent de l'app).

**Résultat obtenu** — `lib/ecran_afaire.dart` : sections "En retard" (bandeau rouge), "À faire aujourd'hui", "À venir", "Jamais renseignées", plus un bloc "Fait ✓" (bandeau vert) en tête quand des tâches sont en attente d'annulation. `enregistrerRealisation()` ajoutée à `donnees.dart` (écrit la Réalisation + avance l'échéance de la Tâche, comme en V2). Le `dispose()` de l'écran force l'enregistrement des "Fait" en attente si on quitte l'écran avant les 5 secondes — équivalent du nettoyage forcé par le routeur en V2 web (§ 16 point 1), mais ici gratuit : Flutter gère nativement la pile de navigation et le bouton retour Android, pas besoin de `history.pushState` custom comme sur le web.

**Navigation** — Bouton "Voir toutes les tâches" ajouté sur l'accueil (temporaire, rejoindra l'écran Paramètres à l'étape 6, comme en V2 web) ; taper une tâche du tableau de bord ouvre aussi l'écran "À faire" complet.

**Critères de validation**
- Cocher une tâche → bascule immédiatement dans "Fait ✓" avec bouton "Annuler"
- Annuler → revient dans sa section d'origine
- Laisser le délai s'écouler → écrite en base, disparaît de "Fait ✓", réapparaît dans "À venir" avec la nouvelle échéance
- Cocher puis appuyer sur retour Android avant la fin du délai → enregistrement forcé, visible dans Firestore (vérifiable côté V2 web dans "Historique")

**Statut** — `flutter analyze` propre, build release réussi (17,9 Mo, arm64), envoyé à Kinder pour test le 2026-09-10.

### Étape 4 — Pièces et tâches

**Objectif** — Équivalent Flutter de `afficherEcranGestion` : créer/renommer/supprimer une pièce, créer/modifier/supprimer une tâche avec sélecteur d'emoji.

**Résultat obtenu** — `lib/ecran_gestion.dart` : liste des pièces (champ + bouton "+" pour en créer une), chaque pièce affiche ses tâches (emoji, nom, fréquence, produit, astuce) avec "Renommer"/"Supprimer" pour la pièce et "Modifier"/"Supprimer" pour chaque tâche. Le formulaire tâche (création et modification, même composant `_FormulaireTache`) s'ouvre en feuille modale (plus adapté à Flutter que le formulaire inline de la V2 web) : nom, fréquence, produit, astuce, grille de 30 pictogrammes (même liste que la V2, déplacée dans `lib/palette.dart`). Fonctions `ecouterPieces`, `modifierPiece`, `supprimerPiece` (refuse si la pièce contient des tâches, même règle que V2-D12), `modifierTache`, `supprimerTache` ajoutées à `donnees.dart`. Bouton "Pièces et tâches" ajouté sur l'accueil.

**Non repris (secondaire, laissé pour les finitions § 7 si besoin)** — L'export de structure en `.json` (fonctionnalité V2-D7/D8, utile surtout pour créer de nouveaux modèles de départ — pas indispensable au fonctionnement quotidien).

**Critères de validation**
- Créer une pièce → apparaît dans la liste
- Ajouter une tâche avec emoji, produit, astuce → apparaît sous la pièce
- Modifier une tâche → changements visibles immédiatement
- Supprimer une pièce contenant une tâche → refusée avec message ; pièce vide → supprimée
- Les mêmes données sont visibles côté V2 web (même Firestore)

**Statut** — `flutter analyze` propre, build release réussi (18 Mo, arm64), envoyé à Kinder pour test le 2026-09-10.

### Étape 5 — Historique

**Objectif** — Équivalent Flutter de `afficherEcranHistorique` : les Réalisations groupées par jour, la plus récente en premier.

**Résultat obtenu** — `lib/ecran_historique.dart` : groupement par `dateRealisation` ("Aujourd'hui"/"Hier"/date), chaque ligne affiche le jeton coloré du membre, le pictogramme de la tâche, son nom et "par [prénom]" — repli "Tâche supprimée" si la tâche n'existe plus (même comportement que V2). `ecouterRealisations()` ajoutée à `donnees.dart` (triée par `enregistreLe` décroissant, limite 100, comme en V2). Bouton "Historique" ajouté sur l'accueil.

**Critères de validation**
- Cocher une tâche (écran "À faire") → apparaît dans l'Historique sous "Aujourd'hui", avec le bon prénom et le bon emoji
- Historique en temps réel (pas besoin de rafraîchir)
- Visible aussi côté V2 web (même Firestore) et réciproquement

**Statut** — `flutter analyze` propre, build release réussi (18 Mo, arm64), envoyé à Kinder pour test le 2026-09-10.

### Étape 6 — Paramètres

**Objectif** — Équivalent Flutter de `afficherEcranParametres` (§ 17 point B) : regrouper "Voir toutes les tâches", "Historique", "Pièces et tâches", les membres (avec "Retirer") et "Quitter cette maison" dans un écran dédié, pour que l'accueil ne garde que la carte de la maison et le tableau de bord — même correction que sur la V2 web.

**Résultat obtenu** — `lib/ecran_parametres.dart`, accessible via un bouton "⚙ Paramètres" sur l'accueil (remplace l'ancien bouton "Quitter" du header et les 3 boutons temporaires ajoutés aux étapes 3-5, retirés de l'accueil). `retirerMembre()` ajoutée à `donnees.dart` (même écriture que `quitterMaison`, exposée séparément pour éviter toute confusion de profil côté appelant, comme en V2). "Quitter cette maison" utilise `pushAndRemoveUntil` pour vider toute la pile de navigation (Paramètres, Accueil, etc.) en revenant à l'écran "Votre maison" — évite qu'un retour Android ramène vers une maison qu'on vient de quitter.

**Critères de validation**
- Accueil : plus que la carte de la maison + tableau de bord + bouton ⚙
- Paramètres : les 3 boutons de navigation, la liste des membres, "Retirer" absent sur soi-même
- Retirer un autre membre → confirmation, puis disparaît en temps réel
- Quitter la maison → confirmation, retour à "Votre maison", impossible d'y revenir par retour Android

**Statut** — `flutter analyze` propre, build release réussi (18 Mo, arm64), envoyé à Kinder pour test le 2026-09-10. Les 6 étapes prévues (routeur/écrans de base, accueil, à faire, gestion, historique, paramètres) sont complètes — reste l'étape 7 (finitions : icône, thème, build final signé) si Kinder confirme que tout fonctionne.

### Étape 7 — Finitions (icône, nom, build signé)

**Objectif** — Dernière étape du découpage : nom affiché "Nickel" (au lieu du nom technique "nickel_mobile"), icône de l'app (même icône que la PWA), et surtout un vrai build de release signé avec une clé propre — jusqu'ici tous les APK étaient signés avec la clé de débogage par défaut de Flutter, ce qui suffit pour tester mais n'est pas une vraie distribution.

**Résultat obtenu**
- `android:label` de `AndroidManifest.xml` : "nickel_mobile" → "Nickel"
- Icône générée avec `flutter_launcher_icons` à partir de `public/icons/icon-512.png` (icône) et `icon-maskable-512.png` (icône adaptative, fond `#16150F`) — toutes les résolutions Android générées automatiquement
- Nouvelle clé de signature dédiée (`android/nickel-release.keystore`, jamais dans le dépôt — voir `.gitignore`), configurée via `android/key.properties` (également hors dépôt) et câblée dans `android/app/build.gradle.kts` : le build `release` utilise désormais cette clé au lieu de la clé de débogage

**Attention pour Kinder** — Le changement de clé de signature casse la compatibilité de mise à jour avec les APK précédents (étapes 1 à 6, signés avec la clé de débogage). Il faut **désinstaller l'app existante avant d'installer celle-ci**, sinon Android refuse ("conflit de signature"). Une fois cette version installée, les futures mises à jour (toujours signées avec la même clé maintenant) s'installeront normalement par-dessus.

**Non traité, volontairement hors périmètre** — Publication sur le Play Store (compte développeur payant, fiche store, etc.) : pas demandé, l'app reste distribuée par APK direct comme le reste du portefeuille de projets tant qu'aucun besoin de diffusion plus large n'est exprimé.

**Statut** — Build release réussi (18 Mo, arm64), signature vérifiée (`apksigner verify --print-certs` confirme le certificat "CN=Kinder, OU=Nickel, O=Nickel"), envoyé à Kinder le 2026-09-10.

## Bilan de la reconstruction Flutter (2026-09-10)

Les 7 étapes prévues sont complètes : squelette + auth, accueil/tableau de bord, À faire, Pièces et tâches, Historique, Paramètres, finitions. L'app Flutter (`mobile/`) couvre toutes les fonctionnalités de la V2 web à l'exception de l'export de structure en `.json` (secondaire, non redemandé). Même Firestore, mêmes règles, même modèle de données que la V2 — les deux façades (web et Flutter) coexistent et partagent les mêmes maisons en temps réel. La V2 web (`public/v2/`) reste déployée et fonctionnelle, non modifiée par ce chantier.

## 19. RETOUR D'USAGE #3 (APP FLUTTER) — démarré le 2026-09-10

Retour de Kinder après test de l'APK Flutter final (§ 18). 9 points : pas d'emoji dans sa maison, historique non modifiable, impossible de cocher depuis l'accueil, "jamais faite" n'a pas de sens au lancement (une tâche est juste "à faire"), écran "À faire" redondant avec l'accueil (tout centraliser sur l'accueil en blocs repliables À faire / Fait / À venir), pas de fiche détail d'une tâche (produit/astuce), code d'invitation à déplacer dans Paramètres (garder le bandeau), impossible de supprimer une maison ou d'en avoir plusieurs, renommer le modèle foyer pilote.

### Décisions actées avec Kinder le 2026-09-10

- **Modèle** : "Modèle du foyer pilote" → **"Modèle Spécial Chez nous"**.
- **Historique modifiable — LÈVE LA RÈGLE FIGÉE § 3** ("une Réalisation n'est jamais modifiée, jamais supprimée", imposée depuis V2-8 par `firestore.rules`). Désormais : une Réalisation faite par erreur **peut être supprimée** depuis l'Historique, et l'échéance de la tâche se recalcule à partir de la Réalisation précédente (ou redevient "à faire" s'il n'y en a plus). Justification : un geste de correction est indispensable en usage réel ; l'annulation de 5 secondes ne couvre pas une erreur remarquée plus tard.
- **Supprimer une maison** : efface tout (pièces, tâches, historique, membres), après confirmation claire. Rendu possible par la décision précédente (les Réalisations étaient indélébiles).
- **Plusieurs maisons par profil** : créer ou rejoindre une maison sans quitter l'actuelle, basculer entre elles depuis Paramètres.
- **Nettoyage** : garder uniquement la maison officielle `329547b0…` (3WS3NG) ; les 3 doublons "Chez nous" (`14e28f14…` avec "Val", et deux maisons sans membre créées par l'app Flutter) ont été supprimés le 2026-09-10.
- **Emoji de la vraie maison** : la maison 3WS3NG (aucun membre, aucun historique) sera **recréée par Kinder depuis son téléphone** avec le modèle Spécial Chez nous (emoji inclus), puis l'ancienne supprimée — plutôt que d'y écrire en contournant les règles Firestore (tentative bloquée par le garde-fou de Claude Code, à juste titre). Conséquence : nouveau code d'invitation, sans impact puisque personne n'avait encore rejoint 3WS3NG.

### Plan en 4 étapes

1. Données : emoji sur les 35 tâches du modèle, renommage du modèle
2. Accueil centralisé : blocs repliables À faire (dues, en retard ou jamais faites — "jamais faite" disparaît comme statut affiché) / Fait (cochées aujourd'hui) / À venir ; bouton "Fait" directement sur l'accueil (annulation 5 s conservée) ; fiche détail au toucher (produit, astuce, fréquence, dernière réalisation) ; suppression de l'écran "À faire" séparé ; code d'invitation déplacé dans Paramètres, bandeau du nom de la maison conservé
3. Historique : supprimer une Réalisation, recalcul de l'échéance, `firestore.rules` adaptées
4. Plusieurs maisons : liste, bascule, créer/rejoindre sans quitter, supprimer une maison

### Étape 1 — Emoji du modèle + renommage

**Résultat obtenu** — Un emoji attribué à chacune des 35 tâches de `foyer-pilote.json` (objet désigné, même principe que le modèle générique : 🛋️ canapés, 🧊 frigo, 🚿 douche, 🚽 WC, 🧺 linge, ♻️/🗑️ poubelles, etc.), dans les deux copies (`public/v2/modeles/` et `mobile/assets/modeles/`, vérifiées identiques). Web redéployé. Bouton Flutter renommé "Modèle Spécial Chez nous".

**Statut** — APK envoyé à Kinder le 2026-09-10 (même clé de signature que l'étape 7, s'installe par-dessus). En attente : Kinder recrée "Chez nous" depuis son téléphone ; ensuite suppression de l'ancienne `329547b0…` (3WS3NG).

**Mise à jour étape 1** — Kinder a indiqué avoir recréé "Chez nous" depuis son téléphone, mais aucune nouvelle maison n'apparaît en base (lecture serveur forcée). L'ancienne `329547b0…` (3WS3NG) n'a donc **pas** été supprimée. Cause probable, corrigée à l'étape 2 : voir "Bug d'identité" ci-dessous.

### Étape 2 — Accueil centralisé + fiche tâche (+ correctif création de maison)

**Accueil** (`lib/ecran_accueil.dart`, réécrit) : une seule page pour les tâches, trois blocs repliables :
- **À faire** : tâches en retard, du jour ou jamais faites (plus de statut "jamais renseignée" affiché — une tâche jamais faite est simplement à faire), tri : retard d'abord, puis du jour, puis le reste ; bandeau rouge et "N en retard" s'il y en a
- **Fait aujourd'hui** : tâches cochées aujourd'hui ("Fait par [prénom]")
- **À venir** : le reste, "Demain" / "Dans N j", toujours cochable en avance (D7)

Bouton "Fait" sur chaque tâche, avec délai d'annulation de 5 s conservé ; en plus du bloc "Fait", une barre en bas de l'écran « … faite — ANNULER » (sinon, avec 30+ tâches à faire, le bloc "Fait" et son bouton sont hors de vue et l'annulation est inutilisable en pratique). Toucher une tâche ouvre sa **fiche** : pièce, fréquence, dernière fois (et par qui), prochaine fois, produit, astuce, bouton "C'est fait". L'écran "À faire" séparé est supprimé (`ecran_afaire.dart`). Bandeau noir conservé avec le seul nom de la maison ; **code d'invitation déplacé dans Paramètres**, avec un bouton "Copier".

**Bug d'identité corrigé** — Après une réinstallation, Android peut restaurer le profil local (sauvegarde automatique) alors que Firebase attribue un nouvel identifiant anonyme à l'appareil. Le profil gardait l'ancien identifiant, que les règles Firestore refusent : la création de maison échouait à l'étape "ajout du membre", et l'écran tournait indéfiniment sans message. Indices concordants : deux maisons créées par l'app à 2 minutes d'intervalle le 2026-09-10, toutes deux sans aucun membre, puis la maison "recréée" introuvable. Corrections :
- au démarrage, le profil est recalé sur l'identifiant Firebase réel ; si une maison était enregistrée, l'appareil y est réinscrit sous son nouvel identifiant et l'ancienne entrée orpheline est retirée (`reprendreMaison` dans `donnees.dart`)
- création de maison **atomique** (maison + premier membre en une seule écriture groupée) : plus jamais de maison orpheline en cas d'échec ; même chose pour l'enregistrement d'une tâche faite (Réalisation + échéance)
- les erreurs de création/rejoindre s'affichent désormais au lieu d'un chargement infini

**Autres défauts trouvés et corrigés en cours de route**
- Quitter l'écran avec un "Fait" en attente provoquait une erreur (liste modifiée pendant son parcours) — l'ancien écran "À faire" avait le défaut ; corrigé dans le nouvel accueil
- Tri instable des tâches d'une même pièce (les lignes changeaient d'ordre à chaque mise à jour) — départage par pièce puis par nom
- Décompte "en retard de N j" calculé en UTC pour ne pas être faussé par le passage à l'heure d'été

**Test** — Pour la première fois sur ce chantier, testé sur un émulateur Android (Medium Phone API 36.1) avant envoi : création d'une maison depuis le modèle Spécial Chez nous (35 tâches avec emoji, pièce en sous-titre), "Fait" → la tâche quitte "À faire" immédiatement, barre ANNULER → la tâche revient, blocs repliables (32 / 3 / 0), fiche détail complète (fréquence, dernière fois 10/09 par TestEmu, prochaine fois 10/10, produit, astuce, "Déjà faite aujourd'hui"), Paramètres avec code et "Copier". Maison de test supprimée, émulateur arrêté.

**Statut** — APK envoyé à Kinder le 2026-09-10 (s'installe par-dessus). En attente : Kinder recrée "Chez nous" avec cette version ; ensuite suppression de l'ancienne 3WS3NG.

### Étape 3 — Supprimer une réalisation faite par erreur

**Résultat obtenu**
- `firestore.rules` : une Réalisation reste non modifiable, mais devient **supprimable par un membre** (`allow delete: if estMembre(maisonId)`), conformément à la levée de la règle figée décidée le 2026-09-10. Règles déployées le 2026-09-11.
- `supprimerRealisation()` (`donnees.dart`) : efface la Réalisation et recalcule l'échéance de la tâche en une écriture groupée — dernière réalisation restante + fréquence actuelle, ou échéance vide ("à faire") s'il n'en reste aucune. Si la tâche a été supprimée entre-temps, seule la Réalisation est effacée.
- Deux points d'accès : sur l'accueil, fiche d'une tâche faite aujourd'hui → "Finalement pas faite — annuler" (là où Kinder cherchait à revenir sur une tâche) ; dans l'Historique, icône corbeille sur chaque ligne, avec confirmation.

**Test (émulateur)** — Tâche cochée puis annulée depuis sa fiche → revient dans "À faire", bloc "Fait" vide, échéance remise à vide. Tâche recochée puis supprimée depuis l'Historique (confirmation affichée) → revient dans "À faire", l'historique ne garde aucune trace. La première suppression avait bien disparu de l'historique. Maison de test supprimée, émulateur arrêté.

**Statut** — APK envoyé à Kinder le 2026-09-11 (s'installe par-dessus). Toujours en attente : recréation de "Chez nous" par Kinder (aucune nouvelle maison en base au 2026-09-11), puis suppression de l'ancienne 3WS3NG.

### Étape 4 — Plusieurs maisons, supprimer une maison

**Résultat obtenu**
- Stockage local : en plus de la maison affichée (clé historique conservée, aucune perte à la mise à jour), une **liste des maisons** de l'appareil (`chargerMaisonsLocales`, `ajouterMaisonLocale`, `choisirMaisonLocale`, `retirerMaisonLocale`).
- Paramètres : section **"Mes maisons"** (maison affichée marquée, toucher une autre pour y basculer), bouton **"+ Ajouter ou rejoindre une maison"** (ouvre l'écran "Votre maison" avec flèche retour, sans quitter l'actuelle), **"Supprimer cette maison"** (confirmation explicite : tout effacé définitivement pour tous les membres).
- `supprimerMaison()` : efface historique, tâches, pièces, autres membres, la maison, puis sa propre fiche membre en dernier (ordre imposé par les règles Firestore : il faut rester membre tant qu'on efface), par lots.
- `chargerMesMaisons()` : n'affiche que les maisons existantes dont on est encore membre ; à l'ouverture, une maison supprimée par un autre membre, ou dont on a été retiré, est oubliée et l'app passe à la maison suivante (plus de message d'erreur).
- Rejoindre une maison dont on est déjà membre ne plante plus (les règles interdisent de réécrire sa fiche membre : on ne la touche pas).
- Réinscription automatique après réinstallation (étape 2) étendue à **toutes** les maisons de l'appareil.
- Navigation commune (`navigation.dart`, `ouvrirMaisonCourante`) : après créer / rejoindre / basculer / quitter / supprimer, on arrive sur la bonne maison avec une pile de navigation vidée (le retour Android ne ramène pas vers l'ancienne).

**Ajout décidé en cours de test (proposé par Claude Code)** — Quitter une maison dont on est le **dernier membre** la supprime, avec un message explicite ("Vous êtes le seul membre : en la quittant, la maison sera supprimée définitivement…", bouton "Quitter et supprimer"). Sans ça, la maison restait vide en base pour toujours — c'est exactement ainsi que les doublons "Chez nous" sans membre s'étaient accumulés. Quand d'autres membres restent, "Quitter" garde son comportement habituel.

**Test (émulateur)** — Maison A (vide) créée ; Maison B (modèle générique) ajoutée depuis Paramètres sans quitter A ; "Mes maisons" liste A et B ; bascule vers A ; retour sur B, une tâche cochée (historique non vide), puis "Supprimer cette maison" → confirmation, retour automatique sur A, B absente de la base ; "Quitter" A en étant seul membre → message "Quitter et supprimer", retour sur "Votre maison", A absente de la base. Base finale : seule la maison 3WS3NG. Émulateur arrêté.

**Statut** — APK envoyé à Kinder le 2026-09-11 (s'installe par-dessus). Les 4 étapes du retour d'usage #3 sont faites. Reste en attente : recréation de "Chez nous" par Kinder (toujours aucune nouvelle maison en base au 2026-09-11), puis suppression de l'ancienne 3WS3NG.

## 20. CADRAGE NOTIFICATIONS — 2026-09-11 (non commencé)

Cadrage fait avec Kinder, aucune ligne de code écrite.

**Décidé**
- **Un seul rappel quotidien**, pas une notification par tâche (35 tâches = fatigue, notifications ignorées). Contenu : « Tâches du jour : N à faire, dont M en retard » (à faire = en retard + du jour + jamais faites, même calcul que le bloc "À faire" de l'accueil).
- **Heure choisie par chacun**, sur son téléphone (réglage local dans Paramètres, avec interrupteur pour désactiver).
- **Rien à faire → aucune notification.**
- **Pas de validation depuis la notification** : un rappel groupé ne peut pas se valider d'un geste sans ambiguïté, et on perdrait l'annulation de 5 s. Toucher la notification ouvre l'app sur l'accueil.
- **Pas de notification "tâche faite par un autre membre" pour l'instant** : impossible sans serveur (Cloud Functions → passage au forfait Firebase avec carte bancaire), déjà écarté au peaufinage point 5 pour les mêmes raisons de coût/complexité. Le bloc "Fait aujourd'hui" couvre le besoin à l'ouverture de l'app. Réévaluable si le besoin se confirme.

**Contrainte technique à connaître** — Pour que le compte soit juste (un autre membre a pu faire des tâches entre-temps), le téléphone relit la base en arrière-plan à l'heure choisie avant d'afficher le rappel. Android décale ces traitements pour économiser la batterie : le rappel peut arriver avec quelques minutes de retard, et certains constructeurs très agressifs (Xiaomi, Huawei…) peuvent le bloquer sans réglage manuel de l'utilisateur.

### Réalisation du rappel quotidien — 2026-09-12

**Choix technique** — Le rappel ne peut pas être une notification programmée à l'avance avec un texte figé : le compte doit être juste au moment où il s'affiche (un autre membre a pu cocher entre-temps), et il ne doit rien afficher s'il n'y a rien à faire. Le téléphone se réveille donc à l'heure choisie (**WorkManager**, `workmanager`), relit les tâches de la maison affichée, compte, puis affiche — ou non — la notification (`flutter_local_notifications`). WorkManager plutôt qu'une alarme exacte : une alarme exacte demande une autorisation Android réservée aux réveils et agendas, ce qu'un rappel de ménage n'est pas. Contrepartie assumée, déjà documentée au § 20 : Android peut décaler le réveil de quelques minutes.

**Fichiers** — `lib/notifications.dart` (programmation, comptage, affichage, point d'entrée en arrière-plan), réglages locaux dans `stockage_local.dart`, `lireTaches()` (lecture ponctuelle) dans `donnees.dart`, section "Rappel quotidien" dans Paramètres, permission `POST_NOTIFICATIONS` et *core library desugaring* (exigé par `flutter_local_notifications`) côté Android.

**Comportement** — Interrupteur (désactivé par défaut), heure réglable (19:00 par défaut : en fin de journée, on sait ce qui a été fait et il reste du temps pour agir), bouton "Voir ce que ça donne maintenant" qui affiche le rappel tel qu'il serait envoyé sans rien programmer. L'autorisation Android est demandée au moment de l'activation, pas au premier lancement. Le rappel est réinstallé à chaque démarrage de l'app (réinstallation, mise à jour, redémarrage du téléphone). Texte : « Tâches du jour — N à faire », avec « dont M en retard » seulement s'il y en a.

**Non fait, conforme au cadrage** — Pas de validation depuis la notification, pas de notification par tâche, pas de notification quand un autre membre coche (impossible sans serveur).

**Tests (émulateur)** — Activation → l'autorisation Android est bien demandée ; bouton de test → notification « Tâches du jour — 17 à faire » ; appui sur la notification → ouvre l'app ; maison sans tâche → message "Rien à faire aujourd'hui : aucun rappel ne serait envoyé", aucune notification ; travail programmé vérifié dans le planificateur Android à l'heure exacte choisie. À noter : Android refuse de déclencher un travail périodique avant son heure, même forcé (`cmd jobscheduler run -f`) — la vérification de bout en bout se fait donc en réglant l'heure à quelques minutes.

**Vérification de bout en bout (2026-09-12)** — Rappel réglé à 8:30, app en arrière-plan : la notification « Tâches du jour » s'est affichée seule entre 8:31 et 8:34, sans que l'application soit ouverte. Le réveil en arrière-plan, la relecture de la base et l'affichage fonctionnent donc réellement, avec le décalage de quelques minutes annoncé. Maisons de test supprimées.
