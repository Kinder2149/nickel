// Police au maximum : aucun texte coupé sur le Marché (étape 1 de la réparation).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nickel_mobile/catalogue.dart';
import 'package:nickel_mobile/catalogue_distant.dart';
import 'package:nickel_mobile/collections.dart';
import 'package:nickel_mobile/jeu.dart';
import 'package:nickel_mobile/widgets_collections.dart';
import 'package:nickel_mobile/widgets_objet.dart';

import 'detecteur_coupure.dart';

void main() {
  setUpAll(chargerRoboto);

  const casque = Objet(id: 'casque', type: TypeObjet.avatar, nom: 'Casque', prix: 40, icone: Icons.headphones);
  const long = Objet(id: 'l', type: TypeObjet.avatar, nom: 'Corbeau et chaîne de mestre', rarete: Rarete.legendaire, prix: 600, icone: Icons.pets);
  const couv = Objet(id: 'c', type: TypeObjet.couverture, nom: 'Salle du trône de balais', rarete: Rarete.epique, prix: 250, couleurs: [Color(0xFF1B2A49), Color(0xFF5B6EA8)]);
  const exclusif = Objet(id: 'e', type: TypeObjet.avatar, nom: 'Trophée du champion', rarete: Rarete.legendaire, icone: Icons.emoji_events, succesRequis: 'cinqcents');
  const saisonnier = Objet(id: 's', type: TypeObjet.avatar, nom: 'Silverwing', rarete: Rarete.epique, prix: 250, icone: Icons.pets, saison: 'h');
  const saison = Saison(id: 'h', nom: 'Hiver des dragons', theme: '', debut: '2026-10-01', mois: [10, 11, 12]);

  Widget page(double echelle, Widget enfant) => MaterialApp(
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(echelle)), child: child!),
        home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: enfant)),
      );

  final maintenant = DateTime(2027, 2, 3); // hors saison pour « h »
  Widget carte(Objet o, EtatObjet e, {int solde = 100}) => CarteObjet(
        objet: o,
        couleur: Colors.teal,
        bouton: BoutonObjet(objet: o, etat: e, solde: solde, maintenant: maintenant, nomSucces: 'Légende du ménage'),
      );

  final cas = <String, Widget Function()>{
    'cartes du marché (il manque, prix, exclusif, saison)': () => GrilleObjets(enfants: [
          carte(casque, EtatObjet.achetable),
          carte(long, EtatObjet.pasAssez),
          carte(couv, EtatObjet.possede),
          carte(casque, EtatObjet.equipe),
          carte(exclusif, EtatObjet.exclusif),
          carte(saisonnier, EtatObjet.horsSaison),
          carte(saisonnier, EtatObjet.bientot),
        ]),
    'filtre Tout / Avatars / Couvertures': () => SelecteurFiltre(filtre: FiltreObjets.tout, onChanged: (_) {}),
    'objectif': () => Container(
          color: Colors.black,
          child: BarreObjectif(objet: long, solde: 120, couleur: Colors.teal, maintenant: maintenant, surMarche: true),
        ),
    'cadeau de la saison': () => CadeauSaison(nomSaison: 'Hiver des dragons', dotation: 50, onRecuperer: () {}),
    'carte de collection': () => LigneCollection(
          etat: const EtatCollection(
            saison: saison,
            total: 12,
            possedes: 4,
            paliers: [
              PalierCollection(cle: 'h:5', type: TypePalier.cinqObjets, libelle: '5 objets de la saison', requis: 5, possedes: 4, recompense: 30),
              PalierCollection(cle: 'h:complete', type: TypePalier.complete, libelle: 'Collection complète', requis: 12, possedes: 4, recompense: 100),
            ],
            exclusif: long,
          ),
          credites: const {},
          couleur: Colors.teal,
        ),
  };

  for (final echelle in [1.0, 1.5, 2.0]) {
    for (final e in cas.entries) {
      testWidgets('${e.key} : aucune coupure à police x$echelle', (tester) async {
        saisonsDistantes.value = const [saison];
        addTearDown(() => saisonsDistantes.value = const []);
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(page(echelle, e.value()));
        await tester.pump();
        expect(coupures(tester), isEmpty);
      });
    }
  }
}
