// Police au maximum : aucun texte coupé sur l'Équipe, les Quêtes et le menu du bas (étape 3).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nickel_mobile/catalogue_distant.dart';
import 'package:nickel_mobile/jeu.dart';
import 'package:nickel_mobile/quetes.dart';
import 'package:nickel_mobile/widgets_equipe.dart';
import 'package:nickel_mobile/widgets_quetes.dart';

import 'detecteur_coupure.dart';

void main() {
  setUpAll(chargerRoboto);

  Widget page(double echelle, Widget Function() corps, {Widget? bas}) => MaterialApp(
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(echelle)), child: child!),
        home: Scaffold(
          body: SingleChildScrollView(padding: const EdgeInsets.all(22), child: corps()),
          bottomNavigationBar: bas,
        ),
      );

  final membre = <String, dynamic>{'prenom': 'Alexandrine', 'couleur': '#2E7D6B', 'achats': <String>[], 'collections': <String>[]};
  const stats = StatsMembre(
      xp: 600, taches: 1280, semaine: 12, serie: 31, meilleureSerie: 31, maxParJour: 5, leveTot: false, coucheTard: false, pieces: 4, weekend: 6, joursActifs: 40);
  final badges = [for (final s in succes.take(3)) s.id];

  LigneQueteDonnees quete({required int valeur, bool reclamee = false, bool commune = false}) => LigneQueteDonnees(
      cle: 'k',
      titre: 'Faire le ménage de toute la maison ensemble',
      sousTitre: commune ? 'Quête commune · difficile' : 'Quête · moyenne',
      recompense: 120,
      valeur: valeur,
      objectif: 5,
      reclamee: reclamee,
      commune: commune);

  final cas = <String, ({Widget Function() corps, Widget? bas})>{
    'carte membre (moi, 3 badges)': (corps: () => CarteMembre(membre: membre, estMoi: true, stats: stats, badges: badges, onTap: () {}), bas: null),
    'carte membre (autre, sans badge)': (corps: () => CarteMembre(membre: membre, estMoi: false, stats: stats, badges: const [], onTap: () {}), bas: null),
    'quête à récupérer': (corps: () => LigneQuete(donnees: quete(valeur: 5), onRecuperer: () {}), bas: null),
    'quête en cours': (corps: () => LigneQuete(donnees: quete(valeur: 2, commune: true), onRecuperer: () {}), bas: null),
    'quête récupérée': (corps: () => LigneQuete(donnees: quete(valeur: 5, reclamee: true), onRecuperer: () {}), bas: null),
    'menu du bas': (corps: () => const SizedBox(), bas: MenuBas(onglet: 1, onChoix: (_) {}, questesPretes: 0)),
  };

  for (final echelle in [1.0, 1.5, 2.0]) {
    for (final e in cas.entries) {
      testWidgets('équipe, ${e.key} : aucune coupure à police x$echelle', (tester) async {
        objetsDistants.value = const [];
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(page(echelle, e.value.corps, bas: e.value.bas));
        await tester.pump();
        // Alerte connue de la barre d'XP existante (libellé d'accessibilité non numérique),
        // sans rapport avec la coupure : écartée ici, signalée dans le bilan.
        final alerte = tester.takeException();
        if (alerte != null && !alerte.toString().contains('Progress bar value')) throw alerte;
        expect(coupures(tester), isEmpty);
      });
    }
  }
}
