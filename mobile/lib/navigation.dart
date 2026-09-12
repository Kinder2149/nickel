import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'donnees.dart';
import 'ecran_maison.dart';
import 'ecran_racine.dart';
import 'stockage_local.dart';

/// Ouvre la maison affichée de cet appareil, ou l'écran "Votre maison" s'il
/// n'en a plus aucune, en vidant la pile de navigation : après avoir changé,
/// quitté ou supprimé une maison, le bouton retour d'Android ne doit pas
/// ramener vers l'ancienne.
Future<void> ouvrirMaisonCourante(BuildContext context, Profil profil) async {
  final prefs = await SharedPreferences.getInstance();
  final maisonId = chargerMaisonIdLocal(prefs);
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => maisonId == null ? EcranMaison(profil: profil) : EcranRacine(profil: profil, maisonId: maisonId),
    ),
    (route) => false,
  );
}
