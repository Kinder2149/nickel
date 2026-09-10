import 'package:flutter/material.dart';

// Palette reprise de la V2 (public/v2/index.html) — même identité visuelle,
// "le registre d'entretien" (§ 11 PROJET_CONTEXTE.md).
class Palette {
  static const papier = Color(0xFFEFE7D6);
  static const papierClair = Color(0xFFF6EFDE);
  static const encre = Color(0xFF16150F);
  static const encreDouce = Color(0xFF6B675A);
  static const encreFaible = Color(0xFFA9A18D);
  static const trait = Color(0xFFD8CFB8);
  static const rouge = Color(0xFFB4321F);
  static const vert = Color(0xFF2E6B4E);
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

InputDecoration decorationChamp(String indice) => InputDecoration(
      hintText: indice,
      filled: true,
      fillColor: Palette.papierClair,
      border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Palette.encre, width: 2)),
      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Palette.encre, width: 2)),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Palette.encre, width: 2)),
    );
