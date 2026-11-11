// Police au maximum : la fenêtre de détail d'un objet du Marché (étape 4).
// Elle ne dépasse pas la hauteur de l'écran, défile si son contenu est plus
// grand, et ses boutons restent atteignables.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nickel_mobile/catalogue.dart';
import 'package:nickel_mobile/jeu.dart';
import 'package:nickel_mobile/palette.dart';
import 'package:nickel_mobile/widgets_objet.dart';

import 'detecteur_coupure.dart';

void main() {
  setUpAll(chargerRoboto);

  const objet = Objet(id: 'l', type: TypeObjet.avatar, nom: 'Corbeau et chaîne de mestre', rarete: Rarete.legendaire, prix: 600, icone: Icons.pets);
  // Le texte le plus long que la fenêtre affiche (objet offert à qui complète la collection).
  const commentaire = 'Cet objet ne s\'achète pas : il est offert à qui complète la collection « Hiver des dragons » (tous ses objets achetables).';
  const hauteurEcran = 800.0; // téléphone 400 x 800 : à 800 x 1280 la fenêtre tient encore à x2.0 et ne reproduit pas le défaut

  for (final echelle in [1.0, 1.5, 2.0]) {
    testWidgets('fenêtre d\'objet : tient dans l\'écran et boutons atteignables à police x$echelle', (tester) async {
      tester.view.physicalSize = const Size(400, hauteurEcran);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final maintenant = DateTime(2027, 2, 3);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(echelle)), child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Palette.papier,
                builder: (c) => FicheObjet(
                  objet: objet,
                  couleur: Colors.teal,
                  commentObtenir: commentaire,
                  bouton: BoutonObjet(objet: objet, etat: EtatObjet.achetable, solde: 900, maintenant: maintenant, nomSucces: ''),
                  actionSecondaire: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.star_border),
                    label: const Text('En faire mon objectif', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      // Aucune erreur de débordement ni texte coupé.
      expect(coupures(tester), isEmpty);

      // La fenêtre ne dépasse pas l'écran.
      final fiche = tester.getRect(find.byType(FicheObjet));
      expect(fiche.top, greaterThanOrEqualTo(0));
      expect(fiche.bottom, lessThanOrEqualTo(hauteurEcran));

      // Les boutons sont atteignables : visibles, ou en faisant défiler.
      final defilement = find.descendant(of: find.byType(FicheObjet), matching: find.byType(Scrollable));
      for (final bouton in [find.byType(ElevatedButton), find.text('En faire mon objectif')]) {
        expect(bouton, findsWidgets);
        if (defilement.evaluate().isNotEmpty) {
          await tester.ensureVisible(bouton.first);
          await tester.pumpAndSettle();
        }
        final zone = tester.getRect(bouton.first);
        expect(zone.bottom, lessThanOrEqualTo(fiche.bottom + 0.5), reason: 'bouton hors de la fenêtre');
        expect(zone.bottom, lessThanOrEqualTo(hauteurEcran), reason: 'bouton hors de l\'écran');
        expect(zone.top, greaterThanOrEqualTo(fiche.top - 0.5));
      }
    });
  }
}
