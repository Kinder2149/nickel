// Police au maximum : aucun texte coupé sur la fiche (étape 2 de la réparation).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nickel_mobile/catalogue.dart';
import 'package:nickel_mobile/catalogue_distant.dart';
import 'package:nickel_mobile/donnees.dart';
import 'package:nickel_mobile/ecran_fiche.dart';
import 'package:nickel_mobile/jeu.dart';
import 'package:nickel_mobile/widgets_fiche.dart';
import 'package:nickel_mobile/widgets_objet.dart';

import 'detecteur_coupure.dart';

void main() {
  setUpAll(chargerRoboto);

  Widget page(double echelle, {PreferredSizeWidget Function(BuildContext)? barre, required Widget Function() corps}) => MaterialApp(
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(echelle)), child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            appBar: barre?.call(context),
            body: SingleChildScrollView(padding: const EdgeInsets.all(22), child: corps()),
          ),
        ),
      );

  final tous = succes.toList();
  final longs = [...succes]..sort((a, b) => b.nom.length.compareTo(a.nom.length));

  final membre = <String, dynamic>{'prenom': 'Val', 'couleur': '#2E7D6B', 'achats': <String>[], 'collections': <String>[]};
  final debloques = succes.take(6).map((s) => s.id).toSet();
  const long = Objet(id: 'l', type: TypeObjet.avatar, nom: 'Corbeau et chaîne de mestre', rarete: Rarete.legendaire, prix: 600, icone: Icons.pets);

  final cas = <String, ({PreferredSizeWidget Function(BuildContext)? barre, Widget Function() corps})>{
    'titre et actions de la barre': (
      barre: (c) => barreFiche(c, titre: 'Mon profil', estMoi: true, onAide: () {}, onMarche: () {}, onModifier: () {}),
      corps: () => const SizedBox(),
    ),
    'titre de la barre, fiche d\'un autre': (
      barre: (c) => barreFiche(c, titre: 'Alexandrine', estMoi: false, onAide: () {}),
      corps: () => const SizedBox(),
    ),
    'les 4 statistiques': (barre: null, corps: () => const StatsFiche(taches: 128, semaine: 12, serie: 7, meilleureSerie: 31)),
    'les 3 cases de badge': (
      barre: null,
      corps: () => RangeeBadges(badges: [longs[0], longs[1], null]),
    ),
    'les 3 badges pleins': (barre: null, corps: () => RangeeBadges(badges: [longs[2], longs[3], longs[4]])),
    'lignes de succès (tous)': (
      barre: null,
      corps: () => Column(children: [
            for (final s in tous) LigneSucces(succes: s, valeur: 0, debloque: false),
            for (final s in tous) LigneSucces(succes: s, valeur: s.objectif, debloque: true),
          ]),
    ),
    'fenêtre MODIFIER': (
      barre: null,
      corps: () => EditeurProfil(
            maisonId: 'm',
            profil: const Profil(id: 'a', prenom: 'Val', couleur: Colors.teal),
            membre: membre,
            debloques: debloques,
          ),
    ),
    'barre d\'objectif': (
      barre: null,
      corps: () => BarreObjectif(objet: long, solde: 120, couleur: Colors.teal, maintenant: DateTime(2027, 2, 3)),
    ),
  };

  for (final echelle in [1.0, 1.5, 2.0]) {
    for (final e in cas.entries) {
      testWidgets('fiche, ${e.key} : aucune coupure à police x$echelle', (tester) async {
        objetsDistants.value = const [];
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(page(echelle, barre: e.value.barre, corps: e.value.corps));
        await tester.pump();
        expect(coupures(tester), isEmpty);
      });
    }
  }
}
