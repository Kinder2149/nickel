import 'package:flutter_test/flutter_test.dart';
import 'package:nickel_mobile/catalogue.dart';
import 'package:nickel_mobile/jeu.dart';

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
}
