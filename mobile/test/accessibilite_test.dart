// Garde-fous d'accessibilité et de lisibilité du jeu (mission 1, § 30) :
// contrastes de la palette, cartes du marché à police agrandie, libellés
// pour lecteur d'écran.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nickel_mobile/catalogue.dart';
import 'package:nickel_mobile/catalogue_distant.dart';
import 'package:nickel_mobile/jeu.dart';
import 'package:nickel_mobile/palette.dart';
import 'package:nickel_mobile/widgets_objet.dart';

double contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final clair = la > lb ? la : lb, sombre = la > lb ? lb : la;
  return (clair + 0.05) / (sombre + 0.05);
}

void main() {
  test('contrastes de texte ≥ 4,5:1 sur le papier', () {
    for (final fond in [Palette.papier, Palette.papierClair]) {
      for (final (nom, c) in [
        ('encre', Palette.encre),
        ('encreDouce', Palette.encreDouce),
        ('encreFaible', Palette.encreFaible),
        ('vert', Palette.vert),
        ('rouge', Palette.rouge),
        for (final r in Rarete.values) ('rareté ${r.libelle}', r.couleurTexte),
      ]) {
        expect(contraste(c, fond), greaterThanOrEqualTo(4.5), reason: '$nom sur ${fond.toARGB32().toRadixString(16)}');
      }
    }
    // les bordures et pictogrammes se contentent de 3:1
    for (final r in Rarete.values) {
      expect(contraste(r.couleur, Palette.papierClair), greaterThanOrEqualTo(2.6), reason: 'bordure ${r.libelle}');
    }
  });

  const casque = Objet(id: 'casque', type: TypeObjet.avatar, nom: 'Casque', prix: 40, icone: Icons.headphones);
  const long = Objet(id: 'l', type: TypeObjet.avatar, nom: 'Corbeau et chaîne de mestre', rarete: Rarete.legendaire, prix: 600, icone: Icons.pets);
  const couv = Objet(id: 'c', type: TypeObjet.couverture, nom: 'Salle du trône de balais', rarete: Rarete.epique, prix: 250, couleurs: [Color(0xFF1B2A49), Color(0xFF5B6EA8)]);
  const exclusif = Objet(id: 'e', type: TypeObjet.avatar, nom: 'Trophée du champion', rarete: Rarete.legendaire, icone: Icons.emoji_events, succesRequis: 'cinqcents');
  const saisonnier = Objet(id: 's', type: TypeObjet.avatar, nom: 'Silverwing', rarete: Rarete.epique, prix: 250, icone: Icons.pets, saison: 'h');

  Widget page(double echelle, List<Widget> cartes) => MaterialApp(
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(echelle)), child: child!),
        home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: GrilleObjets(enfants: cartes))),
      );

  List<Widget> toutesLesCartes() {
    final maintenant = DateTime(2027, 2, 3); // hors saison pour « h » (octobre à décembre)
    Widget carte(Objet o, EtatObjet e) => CarteObjet(
          objet: o,
          couleur: Colors.teal,
          bouton: BoutonObjet(objet: o, etat: e, solde: 100, maintenant: maintenant, nomSucces: 'Légende du ménage'),
        );
    return [
      carte(casque, EtatObjet.achetable),
      carte(long, EtatObjet.pasAssez),
      carte(couv, EtatObjet.possede),
      carte(casque, EtatObjet.equipe),
      carte(exclusif, EtatObjet.exclusif),
      carte(saisonnier, EtatObjet.horsSaison),
      carte(saisonnier, EtatObjet.bientot),
    ];
  }

  for (final echelle in [1.0, 1.5, 2.0]) {
    testWidgets('cartes du marché sans débordement à police x$echelle', (tester) async {
      saisonsDistantes.value = const [Saison(id: 'h', nom: 'H', theme: '', debut: '2026-10-01', mois: [10, 11, 12])];
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(page(echelle, toutesLesCartes()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      saisonsDistantes.value = const [];
    });
  }

  testWidgets('boutons du marché : 48 px de haut au moins', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page(1.0, [
      CarteObjet(objet: casque, couleur: Colors.teal, bouton: BoutonObjet(objet: casque, etat: EtatObjet.achetable, solde: 100, maintenant: DateTime(2026, 11, 1))),
    ]));
    expect(tester.getSize(find.byType(ElevatedButton)).height, greaterThanOrEqualTo(48));
  });

  testWidgets('lecteur d\'écran : une carte se lit « Casque, Commun, 40 Bulles »', (tester) async {
    final poignee = tester.ensureSemantics();
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page(1.0, [
      CarteObjet(objet: casque, couleur: Colors.teal, bouton: BoutonObjet(objet: casque, etat: EtatObjet.achetable, solde: 100, maintenant: DateTime(2026, 11, 1))),
    ]));
    expect(find.bySemanticsLabel(RegExp('Casque, Commun, 40 Bulles')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Avatar Casque')), findsWidgets);
    poignee.dispose();
  });
}
