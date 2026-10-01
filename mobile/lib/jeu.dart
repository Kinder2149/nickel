// NICKEL — le jeu : XP, niveaux, statistiques, succès (§ 25).
//
// Logique pure, sans Firebase : tout se calcule à partir des Réalisations
// (qui a fait quoi, quand) et des Tâches. Rien d'autre n'est stocké que le
// profil (nom, avatar, couverture, 3 badges) et l'XP gagné au moment de
// chaque coche.

import 'package:flutter/material.dart';

import 'donnees.dart';

// ------------------------------------------------------------------ XP

/// XP d'une tâche = sa durée en minutes (entre 5 et 60). Une tâche sans
/// durée connue (tâche créée à la main) vaut 10.
int xpPourTache(Map<String, dynamic> tache) {
  final duree = tache['dureeMinutes'];
  final base = duree is int ? duree : 10;
  return base.clamp(5, 60);
}

/// XP à compter pour une Réalisation : celui enregistré au moment de la
/// coche (il survit à une tâche supprimée ou à une durée modifiée), ou 10
/// pour les Réalisations plus anciennes que le jeu.
int xpRealisation(Map<String, dynamic> realisation) {
  final xp = realisation['xp'];
  return xp is int ? xp : 10;
}

/// XP cumulé nécessaire pour ATTEINDRE le niveau n (niveau 1 = 0).
/// Avec l'échelle 50 : niv. 2 = 100, niv. 3 = 300, niv. 4 = 600, niv. 5 = 1000…
int xpPourNiveau(int niveau, {int echelle = 50}) => echelle * niveau * (niveau - 1);

int niveauPourXp(int xp, {int echelle = 50}) {
  var n = 1;
  while (xp >= xpPourNiveau(n + 1, echelle: echelle)) {
    n++;
  }
  return n;
}

/// Progression dans le niveau courant : (xp gagné dans ce niveau, xp à gagner
/// pour passer au suivant).
({int dansNiveau, int pourSuivant}) progressionNiveau(int xp, {int echelle = 50}) {
  final n = niveauPourXp(xp, echelle: echelle);
  final debut = xpPourNiveau(n, echelle: echelle);
  return (dansNiveau: xp - debut, pourSuivant: xpPourNiveau(n + 1, echelle: echelle) - debut);
}

const _titres = [
  'Novice',
  'Apprenti',
  'Habitué',
  'Pro du chiffon',
  'Expert',
  'Maître de maison',
  'Légende',
  'Mythe',
];

String titreNiveau(int niveau) => _titres[(niveau - 1).clamp(0, _titres.length - 1)];

/// La maison monte de niveau avec l'XP de tous (échelle plus large : ils
/// sont plusieurs à en gagner).
const echelleMaison = 150;

// --------------------------------------------------------------- Stats

class StatsMembre {
  const StatsMembre({
    required this.xp,
    required this.taches,
    required this.semaine,
    required this.serie,
    required this.meilleureSerie,
    required this.maxParJour,
    required this.leveTot,
    required this.coucheTard,
    required this.pieces,
    required this.weekend,
    required this.joursActifs,
  });

  final int xp;
  final int taches;
  final int semaine; // tâches faites sur les 7 derniers jours
  final int serie; // jours consécutifs en cours (aujourd'hui ou hier compris)
  final int meilleureSerie;
  final int maxParJour;
  final bool leveTot; // une tâche cochée avant 8 h
  final bool coucheTard; // une tâche cochée à 22 h ou après
  final int pieces; // nombre de pièces différentes nettoyées
  final int weekend; // tâches faites un samedi ou un dimanche
  final int joursActifs; // jours différents où il a fait au moins une tâche

  int get niveau => niveauPourXp(xp);
}

/// Calcule les statistiques d'un membre à partir de toutes les Réalisations
/// de la maison et de ses Tâches.
StatsMembre calculerStats(
  String membreId,
  List<Map<String, dynamic>> realisations,
  List<Map<String, dynamic>> taches, {
  String? aujourdhui,
}) {
  final jourJ = aujourdhui ?? dateAujourdhui();
  final siennes = realisations.where((r) => r['realiseParId'] == membreId).toList();

  final parJour = <String, int>{};
  var xp = 0;
  var semaine = 0;
  var leveTot = false;
  var coucheTard = false;
  var weekend = 0;
  final pieces = <String>{};
  final debutSemaine = ajouterJours(jourJ, -6);

  for (final r in siennes) {
    xp += xpRealisation(r);
    final date = r['dateRealisation'] as String;
    parJour[date] = (parJour[date] ?? 0) + 1;
    if (date.compareTo(debutSemaine) >= 0 && date.compareTo(jourJ) <= 0) semaine++;

    final jourSemaine = _dateDe(date).weekday;
    if (jourSemaine == DateTime.saturday || jourSemaine == DateTime.sunday) weekend++;

    final heure = DateTime.tryParse((r['enregistreLe'] as String?) ?? '')?.hour;
    if (heure != null) {
      if (heure < 8) leveTot = true;
      if (heure >= 22) coucheTard = true;
    }

    for (final t in taches) {
      if (t['id'] == r['tacheId'] && t['pieceId'] != null) pieces.add(t['pieceId'] as String);
    }
  }

  // Série en cours : on compte à rebours depuis aujourd'hui, ou depuis hier
  // si rien n'est encore fait aujourd'hui (la série ne casse qu'à minuit).
  var serie = 0;
  var curseur = parJour.containsKey(jourJ) ? jourJ : ajouterJours(jourJ, -1);
  while (parJour.containsKey(curseur)) {
    serie++;
    curseur = ajouterJours(curseur, -1);
  }

  // Meilleure série jamais atteinte.
  var meilleure = 0;
  for (final jour in parJour.keys) {
    if (parJour.containsKey(ajouterJours(jour, -1))) continue; // pas un début de série
    var longueur = 0;
    var c = jour;
    while (parJour.containsKey(c)) {
      longueur++;
      c = ajouterJours(c, 1);
    }
    if (longueur > meilleure) meilleure = longueur;
  }

  return StatsMembre(
    xp: xp,
    taches: siennes.length,
    semaine: semaine,
    serie: serie,
    meilleureSerie: meilleure,
    maxParJour: parJour.values.fold(0, (a, b) => a > b ? a : b),
    leveTot: leveTot,
    coucheTard: coucheTard,
    pieces: pieces.length,
    weekend: weekend,
    joursActifs: parJour.length,
  );
}

DateTime _dateDe(String dateISO) {
  final p = dateISO.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

// -------------------------------------------------------------- Succès

enum Rarete { commun, rare, epique, legendaire }

extension LibelleRarete on Rarete {
  String get libelle => switch (this) {
        Rarete.commun => 'Commun',
        Rarete.rare => 'Rare',
        Rarete.epique => 'Épique',
        Rarete.legendaire => 'Légendaire',
      };

  Color get couleur => switch (this) {
        Rarete.commun => const Color(0xFF6B675A),
        Rarete.rare => const Color(0xFF2F6FB5),
        Rarete.epique => const Color(0xFF8A3FC7),
        Rarete.legendaire => const Color(0xFFB8860B),
      };
}

/// Un succès se débloque quand `valeur` atteint `objectif` (les succès
/// « oui / non » ont un objectif de 1).
class Succes {
  const Succes(this.id, this.emoji, this.nom, this.description, this.rarete, this.objectif, this.valeur);

  final String id;
  final String emoji;
  final String nom;
  final String description;
  final Rarete rarete;
  final int objectif;
  final int Function(StatsMembre s, ContexteMaison m) valeur;

  bool debloque(StatsMembre s, ContexteMaison m) => valeur(s, m) >= objectif;
}

/// Ce qui se joue à l'échelle de la maison (succès coopératifs).
class ContexteMaison {
  const ContexteMaison({required this.toutLeMondeActif, required this.xpMaison});

  /// Chaque membre a fait au moins une tâche ces 7 derniers jours.
  final bool toutLeMondeActif;
  final int xpMaison;

  int get niveauMaison => niveauPourXp(xpMaison, echelle: echelleMaison);
}

int _oui(bool b) => b ? 1 : 0;

final succes = <Succes>[
  // Volume
  Succes('premiere', '🌱', 'Premier pas', 'Cocher sa première tâche', Rarete.commun, 1, (s, m) => s.taches),
  Succes('dix', '🧽', 'Bien lancé', 'Faire 10 tâches', Rarete.commun, 10, (s, m) => s.taches),
  Succes('vingtcinq', '🧴', 'Dans le rythme', 'Faire 25 tâches', Rarete.commun, 25, (s, m) => s.taches),
  Succes('cinquante', '💪', 'Increvable', 'Faire 50 tâches', Rarete.rare, 50, (s, m) => s.taches),
  Succes('cent', '🏅', 'Centurion', 'Faire 100 tâches', Rarete.rare, 100, (s, m) => s.taches),
  Succes('deuxcents', '🥇', 'Machine de guerre', 'Faire 200 tâches', Rarete.epique, 200, (s, m) => s.taches),
  Succes('cinqcents', '🏆', 'Légende du ménage', 'Faire 500 tâches', Rarete.legendaire, 500, (s, m) => s.taches),
  // Régularité
  Succes('serie3', '🔥', 'Sur la lancée', '3 jours de suite', Rarete.commun, 3, (s, m) => s.meilleureSerie),
  Succes('serie7', '⚡', 'Semaine parfaite', '7 jours de suite', Rarete.rare, 7, (s, m) => s.meilleureSerie),
  Succes('serie14', '🌟', "Quinzaine d'or", '14 jours de suite', Rarete.epique, 14, (s, m) => s.meilleureSerie),
  Succes('serie30', '💎', 'Inarrêtable', '30 jours de suite', Rarete.legendaire, 30, (s, m) => s.meilleureSerie),
  Succes('fidele', '📅', 'Fidèle au poste', 'Faire une tâche pendant 30 jours différents', Rarete.rare, 30, (s, m) => s.joursActifs),
  Succes('semaine5', '🗓️', 'Semaine active', '5 tâches en 7 jours', Rarete.commun, 5, (s, m) => s.semaine),
  Succes('semaine15', '🌪️', 'Semaine de feu', '15 tâches en 7 jours', Rarete.epique, 15, (s, m) => s.semaine),
  // Efforts d'un jour
  Succes('triple', '🎯', 'Triplé', '3 tâches le même jour', Rarete.commun, 3, (s, m) => s.maxParJour),
  Succes('marathon', '🏃', 'Marathon', '5 tâches le même jour', Rarete.rare, 5, (s, m) => s.maxParJour),
  Succes('tornade', '🌀', 'Tornade blanche', '8 tâches le même jour', Rarete.epique, 8, (s, m) => s.maxParJour),
  // Variété et habitudes
  Succes('deuxpieces', '🚪', 'Curieux', 'Des tâches dans 2 pièces différentes', Rarete.commun, 2, (s, m) => s.pieces),
  Succes('toutterrain', '🧭', 'Touche-à-tout', 'Des tâches dans 4 pièces différentes', Rarete.rare, 4, (s, m) => s.pieces),
  Succes('maitrelieux', '🗝️', 'Maître des lieux', 'Des tâches dans 6 pièces différentes', Rarete.epique, 6, (s, m) => s.pieces),
  Succes('tot', '🌅', 'Lève-tôt', 'Cocher une tâche avant 8 h', Rarete.rare, 1, (s, m) => _oui(s.leveTot)),
  Succes('tard', '🦉', 'Oiseau de nuit', 'Cocher une tâche à 22 h ou après', Rarete.rare, 1, (s, m) => _oui(s.coucheTard)),
  Succes('weekend', '☀️', 'Week-end productif', 'Faire 5 tâches un samedi ou un dimanche', Rarete.commun, 5, (s, m) => s.weekend),
  // Niveaux
  Succes('niveau3', '🥉', 'Habitué', 'Atteindre le niveau 3', Rarete.commun, 3, (s, m) => s.niveau),
  Succes('niveau5', '🥈', 'Expert', 'Atteindre le niveau 5', Rarete.rare, 5, (s, m) => s.niveau),
  Succes('niveau8', '🎖️', 'Légende', 'Atteindre le niveau 8', Rarete.epique, 8, (s, m) => s.niveau),
  Succes('niveau10', '👑', 'Au sommet', 'Atteindre le niveau 10', Rarete.legendaire, 10, (s, m) => s.niveau),
  // Coopération
  Succes('equipe', '🤝', 'Tous ensemble', 'Toute la maison a fait une tâche cette semaine (vous aussi)', Rarete.rare, 1,
      (s, m) => _oui(m.toutLeMondeActif && s.semaine >= 1)),
  Succes('maison3', '🏡', 'Maison en forme', 'La maison atteint le niveau 3', Rarete.commun, 3, (s, m) => m.niveauMaison),
  Succes('maison5', '🏰', 'Maison de rêve', 'La maison atteint le niveau 5', Rarete.epique, 5, (s, m) => m.niveauMaison),
];

// ---------------------------------------------- Personnalisation (profil)

/// Avatars : un emoji, à débloquer avec le niveau. Le premier est le défaut.
class Avatar {
  const Avatar(this.emoji, this.niveauRequis);
  final String emoji;
  final int niveauRequis;
}

const avatars = [
  Avatar('🙂', 1), Avatar('🐱', 1), Avatar('🐶', 1), Avatar('🦊', 1), Avatar('🐼', 1), Avatar('🐸', 1),
  Avatar('🐰', 2), Avatar('🦁', 2), Avatar('🐯', 2), Avatar('🐨', 2),
  Avatar('🦄', 3), Avatar('🐙', 3), Avatar('🦉', 3), Avatar('🐧', 3),
  Avatar('🤖', 5), Avatar('👽', 5), Avatar('🧙', 5), Avatar('🐲', 5),
  Avatar('🦸', 7), Avatar('👑', 7),
];

/// Images de couverture : des dégradés dessinés dans l'app (aucune image à
/// télécharger ni à héberger).
class Couverture {
  const Couverture(this.id, this.nom, this.couleurs, this.niveauRequis);
  final String id;
  final String nom;
  final List<Color> couleurs;
  final int niveauRequis;
}

const couvertures = [
  Couverture('encre', 'Encre', [Color(0xFF16150F), Color(0xFF4A463A)], 1),
  Couverture('aube', 'Aube', [Color(0xFFF2A65A), Color(0xFFF6D6A0)], 1),
  Couverture('ciel', 'Ciel', [Color(0xFF5AA9E6), Color(0xFFB5DCF7)], 1),
  Couverture('foret', 'Forêt', [Color(0xFF2E6B4E), Color(0xFF8CC3A2)], 2),
  Couverture('orchidee', 'Orchidée', [Color(0xFFC77DFF), Color(0xFFF0D2FF)], 3),
  Couverture('braise', 'Braise', [Color(0xFFB4321F), Color(0xFFF2A65A)], 4),
  Couverture('nuit', 'Nuit', [Color(0xFF1B2A49), Color(0xFF5B6EA8)], 5),
  Couverture('or', 'Or', [Color(0xFFB8860B), Color(0xFFFFE08A)], 7),
];

Couverture couverturePourId(String? id) =>
    couvertures.firstWhere((c) => c.id == id, orElse: () => couvertures.first);

/// Les 3 badges d'un profil : ids de succès, limités aux débloqués.
List<String> badgesAffiches(List<dynamic>? ids, Set<String> debloques) =>
    (ids ?? const []).whereType<String>().where(debloques.contains).take(3).toList();

Set<String> succesDebloques(StatsMembre s, ContexteMaison m) => {
      for (final x in succes)
        if (x.debloque(s, m)) x.id,
    };

/// Cette maison et ses membres : calcule le contexte coopératif.
ContexteMaison contexteMaison(
  List<Map<String, dynamic>> membres,
  List<Map<String, dynamic>> realisations,
  List<Map<String, dynamic>> taches, {
  String? aujourdhui,
}) {
  final stats = [for (final m in membres) calculerStats(m['id'] as String, realisations, taches, aujourdhui: aujourdhui)];
  return ContexteMaison(
    toutLeMondeActif: stats.isNotEmpty && stats.every((s) => s.semaine >= 1),
    xpMaison: realisations.fold(0, (a, r) => a + xpRealisation(r)),
  );
}
