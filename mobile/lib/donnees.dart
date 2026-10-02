// NICKEL — couche DONNÉES (Flutter)
//
// Équivalent Dart de public/v2/js/donnees.js. Même projet Firebase, même
// collection `maisons` et sous-collections, mêmes règles Firestore — rien
// ne change côté serveur, seule la façade est reconstruite (§ 18,
// PROJET_CONTEXTE.md).

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'jeu.dart';

final _db = FirebaseFirestore.instance;

/// Profil local minimal : id = uid Firebase Auth, prénom choisi par
/// l'utilisateur, couleur (stockée en hex "#rrggbb" côté Firestore, comme
/// en V2, pour rester interopérable avec le web).
class Profil {
  const Profil({required this.id, required this.prenom, required this.couleur});

  final String id;
  final String prenom;
  final Color couleur;
}

String couleurVersHex(Color c) {
  final argb = c.toARGB32();
  return '#${argb.toRadixString(16).padLeft(8, '0').substring(2)}';
}

Color hexVersCouleur(String hex) {
  final propre = hex.replaceFirst('#', '');
  return Color(int.parse('FF$propre', radix: 16));
}

const _caracteresCode = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans 0/O/1/I
String genererCode() {
  final alea = Random.secure();
  return List.generate(6, (_) => _caracteresCode[alea.nextInt(_caracteresCode.length)]).join();
}

/// Aujourd'hui en « AAAA-MM-JJ », dans le fuseau du téléphone — même piège
/// UTC évité qu'en V2 (PROJET_CONTEXTE.md § 16, point 8) : DateTime.now()
/// est déjà en heure locale sous Flutter, pas de conversion UTC involontaire.
String dateAujourdhui() {
  final d = DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String ajouterJours(String dateISO, int jours) {
  final parties = dateISO.split('-').map(int.parse).toList();
  final d = DateTime(parties[0], parties[1], parties[2] + jours);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Statuts identiques à la V2 (§ 3 modèle métier) : 'retard', 'aujourdhui',
/// 'avenir', 'jamais'. Comparaison de chaînes AAAA-MM-JJ = comparaison
/// chronologique correcte.
String statutTache(Map<String, dynamic> tache) {
  final echeance = tache['prochaineEcheance'] as String?;
  if (echeance == null) return 'jamais';
  final aujourdhui = dateAujourdhui();
  if (echeance.compareTo(aujourdhui) < 0) return 'retard';
  if (echeance == aujourdhui) return 'aujourdhui';
  return 'avenir';
}

/// Crée une maison, avec un code d'invitation unique, et y ajoute le profil
/// créateur comme premier membre.
Future<({String id, String codeInvitation})> creerMaison(String nom, Profil profil) async {
  final maisonRef = _db.collection('maisons').doc();
  final codeInvitation = genererCode();

  // Écriture atomique : la maison et son premier membre, ou rien. Avant, un
  // refus sur le membre laissait une maison orpheline sans aucun membre.
  final lot = _db.batch();
  lot.set(maisonRef, {
    'nom': nom,
    'codeInvitation': codeInvitation,
    'creeLe': DateTime.now().toIso8601String(),
  });
  lot.set(maisonRef.collection('membres').doc(profil.id), {
    'prenom': profil.prenom,
    'couleur': couleurVersHex(profil.couleur),
    'rejointLe': DateTime.now().toIso8601String(),
  });
  await lot.commit();

  return (id: maisonRef.id, codeInvitation: codeInvitation);
}

/// Cherche une maison par son code d'invitation et y ajoute le profil.
/// Retourne null si le code n'existe pas.
Future<Map<String, dynamic>?> rejoindreMaison(String code, Profil profil) async {
  final resultat = await _db
      .collection('maisons')
      .where('codeInvitation', isEqualTo: code.toUpperCase().trim())
      .limit(1)
      .get();

  if (resultat.docs.isEmpty) return null;

  final document = resultat.docs.first;
  // Déjà membre (rejoindre une maison qu'on a déjà) : les règles
  // interdisent de réécrire sa fiche membre, on n'y touche pas.
  final dejaMembre = await document.reference.collection('membres').doc(profil.id).get();
  if (dejaMembre.exists) return {'id': document.id, ...document.data()};

  await document.reference.collection('membres').doc(profil.id).set({
    'prenom': profil.prenom,
    'couleur': couleurVersHex(profil.couleur),
    'rejointLe': DateTime.now().toIso8601String(),
  });

  return {'id': document.id, ...document.data()};
}

Future<Map<String, dynamic>?> chargerMaison(String maisonId) async {
  final snap = await _db.collection('maisons').doc(maisonId).get();
  if (!snap.exists) return null;
  return {'id': snap.id, ...snap.data()!};
}

Stream<List<Map<String, dynamic>>> ecouterTaches(String maisonId) {
  return _db.collection('maisons').doc(maisonId).collection('taches').snapshots().map(
        (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      );
}

Stream<List<Map<String, dynamic>>> ecouterMembres(String maisonId) {
  return _db.collection('maisons').doc(maisonId).collection('membres').snapshots().map(
        (snap) {
          final membres = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          membres.sort((a, b) => (a['rejointLe'] as String).compareTo(b['rejointLe'] as String));
          return membres;
        },
      );
}

/// Les maisons de la liste locale dont ce profil est encore membre (une
/// maison supprimée par un autre membre, ou dont on a été retiré, n'y
/// figure plus). Ordre de la liste conservé.
Future<List<Map<String, dynamic>>> chargerMesMaisons(List<String> ids, String profilId) async {
  final maisons = <Map<String, dynamic>>[];
  for (final id in ids) {
    final maison = await _db.collection('maisons').doc(id).get();
    if (!maison.exists) continue;
    final membre = await maison.reference.collection('membres').doc(profilId).get();
    if (!membre.exists) continue;
    maisons.add({'id': maison.id, ...maison.data()!});
  }
  return maisons;
}

/// Supprime une maison et tout son contenu (pièces, tâches, historique,
/// membres), décision de Kinder du 2026-09-10 (§ 19). Ordre imposé par les
/// règles Firestore : tant qu'on efface, il faut rester membre — sa propre
/// fiche membre est donc effacée en tout dernier.
Future<void> supprimerMaison(String maisonId, String profilId) async {
  final maison = _db.collection('maisons').doc(maisonId);

  Future<void> viderCollection(String nom, {String? sauf}) async {
    final docs = (await maison.collection(nom).get()).docs.where((d) => d.id != sauf).toList();
    // Écritures groupées par paquets (limite Firestore : 500 par lot).
    for (var i = 0; i < docs.length; i += 400) {
      final lot = _db.batch();
      for (final d in docs.skip(i).take(400)) {
        lot.delete(d.reference);
      }
      await lot.commit();
    }
  }

  await viderCollection('realisations');
  await viderCollection('taches');
  await viderCollection('pieces');
  await viderCollection('membres', sauf: profilId);
  await maison.delete();
  await maison.collection('membres').doc(profilId).delete();
}

Future<void> quitterMaison(String maisonId, String profilId) async {
  await _db.collection('maisons').doc(maisonId).collection('membres').doc(profilId).delete();
}

/// Retire un AUTRE membre d'une maison (droits identiques, pas de rôle
/// propriétaire — n'importe quel membre peut retirer n'importe quel autre).
/// Même écriture que `quitterMaison`, exposée séparément pour que
/// l'appelant ne puisse pas se tromper de profil par accident.
Future<void> retirerMembre(String maisonId, String membreId) async {
  await _db.collection('maisons').doc(maisonId).collection('membres').doc(membreId).delete();
}

Future<String> creerPiece(String maisonId, String nom) async {
  final ref = await _db.collection('maisons').doc(maisonId).collection('pieces').add({
    'nom': nom,
    'creeLe': DateTime.now().toIso8601String(),
  });
  return ref.id;
}

Future<void> creerTache(
  String maisonId, {
  required String nom,
  required String pieceId,
  required int frequenceJours,
  String produit = '',
  String astuce = '',
  String emoji = '🧹',
  String ustensile = '',
  String aEviter = '',
  String fiabilite = '',
  int? dureeMinutes,
}) async {
  await _db.collection('maisons').doc(maisonId).collection('taches').add({
    'nom': nom,
    'pieceId': pieceId,
    'frequenceJours': frequenceJours,
    'produit': produit,
    'astuce': astuce,
    'emoji': emoji,
    'ustensile': ustensile,
    'aEviter': aEviter,
    'fiabilite': fiabilite,
    'dureeMinutes': dureeMinutes,
    'prochaineEcheance': null,
  });
}

/// Lecture ponctuelle des tâches (pas un abonnement) — utilisée par le
/// rappel quotidien, qui se réveille en arrière-plan, lit une fois et se
/// rendort.
Future<List<Map<String, dynamic>>> lireTaches(String maisonId) async {
  final snap = await _db.collection('maisons').doc(maisonId).collection('taches').get();
  return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
}

Stream<List<Map<String, dynamic>>> ecouterPieces(String maisonId) {
  return _db.collection('maisons').doc(maisonId).collection('pieces').snapshots().map((snap) {
    final pieces = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    pieces.sort((a, b) => (a['nom'] as String).compareTo(b['nom'] as String));
    return pieces;
  });
}

/// Renomme une Pièce.
Future<void> modifierPiece(String maisonId, String pieceId, String nom) async {
  await _db.collection('maisons').doc(maisonId).collection('pieces').doc(pieceId).update({'nom': nom});
}

/// Supprime une Pièce. Refuse si elle contient encore des Tâches (V2-D12 :
/// une Tâche appartient obligatoirement à une Pièce — pas de suppression en
/// cascade silencieuse, il faut d'abord vider la pièce).
Future<void> supprimerPiece(String maisonId, String pieceId) async {
  final tachesSnap = await _db
      .collection('maisons')
      .doc(maisonId)
      .collection('taches')
      .where('pieceId', isEqualTo: pieceId)
      .get();
  if (tachesSnap.docs.isNotEmpty) {
    throw Exception('Cette pièce contient encore des tâches. Supprimez-les d\'abord.');
  }
  await _db.collection('maisons').doc(maisonId).collection('pieces').doc(pieceId).delete();
}

/// Modifie une Tâche (nom, fréquence, produit, ustensile, astuce, à éviter,
/// emoji). Ne touche ni à la fiabilité ni à la durée (elles viennent du
/// modèle) ni à `pieceId` : déplacer une tâche d'une pièce à l'autre est hors
/// périmètre (comme en V2).
Future<void> modifierTache(
  String maisonId,
  String tacheId, {
  required String nom,
  required int frequenceJours,
  String produit = '',
  String astuce = '',
  String emoji = '🧹',
  String ustensile = '',
  String aEviter = '',
}) async {
  await _db.collection('maisons').doc(maisonId).collection('taches').doc(tacheId).update({
    'nom': nom,
    'frequenceJours': frequenceJours,
    'produit': produit,
    'astuce': astuce,
    'emoji': emoji,
    'ustensile': ustensile,
    'aEviter': aEviter,
  });
}

/// Supprime une Tâche. L'historique (Réalisations) n'est jamais touché.
Future<void> supprimerTache(String maisonId, String tacheId) async {
  await _db.collection('maisons').doc(maisonId).collection('taches').doc(tacheId).delete();
}

/// Enregistre qu'une tâche vient d'être faite (§ 3, règle héritée de la
/// V1). Deux écritures indissociables : la Réalisation (jamais modifiée,
/// jamais supprimée — c'est l'historique) et la nouvelle échéance de la
/// Tâche.
Future<void> enregistrerRealisation(
  String maisonId,
  String tacheId,
  String profilId,
  String dateISO,
  String prochaineEcheance, {
  int xp = 10,
}) async {
  final maison = _db.collection('maisons').doc(maisonId);
  final lot = _db.batch();
  lot.set(maison.collection('realisations').doc(), {
    'tacheId': tacheId,
    'realiseParId': profilId,
    'dateRealisation': dateISO,
    // XP gagné, figé au moment de la coche (§ 25).
    'xp': xp,
    'enregistreLe': DateTime.now().toIso8601String(),
  });
  lot.update(maison.collection('taches').doc(tacheId), {
    'prochaineEcheance': prochaineEcheance,
  });
  await lot.commit();
}

/// Supprime une Réalisation cochée par erreur (règle figée "jamais
/// supprimée" levée le 2026-09-10, § 19) et recalcule l'échéance de la
/// tâche : dernière réalisation restante + fréquence actuelle, ou "à faire"
/// (échéance vide) s'il n'en reste aucune.
Future<void> supprimerRealisation(String maisonId, String realisationId, String tacheId) async {
  final maison = _db.collection('maisons').doc(maisonId);
  final tacheRef = maison.collection('taches').doc(tacheId);

  final restantes = await maison.collection('realisations').where('tacheId', isEqualTo: tacheId).get();
  String? derniereDate;
  for (final r in restantes.docs) {
    if (r.id == realisationId) continue;
    final date = r.data()['dateRealisation'] as String;
    if (derniereDate == null || date.compareTo(derniereDate) > 0) derniereDate = date;
  }

  final lot = _db.batch();
  lot.delete(maison.collection('realisations').doc(realisationId));

  // La tâche a pu être supprimée entre-temps : dans ce cas on efface
  // seulement la Réalisation.
  final tache = await tacheRef.get();
  if (tache.exists) {
    final frequence = tache.data()!['frequenceJours'] as int;
    lot.update(tacheRef, {
      'prochaineEcheance': derniereDate == null ? null : ajouterJours(derniereDate, frequence),
    });
  }
  await lot.commit();
}

/// Toutes les Réalisations de la maison (sans limite) : nécessaire au calcul
/// de l'XP et des succès. Un foyer de quelques personnes en produit peu.
Stream<List<Map<String, dynamic>>> ecouterToutesRealisations(String maisonId) {
  return _db
      .collection('maisons')
      .doc(maisonId)
      .collection('realisations')
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
}

/// Met à jour sa propre fiche personnage dans une maison (§ 25).
Future<void> modifierProfil(
  String maisonId,
  String membreId, {
  required String prenom,
  required String avatar,
  required String couverture,
  required List<String> badges,
}) async {
  await _db.collection('maisons').doc(maisonId).collection('membres').doc(membreId).update({
    'prenom': prenom,
    'avatar': avatar,
    'couverture': couverture,
    'badges': badges,
  });
}

/// Achète un objet de la boutique : l'ajoute à la liste d'achats du membre.
/// Le solde est vérifié par l'appelant (gains calculés − dépenses).
Future<void> acheterObjet(String maisonId, String membreId, String objetId) async {
  await _db.collection('maisons').doc(maisonId).collection('membres').doc(membreId).update({
    'achats': FieldValue.arrayUnion([objetId]),
  });
}

/// Bonus de connexion du jour : à appeler à l'ouverture de l'app. Une seule
/// fois par jour (sinon renvoie 0). La série repart de 1 si un jour a été
/// sauté. Transaction : deux appareils du même membre ne le comptent pas deux fois.
Future<({int montant, int serie})> reclamerBonusConnexion(String maisonId, String membreId) {
  final ref = _db.collection('maisons').doc(maisonId).collection('membres').doc(membreId);
  return _db.runTransaction((tx) async {
    final data = (await tx.get(ref)).data() ?? {};
    final aujourdhui = dateAujourdhui();
    final derniere = data['derniereConnexion'] as String?;
    final serieActuelle = (data['serieConnexion'] as int?) ?? 0;
    if (derniere == aujourdhui) return (montant: 0, serie: serieActuelle);
    final serie = derniere == ajouterJours(aujourdhui, -1) ? serieActuelle + 1 : 1;
    final montant = bonusConnexion(serie);
    tx.update(ref, {
      'derniereConnexion': aujourdhui,
      'serieConnexion': serie,
      'bullesBonus': ((data['bullesBonus'] as int?) ?? 0) + montant,
    });
    return (montant: montant, serie: serie);
  });
}

/// Cadeau de saison : une fois par clé (saison + année). Renvoie false s'il
/// avait déjà été récupéré.
Future<bool> reclamerDotationSaison(String maisonId, String membreId, String cle, int montant) {
  final ref = _db.collection('maisons').doc(maisonId).collection('membres').doc(membreId);
  return _db.runTransaction((tx) async {
    final data = (await tx.get(ref)).data() ?? {};
    final deja = ((data['dotations'] as List?) ?? const []).whereType<String>().toList();
    if (deja.contains(cle)) return false;
    tx.update(ref, {
      'dotations': [...deja, cle],
      'bullesBonus': ((data['bullesBonus'] as int?) ?? 0) + montant,
    });
    return true;
  });
}

/// Équipe un objet possédé : champ `avatar` ou `couverture` de sa fiche.
Future<void> equiperObjet(String maisonId, String membreId, String champ, String objetId) async {
  assert(champ == 'avatar' || champ == 'couverture');
  await _db.collection('maisons').doc(maisonId).collection('membres').doc(membreId).update({champ: objetId});
}

/// Réinscrit ce profil dans sa maison sous l'identifiant actuel de
/// l'appareil quand celui-ci a changé (réinstallation avec restauration de
/// la sauvegarde Android : le profil local revient, mais Firebase attribue
/// un nouvel identifiant). Retire l'ancienne entrée devenue orpheline. Sans
/// effet si la maison n'existe plus.
Future<void> reprendreMaison(String maisonId, Profil profil, String ancienId) async {
  final maison = await _db.collection('maisons').doc(maisonId).get();
  if (!maison.exists) return;

  final membres = maison.reference.collection('membres');
  final ancien = await membres.doc(ancienId).get();
  await membres.doc(profil.id).set({
    'prenom': profil.prenom,
    'couleur': couleurVersHex(profil.couleur),
    'rejointLe': (ancien.data()?['rejointLe'] as String?) ?? DateTime.now().toIso8601String(),
  });
  if (ancien.exists) await membres.doc(ancienId).delete();
}

/// S'abonne à l'historique d'une maison, le plus récent en premier —
/// comme en V2 (`ecouterRealisations`, donnees.js).
Stream<List<Map<String, dynamic>>> ecouterRealisations(String maisonId, {int limite = 100}) {
  return _db
      .collection('maisons')
      .doc(maisonId)
      .collection('realisations')
      .orderBy('enregistreLe', descending: true)
      .limit(limite)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
}

/// Produits et ustensiles sont des listes dans les modèles v2, du texte dans
/// les maisons déjà créées (et dans le modèle générique v1) : on stocke
/// toujours du texte « a, b, c ».
String _texteModele(dynamic valeur) {
  if (valeur is List) return valeur.join(', ');
  return (valeur as String?) ?? '';
}

/// Importe une structure (pièces + tâches) depuis un modèle JSON : crée
/// toujours une NOUVELLE maison (V2-D9, jamais de fusion). Même format que
/// public/v2/modeles/*.json.
Future<({String id, String codeInvitation})> importerStructure(
  String nomMaison,
  Map<String, dynamic> structure,
  Profil profil,
) async {
  final maison = await creerMaison(nomMaison, profil);

  for (final piece in (structure['pieces'] as List? ?? [])) {
    final pieceId = await creerPiece(maison.id, piece['nom'] as String);
    for (final tache in (piece['taches'] as List? ?? [])) {
      await creerTache(
        maison.id,
        nom: tache['nom'] as String,
        pieceId: pieceId,
        frequenceJours: tache['frequenceJours'] as int,
        produit: _texteModele(tache['produit']),
        astuce: tache['astuce'] as String? ?? '',
        emoji: tache['emoji'] as String? ?? '🧹',
        ustensile: _texteModele(tache['ustensile']),
        aEviter: tache['aEviter'] as String? ?? '',
        fiabilite: tache['fiabilite'] as String? ?? '',
        dureeMinutes: tache['dureeMinutes'] as int?,
      );
    }
  }

  return maison;
}
