// Détecteur de coupure (police au maximum) : cherche dans l'arbre affiché
// tout texte qui dépasse son nombre de lignes, tout mot cassé en deux et tout
// texte qui sort de la boîte qui le contient.

import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> coupures(WidgetTester tester) {
  final problemes = <String>[];
  void visite(RenderObject r) {
    if (r is RenderParagraph) {
      final texte = r.text.toPlainText();
      if (r.didExceedMaxLines) problemes.add('« $texte » : plus de lignes que permis (coupé)');
      final span = r.text;
      if (r.size.width > 0 && span is TextSpan) {
        for (final mot in texte.split(RegExp(r'\s+')).where((m) => m.isNotEmpty)) {
          final mesure = TextPainter(text: TextSpan(text: mot, style: span.style), textDirection: r.textDirection, textScaler: r.textScaler)..layout();
          if (mesure.width > r.size.width + 0.5) {
            problemes.add('« $texte » : le mot « $mot » est cassé en deux');
            break;
          }
        }
      }
      final zone = MatrixUtils.transformRect(r.getTransformTo(null), Offset.zero & r.size);
      RenderObject? parent = r.parent;
      while (parent != null) {
        if (parent is RenderAbstractViewport) break;
        if (parent is RenderBox && parent.hasSize) {
          final b = MatrixUtils.transformRect(parent.getTransformTo(null), Offset.zero & parent.size);
          if (zone.bottom > b.bottom + 0.5 || zone.top < b.top - 0.5 || zone.right > b.right + 0.5 || zone.left < b.left - 0.5) {
            problemes.add('« $texte » : sort de sa boîte (${parent.runtimeType})');
            break;
          }
        }
        parent = parent.parent;
      }
    }
    r.visitChildren(visite);
  }

  visite(tester.binding.renderViews.first);
  final exception = tester.takeException();
  if (exception != null) problemes.add('erreur de débordement : ${exception.toString().split('\n').first}');
  return problemes;
}

/// Charge la vraie police de l'appli (Roboto, livrée avec Flutter) : la police
/// de test par défaut (Ahem) est deux fois trop large et fausserait la mesure.
Future<void> chargerRoboto() async {
  final racine = Platform.environment['FLUTTER_ROOT'] ?? '';
  final dossier = '$racine/bin/cache/artifacts/material_fonts';
  final chargeur = FontLoader('Roboto');
  for (final f in ['regular', 'medium', 'bold', 'black', 'light']) {
    final fichier = File('$dossier/roboto-$f.ttf');
    if (!fichier.existsSync()) throw StateError('Police introuvable : ${fichier.path} (FLUTTER_ROOT=$racine)');
    chargeur.addFont(Future.value(ByteData.view(fichier.readAsBytesSync().buffer)));
  }
  await chargeur.load();
}
