import 'package:flutter_test/flutter_test.dart';
import 'package:nickel_mobile/jeu.dart';

Map<String, dynamic> r(String par, String date, {int? xp, String tache = 't1', String heure = '12:00:00'}) => {
      'realiseParId': par,
      'dateRealisation': date,
      'tacheId': tache,
      'enregistreLe': '${date}T$heure',
      if (xp != null) 'xp': xp,
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
}
