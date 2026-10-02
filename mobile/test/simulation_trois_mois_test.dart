// Simulation de 3 mois d'usage (1er octobre → 31 décembre) par les trois
// habitants, avec les VRAIES fonctions du jeu : XP, niveaux, succès, Bulles,
// bonus de connexion, cadeau de saison, marché et saisons.
//
// Ce n'est pas un test de non-régression au sens strict : il affiche un
// rapport (lancer avec `flutter test test/simulation_trois_mois_test.dart`)
// et vérifie quelques invariants (jamais de solde négatif, rien d'acheté hors
// saison, etc.). Les comportements des joueurs sont inventés, déterministes
// (graine fixe) et volontairement réalistes : tout le monde ne joue pas
// pareil, quelqu'un part en vacances.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nickel_mobile/catalogue.dart';
import 'package:nickel_mobile/catalogue_distant.dart';
import 'package:nickel_mobile/jeu.dart';

String iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Joueur {
  Joueur(this.id, this.profil, {required this.ouverture, required this.effort, required this.visiteMarche, required this.regle, this.absent});

  final String id;
  final String profil;
  final double ouverture; // probabilité d'ouvrir l'app un jour donné
  final double effort; // tâches faites en moyenne un jour d'ouverture
  final double visiteMarche; // probabilité de passer au marché un jour d'ouverture
  final String regle; // « impulsif », « epargnant », « tardif »
  final (int, int)? absent; // jours d'absence (vacances)

  String? derniereConnexion;
  int serie = 0;
  int bullesBonus = 0;
  int bonusConnexionTotal = 0;
  int cadeaux = 0;
  final achats = <String>[];
  final journal = <String>[]; // événements marquants
  final joursMarquants = <int>[]; // jours avec un « wow »
  final joursOuverts = <int>[];
  int niveauVu = 1;
  Set<String> succesVus = {};
  final achatsDetail = <String>[];
  final joursSucces = <String, int>{};
  int? premierAchat;
}

void main() {
  test('3 mois d\'usage : rapport de jeu', () {
    // --- le vrai catalogue publié et les vraies tâches du modèle
    final cat = lireCatalogue(File('../public/catalogue/chez-nous/catalogue.json').readAsStringSync());
    saisonsDistantes.value = cat.saisons;
    objetsDistants.value = cat.objets;

    final modele = jsonDecode(File('assets/modeles/foyer-pilote.json').readAsStringSync()) as Map<String, dynamic>;
    final taches = <Map<String, dynamic>>[];
    var n = 0;
    for (final (pi, piece) in (modele['pieces'] as List).indexed) {
      for (final t in (piece['taches'] as List)) {
        taches.add({'id': 't${n++}', 'pieceId': 'p$pi', 'frequenceJours': t['frequenceJours'], 'dureeMinutes': t['dureeMinutes'], 'echeance': null});
      }
    }

    final alea = Random(42);
    final joueurs = [
      Joueur('val', 'Val (régulier, impulsif)', ouverture: 0.92, effort: 3.0, visiteMarche: 0.25, regle: 'impulsif'),
      Joueur('sam', 'Sam (moyen, épargnant)', ouverture: 0.75, effort: 2.2, visiteMarche: 0.15, regle: 'epargnant'),
      Joueur('yo', 'Yo (irrégulier, vacances j.40-52)', ouverture: 0.55, effort: 1.6, visiteMarche: 0.10, regle: 'tardif', absent: (40, 52)),
    ];
    final membres = [for (final j in joueurs) {'id': j.id}];
    final realisations = <Map<String, dynamic>>[];

    final debut = DateTime(2026, 10, 1);
    const nbJours = 92;
    final xpParJour = <int>[];
    var tachesFaitesParJour = <int>[];

    for (var jour = 0; jour < nbJours; jour++) {
      final date = debut.add(Duration(days: jour));
      final dateIso = iso(date);
      var faitesAujourdhui = 0;

      for (final j in joueurs) {
        final enVacances = j.absent != null && jour >= j.absent!.$1 && jour <= j.absent!.$2;
        if (enVacances || alea.nextDouble() > j.ouverture) continue;
        j.joursOuverts.add(jour);

        // --- bonus de connexion (même règle que l'app)
        final hier = iso(date.subtract(const Duration(days: 1)));
        j.serie = j.derniereConnexion == hier ? j.serie + 1 : 1;
        if (j.derniereConnexion != dateIso) {
          final b = bonusConnexion(j.serie);
          j.bullesBonus += b;
          j.bonusConnexionTotal += b;
          j.derniereConnexion = dateIso;
          if (j.serie % 7 == 0) {
            j.joursMarquants.add(jour);
            j.journal.add('j${jour + 1}: série de ${j.serie} jours (+$b Bulles)');
          }
        }

        // --- tâches du jour : on pioche parmi les tâches échues, les plus en retard d'abord
        final nb = max(0, (j.effort + (alea.nextDouble() * 2 - 1) * 1.2).round());
        final dues = taches.where((t) => t['echeance'] == null || (t['echeance'] as String).compareTo(dateIso) <= 0).toList()
          ..sort((a, b) => ((a['echeance'] as String?) ?? '0').compareTo((b['echeance'] as String?) ?? '0'));
        final choix = <Map<String, dynamic>>[];
        final pool = dues.take(10).toList()..shuffle(alea);
        choix.addAll(pool.take(nb));
        for (final t in choix) {
          final r = alea.nextDouble();
          final heure = r < 0.05 ? 7 : r < 0.30 ? 12 : r < 0.85 ? 19 : 22;
          realisations.add({
            'id': 'r${realisations.length}',
            'tacheId': t['id'],
            'realiseParId': j.id,
            'dateRealisation': dateIso,
            'enregistreLe': '${dateIso}T${heure.toString().padLeft(2, '0')}:10:00',
            'xp': xpPourTache(t),
          });
          final f = t['frequenceJours'] as int;
          t['echeance'] = iso(date.add(Duration(days: f)));
          faitesAujourdhui++;
        }
      }
      tachesFaitesParJour.add(faitesAujourdhui);

      // --- état de chaque joueur après ses actions du jour : événements, marché
      final contexte = contexteMaison(membres, realisations, taches, aujourdhui: dateIso);
      var xpJour = 0;
      for (final j in joueurs) {
        final stats = calculerStats(j.id, realisations, taches, aujourdhui: dateIso);
        final debloques = succesDebloques(stats, contexte);
        if (j.joursOuverts.isNotEmpty && j.joursOuverts.last == jour) {
          xpJour += stats.xp;
          var marquant = false;
          if (stats.niveau > j.niveauVu) {
            j.journal.add('j${jour + 1}: niveau ${stats.niveau} (${titreNiveau(stats.niveau)})');
            j.niveauVu = stats.niveau;
            marquant = true;
          }
          for (final id in debloques.difference(j.succesVus)) {
            final s = succes.firstWhere((x) => x.id == id);
            j.journal.add('j${jour + 1}: succès « ${s.nom} » (${s.rarete.libelle})');
            j.joursSucces[id] = jour + 1;
            marquant = true;
          }
          j.succesVus = debloques;
          if (marquant) j.joursMarquants.add(jour);

          // --- passage au marché
          final visite = marquant ? alea.nextDouble() < 0.6 : alea.nextDouble() < j.visiteMarche;
          final tard = j.regle == 'tardif' && jour < 20;
          if (visite && !tard) {
            final gagnees = bullesGagnees(stats, debloques);
            // cadeau de saison (première visite)
            if (j.cadeaux == 0) {
              j.bullesBonus += dotationSaison;
              j.cadeaux = dotationSaison;
              j.journal.add('j${jour + 1}: cadeau de saison (+$dotationSaison Bulles)');
            }
            final solde = soldeBulles(gagnees, j.achats, bonus: j.bullesBonus);
            final possedes = {
              for (final o in [...objetsPossedes(TypeObjet.avatar, j.achats, debloques), ...objetsPossedes(TypeObjet.couverture, j.achats, debloques)]) o.id
            };
            final enVente = tousLesObjets.where((o) => estEnVente(o, date) && !possedes.contains(o.id) && o.prix <= solde).toList();
            Objet? voulu;
            if (enVente.isNotEmpty) {
              if (j.regle == 'epargnant') {
                final bons = enVente.where((o) => o.rarete.index >= Rarete.rare.index).toList()..sort((a, b) => b.prix - a.prix);
                voulu = bons.isEmpty ? null : bons.first;
              } else if (j.regle == 'impulsif') {
                enVente.sort((a, b) => a.prix != b.prix ? a.prix - b.prix : a.type.index - b.type.index);
                voulu = enVente.first;
              } else {
                enVente.sort((a, b) => b.prix - a.prix);
                voulu = enVente.first;
              }
            }
            if (voulu != null) {
              expect(estEnVente(voulu, date), true, reason: 'jamais d\'achat hors saison');
              j.achats.add(voulu.id);
              j.premierAchat ??= jour + 1;
              j.achatsDetail.add('j${jour + 1}: ${voulu.nom} (${voulu.rarete.libelle}, ${voulu.prix})');
              j.journal.add('j${jour + 1}: ACHAT ${voulu.nom} (${voulu.prix} Bulles)');
              j.joursMarquants.add(jour);
            }
            expect(soldeBulles(gagnees, j.achats, bonus: j.bullesBonus), greaterThanOrEqualTo(0));
          }
        }
      }
      xpParJour.add(xpJour);
    }

    // ------------------------------------------------------------- rapport
    final dateFin = debut.add(const Duration(days: nbJours - 1));
    final contexteFin = contexteMaison(membres, realisations, taches, aujourdhui: iso(dateFin));
    final lignes = StringBuffer();
    void l(String t) => lignes.writeln(t);
    l('');
    l('================ SIMULATION 3 MOIS (1er oct. → 31 déc. 2026) ================');
    l('Tâches faites : ${realisations.length} en $nbJours jours = ${(realisations.length / nbJours).toStringAsFixed(1)} par jour pour la maison '
        '(objectif du modèle : environ 4,1/jour).');
    l('XP de la maison : ${contexteFin.xpMaison} → niveau de la maison ${contexteFin.niveauMaison} (${titreNiveau(contexteFin.niveauMaison)}).');
    var jEquipe = '-';
    l('');
    for (final j in joueurs) {
      final stats = calculerStats(j.id, realisations, taches, aujourdhui: iso(dateFin));
      final debloques = succesDebloques(stats, contexteFin);
      final gagnees = bullesGagnees(stats, debloques);
      final depense = bullesDepensees(j.achats);
      final parNiveau = [for (var k = 2; k <= stats.niveau; k++) bullesNiveau(k)].fold(0, (a, b) => a + b);
      final parSucces = gagnees - parNiveau;
      l('--- ${j.profil}');
      l('  ouvert l\'app ${j.joursOuverts.length}/$nbJours jours · ${stats.taches} tâches · ${stats.xp} XP · niveau ${stats.niveau} (${titreNiveau(stats.niveau)}) · série max ${stats.meilleureSerie} j');
      l('  succès : ${debloques.length}/${succes.length}');
      l('  Bulles gagnées : ${gagnees + j.bullesBonus} = niveaux $parNiveau + succès $parSucces + connexion ${j.bonusConnexionTotal} + cadeau ${j.cadeaux}');
      l('  Bulles dépensées : $depense · solde final : ${soldeBulles(gagnees, j.achats, bonus: j.bullesBonus)} · objets achetés : ${j.achats.length}'
          '${j.premierAchat == null ? ' (aucun !)' : ' · 1er achat au jour ${j.premierAchat}'}');
      final seuils = <int>[2, 3, 4, 5];
      final dateNiveau = <String>[];
      // jour d'atteinte de chaque niveau (relu dans le journal)
      for (final lvl in seuils) {
        final e = j.journal.where((x) => x.contains('niveau $lvl ')).toList();
        dateNiveau.add('niv.$lvl ${e.isEmpty ? '—' : e.first.split(':').first}');
      }
      l('  jalons : ${dateNiveau.join(' · ')}');
      // jours sans événement marquant entre deux jours d'ouverture : plus longue « traversée du désert »
      final marq = (j.joursMarquants.toSet().toList()..sort());
      var maxVide = 0, prec = 0;
      for (final m in [...marq, nbJours - 1]) {
        maxVide = max(maxVide, m - prec);
        prec = m;
      }
      l('  jours « wow » (niveau, succès, achat, série de 7) : ${marq.length} · plus longue période sans rien de marquant : $maxVide jours');
      if (j.achatsDetail.isNotEmpty) l('  achats : ${j.achatsDetail.join(' ; ')}');
      if (j.id == 'val') jEquipe = j.joursSucces['equipe']?.toString() ?? '-';
    }
    l('');
    final catSaison = tousLesObjets.where((o) => o.saison == 'saison-1-hiver').length;
    final tousAchats = [for (final j in joueurs) ...j.achats];
    l('Catalogue en vente à la fin : saison Hiver $catSaison objets + marché permanent '
        '${tousLesObjets.where((o) => !o.estGratuit && saisonPour(o.saison) == null && o.succesRequis == null).length} objets achetables.');
    l('Achats de la maison : ${tousAchats.length} objets, dont ${tousAchats.where((id) => tousLesObjets.firstWhere((o) => o.id == id).saison == 'saison-1-hiver').length} de la saison Hiver.');
    l('Succès « Tous ensemble » (Val) débloqué au jour : $jEquipe');
    final joursSansTache = tachesFaitesParJour.where((t) => t == 0).length;
    l('Jours sans aucune tâche faite dans la maison : $joursSansTache/$nbJours.');
    l('==============================================================================');
    // ignore: avoid_print
    print(lignes);

    // invariants
    expect(realisations.length, greaterThan(100));
    for (final j in joueurs) {
      expect(j.achats.toSet().length, j.achats.length, reason: 'pas d\'achat en double');
    }
  });
}
