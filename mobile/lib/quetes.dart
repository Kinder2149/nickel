// NICKEL — les quêtes de la semaine (§ 30, mission 2).
//
// Chaque semaine (du lundi au dimanche), trois quêtes personnelles — une
// facile, une moyenne, une difficile — et une quête commune à toute la maison.
// Elles sont tirées de façon déterministe à partir de la date du lundi : tous
// les téléphones voient les mêmes quêtes sans serveur. L'avancement se calcule
// à partir des Réalisations (rien à stocker) ; seule la récupération de la
// récompense est enregistrée.

import 'donnees.dart';

enum Difficulte { facile, moyenne, difficile }

int recompenseQuete(Difficulte d) => switch (d) {
      Difficulte.facile => 5,
      Difficulte.moyenne => 8,
      Difficulte.difficile => 12,
    };

String libelleDifficulte(Difficulte d) => switch (d) {
      Difficulte.facile => 'Facile',
      Difficulte.moyenne => 'Moyenne',
      Difficulte.difficile => 'Difficile',
    };

/// Récompense de la quête commune (versée à chaque membre).
const recompenseQueteCommune = 10;

/// Tâches à faire à plusieurs, par membre de la maison, pour la quête commune.
const tachesParMembreCommune = 7;

/// Lundi de la semaine d'une date (« AAAA-MM-JJ »).
String lundiDe(String dateIso) {
  final p = dateIso.split('-').map(int.parse).toList();
  final jour = DateTime(p[0], p[1], p[2]);
  return ajouterJours(dateIso, -(jour.weekday - 1));
}

/// Ce que fait un membre pendant une semaine.
class StatsSemaine {
  const StatsSemaine({required this.taches, required this.xp, required this.joursActifs, required this.pieces, required this.avant10h});

  final int taches;
  final int xp;
  final int joursActifs;
  final int pieces;
  final bool avant10h;
}

StatsSemaine statsSemaine(
  String? membreId,
  List<Map<String, dynamic>> realisations,
  List<Map<String, dynamic>> taches,
  String lundi,
) {
  final dimanche = ajouterJours(lundi, 6);
  final pieceDe = {for (final t in taches) t['id']: t['pieceId']};
  var n = 0, xp = 0;
  var avant10h = false;
  final jours = <String>{};
  final pieces = <Object>{};
  for (final r in realisations) {
    if (membreId != null && r['realiseParId'] != membreId) continue;
    final date = r['dateRealisation'] as String;
    if (date.compareTo(lundi) < 0 || date.compareTo(dimanche) > 0) continue;
    n++;
    xp += (r['xp'] is int) ? r['xp'] as int : 10;
    jours.add(date);
    final piece = pieceDe[r['tacheId']];
    if (piece != null) pieces.add(piece);
    final heure = DateTime.tryParse((r['enregistreLe'] as String?) ?? '')?.hour;
    if (heure != null && heure < 10) avant10h = true;
  }
  return StatsSemaine(taches: n, xp: xp, joursActifs: jours.length, pieces: pieces.length, avant10h: avant10h);
}

class Quete {
  const Quete(this.id, this.titre, this.difficulte, this.objectif, this.valeur);

  final String id;
  final String titre;
  final Difficulte difficulte;
  final int objectif;
  final int Function(StatsSemaine s) valeur;

  int get recompense => recompenseQuete(difficulte);
}

final List<Quete> _faciles = [
  Quete('taches3', 'Faire 3 tâches', Difficulte.facile, 3, (s) => s.taches),
  Quete('jours2', 'Faire une tâche 2 jours différents', Difficulte.facile, 2, (s) => s.joursActifs),
  Quete('matin', 'Faire une tâche avant 10 h', Difficulte.facile, 1, (s) => s.avant10h ? 1 : 0),
  Quete('xp40', 'Gagner 40 XP', Difficulte.facile, 40, (s) => s.xp),
];

final List<Quete> _moyennes = [
  Quete('taches6', 'Faire 6 tâches', Difficulte.moyenne, 6, (s) => s.taches),
  Quete('pieces3', 'Nettoyer 3 pièces différentes', Difficulte.moyenne, 3, (s) => s.pieces),
  Quete('xp90', 'Gagner 90 XP', Difficulte.moyenne, 90, (s) => s.xp),
  Quete('jours4', 'Faire une tâche 4 jours différents', Difficulte.moyenne, 4, (s) => s.joursActifs),
];

final List<Quete> _difficiles = [
  Quete('taches10', 'Faire 10 tâches', Difficulte.difficile, 10, (s) => s.taches),
  Quete('xp160', 'Gagner 160 XP', Difficulte.difficile, 160, (s) => s.xp),
  Quete('pieces5', 'Nettoyer 5 pièces différentes', Difficulte.difficile, 5, (s) => s.pieces),
  Quete('jours6', 'Faire une tâche 6 jours différents', Difficulte.difficile, 6, (s) => s.joursActifs),
];

int _graine(String s) {
  var h = 7;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

/// Les trois quêtes personnelles d'une semaine (identiques sur tous les appareils).
List<Quete> quetesDeLaSemaine(String lundi) => [
      _faciles[_graine('f$lundi') % _faciles.length],
      _moyennes[_graine('m$lundi') % _moyennes.length],
      _difficiles[_graine('d$lundi') % _difficiles.length],
    ];

/// Une ligne à afficher : personnelle ou commune.
class LigneQueteDonnees {
  const LigneQueteDonnees({
    required this.cle,
    required this.titre,
    required this.sousTitre,
    required this.recompense,
    required this.valeur,
    required this.objectif,
    required this.reclamee,
    required this.commune,
  });

  /// Clé enregistrée à la récupération (« lundi:identifiant »).
  final String cle;
  final String titre;
  final String sousTitre;
  final int recompense;
  final int valeur;
  final int objectif;
  final bool reclamee;
  final bool commune;

  bool get terminee => valeur >= objectif;
  bool get aRecuperer => terminee && !reclamee;
}

/// Les quatre lignes de la semaine d'un membre : 3 quêtes + la quête commune.
List<LigneQueteDonnees> quetesAffichees({
  required String membreId,
  required List<Map<String, dynamic>> realisations,
  required List<Map<String, dynamic>> taches,
  required int nbMembres,
  required List<dynamic>? dejaReclamees,
  required String aujourdhui,
}) {
  final lundi = lundiDe(aujourdhui);
  final reclamees = (dejaReclamees ?? const []).whereType<String>().toSet();
  final moi = statsSemaine(membreId, realisations, taches, lundi);
  final maison = statsSemaine(null, realisations, taches, lundi);
  return [
    for (final q in quetesDeLaSemaine(lundi))
      LigneQueteDonnees(
        cle: '$lundi:${q.id}',
        titre: q.titre,
        sousTitre: libelleDifficulte(q.difficulte),
        recompense: q.recompense,
        valeur: q.valeur(moi).clamp(0, q.objectif),
        objectif: q.objectif,
        reclamee: reclamees.contains('$lundi:${q.id}'),
        commune: false,
      ),
    LigneQueteDonnees(
      cle: '$lundi:commune',
      titre: 'À ${nbMembres > 1 ? 'plusieurs' : 'vous seul'} : ${tachesParMembreCommune * nbMembres} tâches pour la maison',
      sousTitre: 'Quête commune',
      recompense: recompenseQueteCommune,
      valeur: maison.taches.clamp(0, tachesParMembreCommune * nbMembres),
      objectif: tachesParMembreCommune * nbMembres,
      reclamee: reclamees.contains('$lundi:commune'),
      commune: true,
    ),
  ];
}

/// Nombre de récompenses prêtes à être récupérées (pastille sur l'onglet Équipe).
int nombreARecuperer(List<LigneQueteDonnees> lignes) => lignes.where((l) => l.aRecuperer).length;
