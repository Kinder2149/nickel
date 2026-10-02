import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nickel_mobile/catalogue.dart';
import 'package:nickel_mobile/catalogue_distant.dart';
import 'package:nickel_mobile/collections.dart';
import 'package:nickel_mobile/donnees.dart' show ajouterJours;
import 'package:nickel_mobile/jeu.dart';
import 'package:nickel_mobile/quetes.dart';

Map<String, dynamic> r(String par, String date, {int? xp, String tache = 't1', String heure = '12:00:00'}) => {
      'realiseParId': par,
      'dateRealisation': date,
      'tacheId': tache,
      'enregistreLe': '${date}T$heure',
      'xp': ?xp,
    };

void main() {
  test('XP d\'une tâche = sa durée, bornée, 10 par défaut', () {
    expect(xpPourTache({'dureeMinutes': 45}), 45);
    expect(xpPourTache({'dureeMinutes': 2}), 5);
    expect(xpPourTache({'dureeMinutes': 500}), 60);
    expect(xpPourTache({}), 10);
  });

  test('niveaux : seuils 0 / 100 / 300 / 600', () {
    expect(niveauPourXp(0), 1);
    expect(niveauPourXp(99), 1);
    expect(niveauPourXp(100), 2);
    expect(niveauPourXp(299), 2);
    expect(niveauPourXp(300), 3);
    expect(niveauPourXp(600), 4);
    final p = progressionNiveau(150);
    expect(p.dansNiveau, 50);
    expect(p.pourSuivant, 200);
  });

  test('stats : XP, séries, maximum par jour', () {
    final rea = [
      r('val', '2026-10-01', xp: 20),
      r('val', '2026-10-01', xp: 10),
      r('val', '2026-09-30'),
      r('val', '2026-09-29', heure: '06:30:00'),
      r('val', '2026-09-20', heure: '23:10:00'),
      r('sam', '2026-10-01', xp: 99),
    ];
    final s = calculerStats('val', rea, [], aujourdhui: '2026-10-01');
    expect(s.xp, 20 + 10 + 10 + 10 + 10);
    expect(s.taches, 5);
    expect(s.serie, 3);
    expect(s.meilleureSerie, 3);
    expect(s.maxParJour, 2);
    expect(s.semaine, 4);
    expect(s.leveTot, true);
    expect(s.coucheTard, true);
  });

  test('la série ne casse pas tant que la journée n\'est pas finie', () {
    final rea = [r('val', '2026-09-30'), r('val', '2026-09-29')];
    expect(calculerStats('val', rea, [], aujourdhui: '2026-10-01').serie, 2);
    expect(calculerStats('val', rea, [], aujourdhui: '2026-10-02').serie, 0);
  });

  test('succès et contexte de maison', () {
    final membres = [
      {'id': 'val'},
      {'id': 'sam'},
    ];
    final rea = [r('val', '2026-10-01', xp: 30), r('sam', '2026-09-30', xp: 12)];
    final ctx = contexteMaison(membres, rea, [], aujourdhui: '2026-10-01');
    expect(ctx.toutLeMondeActif, true);
    expect(ctx.xpMaison, 42);
    final s = calculerStats('val', rea, [], aujourdhui: '2026-10-01');
    final ok = succesDebloques(s, ctx);
    expect(ok, containsAll(['premiere', 'equipe']));
    expect(ok.contains('cent'), false);
    expect(badgesAffiches(['premiere', 'cent', 'equipe', 'x'], ok), ['premiere', 'equipe']);
  });

  test('week-end, jours actifs et progression des succès', () {
    // 2026-10-03 est un samedi, 2026-10-04 un dimanche.
    final rea = [r('val', '2026-10-03'), r('val', '2026-10-04'), r('val', '2026-10-05')];
    final s = calculerStats('val', rea, [], aujourdhui: '2026-10-05');
    expect(s.weekend, 2);
    expect(s.joursActifs, 3);
    final ctx = contexteMaison([{'id': 'val'}], rea, [], aujourdhui: '2026-10-05');
    final dix = succes.firstWhere((x) => x.id == 'dix');
    expect(dix.valeur(s, ctx), 3);
    expect(dix.debloque(s, ctx), false);
    expect(succes.firstWhere((x) => x.id == 'serie3').debloque(s, ctx), true);
    expect(succes.map((x) => x.id).toSet().length, succes.length, reason: 'ids uniques');
  });

  test('catalogue : un id inconnu (ancien emoji) retombe sur le défaut', () {
    expect(avatarPourId('🐱').id, 'initiale');
    expect(avatarPourId(null).id, 'initiale');
    expect(avatarPourId('balai').icone, isNotNull);
    expect(couverturePourId('nuit').id, 'encre');
    expect(couverturePourId('foret').id, 'foret');
  });

  test('catalogue : lecture d un objet à image depuis le JSON', () {
    final o = Objet.depuisJson({'id': 'x', 'type': 'avatar', 'nom': 'Dragon', 'rarete': 'epique', 'prix': 250, 'image': 'a.png'});
    expect(o.rarete, Rarete.epique);
    expect(o.prix, 250);
    expect(o.image, 'a.png');
    expect(kitAvatars.every((a) => a.prix == 0), true);
  });

  test('Bulles : gains par niveaux et succès, achats, solde, exclusifs', () {
    expect(bullesNiveau(2), 30);
    expect(bullesNiveau(10), 70);
    expect(bullesSucces(Rarete.legendaire), 100);

    // 300 XP = niveau 3 (30 + 35 = 65 Bulles de niveau) + succès débloqués.
    final rea = [for (var i = 0; i < 30; i++) r('val', '2026-09-${(i % 28 + 1).toString().padLeft(2, '0')}', xp: 10)];
    final s = calculerStats('val', rea, [], aujourdhui: '2026-10-01');
    expect(s.niveau, 3);
    final ctx = contexteMaison([{'id': 'val'}], rea, [], aujourdhui: '2026-10-01');
    final ok = succesDebloques(s, ctx);
    final gagnees = bullesGagnees(s, ok);
    expect(gagnees, 65 + ok.fold<int>(0, (a, id) => a + bullesSucces(succes.firstWhere((x) => x.id == id).rarete)));

    expect(soldeBulles(500, ['casque', 'boussole']), 500 - 40 - 100);
    expect(soldeBulles(10, ['trone']), 0, reason: 'jamais négatif');
    expect(soldeBulles(500, ['trophee']), 500, reason: 'un exclusif ne se paie pas');

    final avatarsPossedes = objetsPossedes(TypeObjet.avatar, ['casque'], {'serie7'}).map((o) => o.id);
    expect(avatarsPossedes, containsAll(['initiale', 'casque', 'foudre']));
    expect(avatarsPossedes.contains('trone'), false);
    expect(avatarsPossedes.contains('diamant'), false);
    expect(tousLesObjets.map((o) => o.id).toSet().length, tousLesObjets.length, reason: 'ids uniques');
    expect(boutique.every((o) => o.succesRequis == null || succes.any((x) => x.id == o.succesRequis)), true);
  });

  test('catalogue distant : lecture, saisons, objets mal formés', () {
    const json = '''
    {"saisons":[{"id":"a","nom":"A","theme":"t","debut":"2026-10-01","mois":[10,11,12]},{"nom":"sans id"}],
     "objets":[
       {"id":"x","type":"avatar","nom":"X","rarete":"rare","prix":100,"image":"a/x.png","saison":"a"},
       {"id":"y","type":"couverture","nom":"Y","couleurs":["#112233","#445566"],"saison":"a"},
       {"type":"avatar"}
     ]}''';
    final c = lireCatalogue(json, base: 'https://h/');
    expect(c.saisons.map((s) => s.id), ['a']);
    expect(c.objets.map((o) => o.id), ['x', 'y']);
    expect(c.objets.first.image, 'https://h/a/x.png');
    expect(c.objets.last.couleurs!.length, 2);
  });

  test('saison : trimestres qui reviennent chaque année', () {
    const hiver = Saison(id: 'h', nom: 'H', theme: '', debut: '2026-10-01', mois: [10, 11, 12]);
    const large = Saison(id: 'g', nom: 'G', theme: '', debut: '2027-01-01', mois: [1, 2, 3]);
    expect(hiver.enCours(DateTime(2026, 10, 2)), true);
    expect(hiver.enCours(DateTime(2026, 9, 30)), false);
    expect(hiver.enCours(DateTime(2027, 1, 1)), false);
    expect(hiver.enCours(DateTime(2027, 11, 15)), true, reason: 'revient la 2e année');
    expect(large.enCours(DateTime(2026, 11, 1)), false, reason: 'pas encore sortie');
    expect(large.pasEncoreSortie(DateTime(2026, 11, 1)), true);
    expect(large.enCours(DateTime(2027, 2, 10)), true);
    expect(large.enCours(DateTime(2027, 4, 1)), false);
    expect(large.enCours(DateTime(2028, 1, 15)), true);

    expect(hiver.fin(DateTime(2026, 10, 2)), DateTime(2026, 12, 31));
    expect(hiver.joursRestants(DateTime(2026, 12, 30)), 1);
    expect(large.prochainRetour(DateTime(2026, 10, 2)), DateTime(2027, 1, 1));
    expect(large.prochainRetour(DateTime(2027, 4, 15)), DateTime(2028, 1, 1));
    expect(hiver.prochainRetour(DateTime(2027, 1, 5)), DateTime(2027, 10, 1));
    expect(hiver.cleDotation(DateTime(2026, 10, 2)), 'h-2026');
  });

  test('marché : en vente seulement pendant la saison, états des boutons', () {
    saisonsDistantes.value = const [Saison(id: 'h', nom: 'H', theme: '', debut: '2026-10-01', mois: [10, 11, 12])];
    const saisonnier = Objet(id: 's1', type: TypeObjet.avatar, nom: 'S', prix: 100, saison: 'h');
    const permanent = Objet(id: 'p1', type: TypeObjet.avatar, nom: 'P', prix: 40, saison: 'lancement');
    const exclusif = Objet(id: 'e1', type: TypeObjet.avatar, nom: 'E', succesRequis: 'cent');
    final hiverDansLeTemps = DateTime(2026, 11, 3), horsSaison = DateTime(2027, 2, 3);

    expect(estEnVente(saisonnier, hiverDansLeTemps), true);
    expect(estEnVente(saisonnier, horsSaison), false);
    expect(estEnVente(permanent, horsSaison), true, reason: 'permanent = toute l\'année');
    expect(estEnVente(exclusif, hiverDansLeTemps), false);

    EtatObjet etat(Objet o, DateTime d, {int solde = 500, Set<String> possedes = const {}, String? equipe}) =>
        etatObjet(o, possedes: possedes, equipeId: equipe, solde: solde, maintenant: d);
    expect(etat(saisonnier, hiverDansLeTemps), EtatObjet.achetable);
    expect(etat(saisonnier, hiverDansLeTemps, solde: 30), EtatObjet.pasAssez);
    expect(etat(saisonnier, horsSaison), EtatObjet.horsSaison);
    expect(etat(saisonnier, DateTime(2026, 9, 1)), EtatObjet.bientot);
    expect(etat(saisonnier, horsSaison, possedes: {'s1'}), EtatObjet.possede, reason: 'acheté = à soi pour toujours');
    expect(etat(saisonnier, horsSaison, possedes: {'s1'}, equipe: 's1'), EtatObjet.equipe);
    expect(etat(exclusif, hiverDansLeTemps), EtatObjet.exclusif);
    saisonsDistantes.value = const [];
  });

  test('bonus de connexion (2 par jour, +10 à 5 jours dans la semaine) et solde avec bonus', () {
    expect(bonusConnexionJour, 2);
    expect(bonusConnexionSemaine, 10);
    expect(joursPourBonusSemaine, 5);
    expect(soldeBulles(100, ['casque'], bonus: 30), 100 + 30 - 40);
    expect(soldeBulles(0, null, bonus: 12), 12);
  });

  test('quêtes : lundi, tirage déterministe, avancement, quête commune', () {
    expect(lundiDe('2026-10-02'), '2026-09-28'); // vendredi
    expect(lundiDe('2026-10-04'), '2026-09-28'); // dimanche
    expect(lundiDe('2026-10-05'), '2026-10-05'); // lundi
    expect(lundiDe('2027-01-01'), '2026-12-28'); // passage d'année

    final a = quetesDeLaSemaine('2026-09-28'), b = quetesDeLaSemaine('2026-09-28');
    expect(a.map((q) => q.id), b.map((q) => q.id), reason: 'même tirage sur tous les appareils');
    expect(a.map((q) => q.difficulte), [Difficulte.facile, Difficulte.moyenne, Difficulte.difficile]);
    final vues = <String>{};
    var lundi = '2026-09-28';
    for (var i = 0; i < 40; i++) {
      vues.addAll(quetesDeLaSemaine(lundi).map((q) => q.id));
      lundi = ajouterJours(lundi, 7);
    }
    expect(vues.length, greaterThanOrEqualTo(8), reason: 'les quêtes varient d\'une semaine à l\'autre');

    final taches = [
      {'id': 't1', 'pieceId': 'p1'},
      {'id': 't2', 'pieceId': 'p2'},
    ];
    Map<String, dynamic> rea(String par, String date, String tache, {int xp = 10, String heure = '19:00:00'}) =>
        {'realiseParId': par, 'dateRealisation': date, 'tacheId': tache, 'xp': xp, 'enregistreLe': '${date}T$heure'};
    final realisations = [
      rea('val', '2026-09-28', 't1', heure: '08:00:00'),
      rea('val', '2026-09-30', 't2', xp: 30),
      rea('val', '2026-10-02', 't1'),
      rea('sam', '2026-09-29', 't1'),
      rea('val', '2026-09-27', 't1'), // semaine précédente : ne compte pas
    ];
    final s = statsSemaine('val', realisations, taches, '2026-09-28');
    expect((s.taches, s.xp, s.joursActifs, s.pieces, s.avant10h), (3, 50, 3, 2, true));
    final maison = statsSemaine(null, realisations, taches, '2026-09-28');
    expect(maison.taches, 4);

    final lignes = quetesAffichees(
      membreId: 'val', realisations: realisations, taches: taches, nbMembres: 3, dejaReclamees: null, aujourdhui: '2026-10-02');
    expect(lignes.length, 4);
    expect(lignes.last.commune, true);
    expect(lignes.last.objectif, tachesParMembreCommune * 3);
    expect(lignes.last.valeur, 4);
    expect(lignes.every((l) => l.valeur <= l.objectif), true);
    final prete = lignes.first;
    final apres = quetesAffichees(
      membreId: 'val', realisations: realisations, taches: taches, nbMembres: 3, dejaReclamees: [prete.cle], aujourdhui: '2026-10-02');
    expect(apres.first.reclamee, true);
    expect(apres.first.aRecuperer, false);
    expect(recompenseQuete(Difficulte.facile), 5);
    expect(recompenseQuete(Difficulte.difficile), 12);
    expect(nombreARecuperer(lignes), lignes.where((l) => l.terminee).length);
  });

  test('collections : paliers relatifs, crédit unique, exclusif de collection', () {
    const saison = Saison(id: 's', nom: 'S', theme: '', debut: '2026-10-01', mois: [10, 11, 12]);
    Objet o(String id, Rarete r, {String? collection}) => Objet(
        id: id, type: TypeObjet.avatar, nom: id, rarete: r, prix: collection == null ? 40 : 0, icone: Icons.star, saison: 's', collectionRequise: collection);
    final objets = [
      o('c1', Rarete.commun), o('c2', Rarete.commun), o('c3', Rarete.commun),
      o('r1', Rarete.rare), o('r2', Rarete.rare), o('e1', Rarete.epique),
      o('x', Rarete.legendaire, collection: 's'),
    ];
    saisonsDistantes.value = const [saison];
    objetsDistants.value = objets;
    final maintenant = DateTime(2026, 11, 1);

    expect(objetsDeCollection(saison).map((x) => x.id), ['c1', 'c2', 'c3', 'r1', 'r2', 'e1'], reason: 'l\'exclusif ne compte pas dans la collection');
    expect(objets.last.estGratuit, false);
    expect(objets.last.estAchetable, false);
    expect(estEnVente(objets.last, maintenant), false);
    expect(etatObjet(objets.last, possedes: {}, equipeId: null, solde: 999, maintenant: maintenant), EtatObjet.exclusif);

    var e = etatCollection(saison, {'c1', 'c2'});
    expect((e.total, e.possedes), (6, 2));
    expect(e.paliers.map((p) => p.cle), ['s:5', 's:cr', 's:complete']);
    expect(e.paliers.where((p) => p.atteint), isEmpty);
    expect(e.exclusif?.id, 'x');

    final cinq = ['c1', 'c2', 'c3', 'r1', 'r2'];
    e = etatCollection(saison, cinq.toSet());
    expect(e.paliers.where((p) => p.atteint).map((p) => p.cle), ['s:5', 's:cr']);
    expect(paliersACrediter(cinq, null, maintenant).map((p) => p.cle), ['s:5', 's:cr']);
    expect(paliersACrediter(cinq, ['s:5'], maintenant).map((p) => p.cle), ['s:cr'], reason: 'un palier déjà payé ne l\'est jamais deux fois');
    expect(paliersACrediter(cinq, ['s:5', 's:cr'], maintenant), isEmpty);
    expect(paliersACrediter([...cinq, 'e1'], ['s:5', 's:cr'], maintenant).map((p) => p.cle), ['s:complete']);

    final sansExclusif = objetsPossedes(TypeObjet.avatar, cinq, {}, collections: ['s:5']).map((x) => x.id);
    expect(sansExclusif.contains('x'), false);
    final avecExclusif = objetsPossedes(TypeObjet.avatar, [...cinq, 'e1'], {}, collections: ['s:5', 's:cr', 's:complete']).map((x) => x.id);
    expect(avecExclusif.contains('x'), true, reason: 'collection complète = exclusif possédé');
    expect(etatObjet(objets.last, possedes: avecExclusif.toSet(), equipeId: null, solde: 0, maintenant: maintenant), EtatObjet.possede);

    // saison qui n'a pas encore existé : pas de collection affichée
    expect(toutesLesCollections(cinq, DateTime(2026, 9, 1)), isEmpty);
    expect(toutesLesCollections(cinq, maintenant).length, 1);

    // petite saison : pas de palier « 5 objets » ni « communs et rares » en doublon
    objetsDistants.value = [o('a', Rarete.commun), o('b', Rarete.rare), o('c', Rarete.rare), o('d', Rarete.commun)];
    expect(etatCollection(saison, {}).paliers.map((p) => p.cle), ['s:complete']);

    saisonsDistantes.value = const [];
    objetsDistants.value = const [];
  });

  test('marché permanent : saison de 12 mois et objets retirés de la vente', () {
    final classiques = Saison(id: 'classiques', nom: 'C', theme: '', debut: '2026-10-01', mois: List.generate(12, (i) => i + 1));
    const nouveau = Objet(id: 'n1', type: TypeObjet.avatar, nom: 'N', prix: 40, icone: Icons.star, saison: 'classiques');
    saisonsDistantes.value = [classiques];
    objetsDistants.value = const [nouveau];
    final ete = DateTime(2027, 6, 1);

    expect(classiques.permanente, true);
    expect(estEnVente(nouveau, ete), true, reason: 'permanent, toute l annee');
    expect(toutesLesCollections(['n1'], ete), isEmpty, reason: 'pas de collection pour le marché permanent');

    final casque = boutique.firstWhere((o) => o.id == 'casque');
    expect(estEnVente(casque, ete), true);
    idsRetires.value = {'casque'};
    expect(estEnVente(casque, ete), false, reason: 'retiré de la vente par le catalogue');
    expect(casque.estAchetable, true);
    expect(bullesDepensees(['casque']), casque.prix, reason: 'qui a achete ne perd rien, le solde est inchange');
    expect(objetsPossedes(TypeObjet.avatar, ['casque'], {}).map((o) => o.id), contains('casque'), reason: 'et il le garde');

    final lu = lireCatalogue('{"retires":["a","b"],"saisons":[],"objets":[]}');
    expect(lu.retires, {'a', 'b'});
    expect(lireCatalogue('{"saisons":[],"objets":[]}').retires, isEmpty, reason: 'ancien catalogue sans la clé');

    idsRetires.value = const {};
    saisonsDistantes.value = const [];
    objetsDistants.value = const [];
  });
}
