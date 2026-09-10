// NICKEL — couche DONNÉES (Flutter)
//
// Équivalent Dart de public/v2/js/donnees.js. Même projet Firebase, même
// collection `maisons` et sous-collections, mêmes règles Firestore — rien
// ne change côté serveur, seule la façade est reconstruite (§ 18,
// PROJET_CONTEXTE.md).

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final maisonId = _db.collection('maisons').doc().id;
  final codeInvitation = genererCode();

  await _db.collection('maisons').doc(maisonId).set({
    'nom': nom,
    'codeInvitation': codeInvitation,
    'creeLe': DateTime.now().toIso8601String(),
  });

  await _db.collection('maisons').doc(maisonId).collection('membres').doc(profil.id).set({
    'prenom': profil.prenom,
    'couleur': couleurVersHex(profil.couleur),
    'rejointLe': DateTime.now().toIso8601String(),
  });

  return (id: maisonId, codeInvitation: codeInvitation);
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

Future<void> quitterMaison(String maisonId, String profilId) async {
  await _db.collection('maisons').doc(maisonId).collection('membres').doc(profilId).delete();
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
}) async {
  await _db.collection('maisons').doc(maisonId).collection('taches').add({
    'nom': nom,
    'pieceId': pieceId,
    'frequenceJours': frequenceJours,
    'produit': produit,
    'astuce': astuce,
    'emoji': emoji,
    'responsablePrevu': null,
    'prochaineEcheance': null,
  });
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

/// Modifie une Tâche (nom, fréquence, produit, astuce, emoji). Ne touche
/// jamais à `pieceId` : déplacer une tâche d'une pièce à l'autre est hors
/// périmètre (comme en V2).
Future<void> modifierTache(
  String maisonId,
  String tacheId, {
  required String nom,
  required int frequenceJours,
  String produit = '',
  String astuce = '',
  String emoji = '🧹',
}) async {
  await _db.collection('maisons').doc(maisonId).collection('taches').doc(tacheId).update({
    'nom': nom,
    'frequenceJours': frequenceJours,
    'produit': produit,
    'astuce': astuce,
    'emoji': emoji,
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
  String prochaineEcheance,
) async {
  await _db.collection('maisons').doc(maisonId).collection('realisations').add({
    'tacheId': tacheId,
    'realiseParId': profilId,
    'dateRealisation': dateISO,
    'enregistreLe': DateTime.now().toIso8601String(),
  });

  await _db.collection('maisons').doc(maisonId).collection('taches').doc(tacheId).update({
    'prochaineEcheance': prochaineEcheance,
  });
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
        produit: tache['produit'] as String? ?? '',
        astuce: tache['astuce'] as String? ?? '',
        emoji: tache['emoji'] as String? ?? '🧹',
      );
    }
  }

  return maison;
}
