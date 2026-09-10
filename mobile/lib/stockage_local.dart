// Équivalent des clés `localStorage` de la V2 (public/v2/js/app.js,
// CLE_PROFIL / CLE_MAISON) — mais avec shared_preferences.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'donnees.dart';
import 'palette.dart';

const _cleProfilId = 'nickel-profil-id';
const _cleProfilPrenom = 'nickel-profil-prenom';
const _cleProfilCouleur = 'nickel-profil-couleur';
const _cleMaisonId = 'nickel-maison-id';

Future<void> enregistrerProfilLocal(SharedPreferences prefs, Profil profil) async {
  await prefs.setString(_cleProfilId, profil.id);
  await prefs.setString(_cleProfilPrenom, profil.prenom);
  await prefs.setInt(_cleProfilCouleur, profil.couleur.toARGB32());
}

Profil? chargerProfilLocal(SharedPreferences prefs) {
  final prenom = prefs.getString(_cleProfilPrenom);
  final id = prefs.getString(_cleProfilId);
  if (prenom == null || id == null) return null;
  final couleurArgb = prefs.getInt(_cleProfilCouleur) ?? couleursProfil.first.toARGB32();
  return Profil(id: id, prenom: prenom, couleur: Color(couleurArgb));
}

Future<void> enregistrerMaisonIdLocal(SharedPreferences prefs, String maisonId) =>
    prefs.setString(_cleMaisonId, maisonId);

String? chargerMaisonIdLocal(SharedPreferences prefs) => prefs.getString(_cleMaisonId);

Future<void> effacerMaisonIdLocal(SharedPreferences prefs) => prefs.remove(_cleMaisonId);
