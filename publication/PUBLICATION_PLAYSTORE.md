# Nickel — Publication Google Play (test fermé)

> Préparé le 2026-10-10 (étape 1, Claude Code). L'étape 2 se fait dans Chrome avec Claude : copier le **prompt de la section 6** dans une conversation Claude in Chrome, sur la page « Créer une application » de la Play Console.
> Publication **telle quelle** (modèles actuels). Le modèle générique sera revu avant la production.

---

## 1. Ce qui est prêt (dossier `publication/`)

| Élément | Fichier | Note |
|---|---|---|
| Paquet à téléverser | `app-release.aab` (46 Mo) | version **1.1.0 (5000)**, signé avec la clé `nickel-release` ; non versionné dans git |
| Icône 512 × 512 | `icone-512.png` | |
| Image de présentation 1024 × 500 | `image-presentation-1024x500.png` | |
| 7 captures téléphone | `captures/1_accueil.png` … `7_astuces.png` | 1140 × 2240 (rapport accepté par Play) |
| Politique de confidentialité | `public/confidentialite.html` | **à mettre en ligne** (voir § 5) |
| Sauvegarde de la clé de signature | `V:\DEV\keys\nickel-release.keystore` + `nickel-key.properties` | **ne jamais perdre** : sans elle, plus aucune mise à jour possible |

Ordre des captures : 1 accueil (à faire) · 2 fiche d'une tâche + son historique · 3 fait aujourd'hui · 4 équipe et quêtes · 5 succès débloqués · 6 profil · 7 astuces.
Capture du **Marché volontairement écartée** (voir § 7).

Changements de code faits pour la publication : version 1.1.0+5000 ; retrait de 3 permissions « service au premier plan » ajoutées par la bibliothèque du rappel et jamais utilisées (sinon Google exige une déclaration avec vidéo). Rappel quotidien re-testé après coup : il fonctionne.

---

## 2. Création de l'application (page « Créer une application »)

| Champ | Valeur |
|---|---|
| Nom de l'application | `Nickel : ménage partagé` |
| Nom du package | `com.nickelmenage.nickel_mobile` (**doit être exactement celui-ci**, c'est celui du paquet) |
| Langue par défaut | Français (France) – fr-FR |
| Application ou jeu | Appli |
| Gratuite ou payante | Gratuite |
| Déclarations | cocher les deux (règles du programme pour les développeurs, lois export États-Unis) |

---

## 3. Fiche Play Store principale

**Nom** : `Nickel : ménage partagé`

**Description courte** (69 / 80) :
```
Le ménage partagé de la maison : cocher, suivre, progresser ensemble.
```

**Description complète** :
```
Nickel organise le ménage d'une maison partagée — colocation, famille, couple — sans tableau sur le frigo ni rappels à répétition.

CHACUN VOIT CE QUI EST À FAIRE
Chaque tâche a sa fréquence (tous les 7 jours, tous les 30 jours…). Nickel calcule tout seul ce qui est en retard, ce qui est à faire aujourd'hui et ce qui arrive. Un geste suffit : « Fait ». La prochaine échéance se recalcule à partir du jour où la tâche a vraiment été faite.

UNE FICHE POUR CHAQUE TÂCHE
Produit, ustensile, astuce, ce qu'il faut éviter, durée… et tout l'historique de la tâche : quand elle a été faite, par qui, et si le rythme prévu est tenu.

UNE MAISON, PLUSIEURS TÉLÉPHONES
Créez votre maison, partagez son code d'invitation, et tout le monde est synchronisé en temps réel. Pas de compte, pas d'e-mail, pas de mot de passe.

DÉMARRER EN UNE MINUTE
Partez d'une maison vide ou d'un modèle déjà rempli (pièces et tâches courantes), puis ajustez à votre logement.

PROGRESSER ENSEMBLE
Chaque tâche rapporte de l'expérience. La maison monte de niveau quand tout le monde s'y met. Quêtes de la semaine, 30 succès à débloquer, avatars et couvertures à collectionner avec les Bulles gagnées en jouant. Esprit coopératif : personne n'est classé.

DES ASTUCES QUI MARCHENT
Une bibliothèque d'astuces de nettoyage classées par pièce, avec les précautions de sécurité et les produits à ne pas mélanger.

ET AUSSI
• Un rappel quotidien optionnel, une seule notification par jour, aucune s'il n'y a rien à faire
• Annulation possible si vous avez coché par erreur
• Plusieurs maisons sur le même téléphone

Gratuit, sans publicité, sans achat intégré.
```

**Éléments graphiques** : icône `icone-512.png`, image de présentation `image-presentation-1024x500.png`, captures téléphone `captures/1_…` à `7_…` dans l'ordre.

**Catégorie** : Appli · **Maison et habitat** (à défaut : Productivité). Tags : laisser vide si proposé.

**Coordonnées** : e-mail **à fournir par Kinder** (le même que dans la politique de confidentialité). Site web : vide. Téléphone : vide.

---

## 4. Contenu de l'application (questionnaires)

| Rubrique | Réponse |
|---|---|
| Règles de confidentialité | `https://nickel-menage-57692.web.app/confidentialite.html` (après mise en ligne, § 5) |
| Accès à l'application | Toutes les fonctionnalités sont disponibles sans accès particulier (pas de connexion : on crée une maison librement) |
| Annonces | Non, l'application ne contient pas d'annonces |
| Classification du contenu | e-mail de contact ; catégorie **« Toutes les autres catégories d'applications »** (utilitaire/productivité) ; violence, sexualité, langage, drogues, jeux d'argent : **Non** partout ; « Les utilisateurs peuvent-ils interagir ou échanger du contenu ? » : **Oui** (les membres d'une maison voient les prénoms et les tâches saisies par les autres) ; partage de position : Non ; achats numériques : Non ; contenu généré par l'utilisateur modéré : non applicable |
| Public cible | **18 ans et plus** uniquement ; l'application n'attire pas particulièrement les enfants : Non |
| Applications d'actualités | Non |
| Applications gouvernementales | Non |
| Fonctionnalités financières | Aucune |
| Santé | Aucune fonctionnalité de santé |
| Sécurité des données | voir ci-dessous |

**Sécurité des données**
- L'appli collecte-t-elle ou partage-t-elle des données utilisateur des types requis ? **Oui**
- Toutes les données sont-elles chiffrées en transit ? **Oui**
- Méthode de suppression : **les utilisateurs peuvent demander la suppression** (et supprimer la maison dans l'app)
- Création de compte : **l'application ne permet pas de créer de compte** (identifiant anonyme, pas de connexion) — si la question est posée ainsi ; sinon « Autre » : pas de compte
- Types de données **collectés** (aucun n'est **partagé** au sens Google : Firebase est un sous-traitant, et ce que voient les autres membres est à l'initiative de l'utilisateur) :

| Catégorie Google | Type | Obligatoire ? | Finalité | Traité de façon éphémère ? |
|---|---|---|---|---|
| Informations personnelles | Nom (prénom choisi) | Obligatoire | Fonctionnalités de l'appli | Non |
| Informations personnelles | ID utilisateur (identifiant anonyme) | Obligatoire | Fonctionnalités de l'appli | Non |
| Activité dans les applis | Autre contenu généré par l'utilisateur (maison, pièces, tâches, astuces) | Obligatoire | Fonctionnalités de l'appli | Non |
| Activité dans les applis | Interactions avec l'appli (tâches cochées : quoi, quand, par qui) | Obligatoire | Fonctionnalités de l'appli | Non |

Rien d'autre : pas de position, contacts, photos, e-mail, téléphone, données financières, santé, journaux de plantage, identifiants publicitaires.

---

## 5. Avant l'étape 2 — à faire / à décider

1. **E-mail de contact** (fiche Play + politique de confidentialité) : Kinder le donne → Claude Code remplace `EMAIL_CONTACT_A_RENSEIGNER` dans `public/confidentialite.html`.
2. **Mise en ligne de la politique** : `firebase deploy --only hosting` (Claude Code, avec l'accord de Kinder). Vérifier ensuite que l'adresse s'ouvre. Ce déploiement republie aussi le reste du dossier `public/` tel qu'il est dans le dépôt.
3. **E-mails des testeurs** (les habitants + toute personne qui testera) : il faut leur adresse Google (celle du Play Store de leur téléphone).

---

## 6. Prompt pour l'étape 2 (Claude in Chrome)

```
Tu m'aides à publier mon application Android « Nickel » en TEST FERMÉ sur la Google Play Console (je suis déjà connecté, la page « Créer une application » est ouverte). Toutes les valeurs à saisir sont dans le document ci-dessous : n'invente rien, et si un champ n'y figure pas, demande-moi.

Règles :
- Avant chaque bouton qui enregistre, envoie ou publie (« Créer l'application », « Enregistrer », « Envoyer pour examen », « Démarrer le déploiement »), montre-moi ce que tu vas valider et attends mon OK.
- Les fichiers à téléverser sont dans V:\DEV\PROJETS\applications_mobile\Nickel\publication\ ; quand une fenêtre de choix de fichier s'ouvre, dis-moi quel fichier choisir et je le sélectionne.
- Ne coche jamais une case d'accord juridique sans me la lire.

Étapes :
1. Créer l'application (section 2 du document).
2. Tableau de bord → « Configurer votre application » : remplir chaque rubrique de la section 4 (confidentialité, accès, annonces, classification, public cible, actualités, sécurité des données, gouvernement, finances, santé), puis la fiche Play Store (section 3) et la catégorie.
3. Tests → Test fermé → piste « Closed testing » (Alpha) : créer une liste de testeurs avec les e-mails que je te donnerai, choisir les pays (France, Belgique, Suisse, Canada).
4. Créer une version dans ce test fermé. ARRÊTE-TOI à l'écran de la clé de signature de l'application : je dois choisir « utiliser ma propre clé » (exporter et importer depuis un keystore Java). Télécharge l'outil PEPK et la clé de chiffrement proposés, dis-moi où ils sont enregistrés, et attends : Claude Code va produire le fichier chiffré à téléverser.
5. Ensuite : téléverser app-release.aab, nom de version « 1.1.0 (5000) », notes de version :
   <fr-FR>Première version de test : tâches à fréquence, fiche et historique de chaque tâche, équipe et progression, astuces, rappel quotidien.</fr-FR>
6. Vérifier la version, me montrer les avertissements éventuels, puis « Envoyer pour examen » seulement avec mon accord.

[COLLER ICI TOUT LE CONTENU DU FICHIER PUBLICATION_PLAYSTORE.md]
```

---

## 7. Points d'attention

- **Clé de signature — choisir « ma propre clé »** (et non la clé générée par Google). Les téléphones de la maison ont aujourd'hui l'APK installé à la main, signé avec `nickel-release`. Avec la même clé, la version du Play Store s'installe **par-dessus**, sans rien perdre. Avec une clé Google, il faudrait désinstaller l'app : profil local perdu, nouvel identifiant, il faut rejoindre la maison à nouveau, et l'historique et l'XP déjà gagnés ne seraient plus rattachés à la personne. L'outil PEPK de Google chiffre la clé ; Claude Code lance la commande (Java présent sur le poste).
- **Accès à la production (comptes personnels récents)** : Google exige un test fermé avec **au moins 12 testeurs** inscrits pendant **14 jours d'affilée** avant de pouvoir demander la production. Si le compte est concerné, il faudra recruter au-delà des habitants.
- **Saison 1 du Marché « Trônes et dragons »** : objets et noms inspirés de Game of Thrones (« Fantôme », « Corbeau messager »…). Risque de refus ou de retrait pour propriété intellectuelle. Les images ne figurent pas dans les captures, mais les objets sont dans l'app (catalogue distant). **À traiter avant la production** ; le catalogue étant distant, un remplacement ne demanderait pas de nouvelle version de l'app.
- Le nom du package `com.nickelmenage.nickel_mobile` est définitif une fois l'application créée.
- Chaque nouvelle version devra avoir un numéro de version supérieur à 5000 (`version:` dans `mobile/pubspec.yaml`).
