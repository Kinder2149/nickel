import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nickel_mobile/main.dart';

void main() {
  testWidgets("L'app démarre sans planter", (WidgetTester tester) async {
    await tester.pumpWidget(const NickelApp());
    // Firebase n'est pas initialisé dans ce test unitaire : on vérifie
    // juste que l'arbre de widgets se construit (écran de démarrage
    // visible), pas le flux d'authentification complet.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
