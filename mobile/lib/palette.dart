import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// Palette reprise de la V2 (public/v2/index.html) — même identité visuelle,
// "le registre d'entretien" (§ 11 PROJET_CONTEXTE.md).
class Palette {
  static const papier = Color(0xFFEFE7D6);
  static const papierClair = Color(0xFFF6EFDE);
  static const encre = Color(0xFF16150F);
  static const encreDouce = Color(0xFF5C5849);
  static const encreFaible = Color(0xFF6D685B);
  static const trait = Color(0xFFD8CFB8);
  static const rouge = Color(0xFFB4321F);
  static const vert = Color(0xFF2E6B4E);
  // Texte d'exemple dans un champ vide : nettement plus pâle (et en
  // italique) qu'une vraie saisie, pour ne pas croire le champ déjà rempli.
  static const indice = Color(0xFF8F897A);
}

// Liste restreinte d'emoji pour les tâches — même liste que la V2 web
// (public/v2/js/app.js, EMOJI_TACHES), § 11 refonte visuelle.
const emojiTaches = [
  '🧹', '🧽', '🧴', '🪣', '🧺', '🚿', '🚽', '🪟',
  '🪑', '🛋️', '🛏️', '🍽️', '🧊', '🔥', '🍳', '💧',
  '🗑️', '♻️', '🧼', '🪥', '🚪', '💻', '🌿', '🐾',
  '📦', '🚰', '🪞', '🧯', '🔌', '🛁',
];
const emojiParDefaut = '🧹';

const couleursProfil = [
  Color(0xFFF2A65A),
  Color(0xFF5AA9E6),
  Color(0xFFC77DFF),
  Color(0xFF2E6B4E),
  Color(0xFFB4321F),
  Color(0xFF6B675A),
];

ButtonStyle boutonPrincipal() => ElevatedButton.styleFrom(
      backgroundColor: Palette.encre,
      foregroundColor: Palette.papier,
      minimumSize: const Size.fromHeight(52),
      shape: const RoundedRectangleBorder(),
    );

ButtonStyle boutonSecondaire() => OutlinedButton.styleFrom(
      foregroundColor: Palette.encre,
      side: const BorderSide(color: Palette.encre, width: 2),
      minimumSize: const Size.fromHeight(52),
      shape: const RoundedRectangleBorder(),
    );

InputDecoration decorationChamp(String indice, {String? aide, String? erreur}) => InputDecoration(
      hintText: indice,
      hintStyle: const TextStyle(color: Palette.indice, fontStyle: FontStyle.italic),
      helperText: aide,
      helperMaxLines: 3,
      helperStyle: const TextStyle(color: Palette.encreFaible, fontSize: 12),
      errorText: erreur,
      errorMaxLines: 3,
      errorStyle: const TextStyle(color: Palette.rouge, fontSize: 12, fontWeight: FontWeight.w600),
      errorBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Palette.rouge, width: 2)),
      focusedErrorBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Palette.rouge, width: 2.5)),
      filled: true,
      fillColor: Palette.papierClair,
      border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Palette.encre, width: 2)),
      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Palette.encre, width: 2)),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Palette.encre, width: 2)),
    );

/// Libellé d'un champ de formulaire, avec la mention « obligatoire » ou
/// « facultatif » pour que l'utilisateur sache ce qui est attendu.
Widget libelleChamp(String texte, {bool obligatoire = false}) => Text.rich(
      TextSpan(
        text: texte,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce),
        children: [
          TextSpan(
            text: obligatoire ? '  obligatoire' : '  facultatif',
            style: TextStyle(fontWeight: FontWeight.normal, fontSize: 12, color: obligatoire ? Palette.rouge : Palette.encreFaible),
          ),
        ],
      ),
    );

/// Message affiché quand une écriture n'a pas pu joindre le serveur à temps.
/// Firestore la garde sur le téléphone et l'envoie au retour du réseau.
const messageHorsConnexion =
    "Pas de connexion pour l'instant : c'est gardé sur ce téléphone et sera partagé avec la maison dès le retour du réseau.";

/// Attend une écriture Firestore sans bloquer l'écran hors connexion (sans
/// réseau, Firestore ne confirme jamais l'écriture : on lève une
/// `TimeoutException` au bout de 8 s, traduite par `texteErreur`).
Future<T> ecrire<T>(Future<T> ecriture) => ecriture.timeout(const Duration(seconds: 8));

/// Traduit une erreur (Firebase, délai dépassé, refus métier) en phrase
/// compréhensible — jamais de message technique brut à l'écran.
String texteErreur(Object e) {
  if (e is TimeoutException) return messageHorsConnexion;
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return "Action refusée : vous ne faites peut-être plus partie de cette maison. Rouvrez l'app et réessayez.";
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Pas de connexion internet. Vérifiez le réseau et réessayez.';
      case 'not-found':
        return "Cet élément n'existe plus : il a peut-être été supprimé par un autre membre.";
      case 'resource-exhausted':
        return 'Le service est saturé pour le moment. Réessayez dans quelques minutes.';
    }
  }
  final texte = e.toString();
  if (e is Exception && texte.startsWith('Exception: ')) return texte.substring('Exception: '.length);
  return "Quelque chose s'est mal passé. Réessayez dans un instant.";
}

/// Affiche une erreur en bas de l'écran, en rouge (en neutre pour le cas
/// « hors connexion », qui n'est pas un échec).
void signalerErreur(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(texteErreur(e)),
    backgroundColor: e is TimeoutException ? null : Palette.rouge,
    duration: const Duration(seconds: 6),
  ));
}

/// Confirme en bas de l'écran qu'une action a réussi.
void signalerSucces(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
