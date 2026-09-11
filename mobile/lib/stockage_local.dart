// Équivalent des clés `localStorage` de la V2 (public/v2/js/app.js,
// CLE_PROFIL / CLE_MAISON) — mais avec shared_preferences.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'donnees.dart';
import 'palette.dart';

const _cleProfilId = 'nickel-profil-id';
const _cleProfilPrenom = 'nickel-profil-prenom';
const _cleProfilCouleur = 'nickel-profil-couleur';
// Maison affichée (clé historique, conservée telle quelle pour que la mise
// à jour ne perde pas la maison en cours) + liste de toutes les maisons de
// cet appareil (plusieurs maisons par profil, § 19 étape 4).
const _cleMaisonId = 'nickel-maison-id';
const _cleMaisons = 'nickel-maisons';

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

String? chargerMaisonIdLocal(SharedPreferences prefs) => prefs.getString(_cleMaisonId);

/// Toutes les maisons connues de cet appareil. La maison affichée y figure
/// toujours (cas d'une installation antérieure à la liste).
List<String> chargerMaisonsLocales(SharedPreferences prefs) {
  final liste = List<String>.from(prefs.getStringList(_cleMaisons) ?? const []);
  final courante = prefs.getString(_cleMaisonId);
  if (courante != null && !liste.contains(courante)) liste.add(courante);
  return liste;
}

/// Ajoute une maison à la liste et en fait la maison affichée.
Future<void> ajouterMaisonLocale(SharedPreferences prefs, String maisonId) async {
  final liste = chargerMaisonsLocales(prefs);
  if (!liste.contains(maisonId)) liste.add(maisonId);
  await prefs.setStringList(_cleMaisons, liste);
  await prefs.setString(_cleMaisonId, maisonId);
}

Future<void> choisirMaisonLocale(SharedPreferences prefs, String maisonId) =>
    prefs.setString(_cleMaisonId, maisonId);

/// Retire une maison de la liste (quittée, supprimée ou introuvable). Si
/// c'était la maison affichée, la suivante de la liste prend le relais.
Future<void> retirerMaisonLocale(SharedPreferences prefs, String maisonId) async {
  final liste = chargerMaisonsLocales(prefs)..remove(maisonId);
  await prefs.setStringList(_cleMaisons, liste);
  if (prefs.getString(_cleMaisonId) == maisonId) {
    if (liste.isEmpty) {
      await prefs.remove(_cleMaisonId);
    } else {
      await prefs.setString(_cleMaisonId, liste.first);
    }
  }
}
