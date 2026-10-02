// NICKEL — catalogue d'objets de personnalisation (§ 27).
//
// Un « objet » est un avatar ou une couverture. Le kit gratuit ci-dessous est
// embarqué dans l'app et disponible dès le premier jour, sans emoji : des
// pictogrammes simples et des fonds unis. Les objets de la boutique et des
// saisons (images) suivront le même modèle, lus depuis `catalogue.json`.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'catalogue_distant.dart';
import 'donnees.dart';
import 'jeu.dart';

enum TypeObjet { avatar, couverture }

class Objet {
  const Objet({
    required this.id,
    required this.type,
    required this.nom,
    this.rarete = Rarete.commun,
    this.prix = 0,
    this.icone,
    this.couleurs,
    this.image,
    this.succesRequis,
    this.collectionRequise,
    this.saison,
  });

  /// Lu depuis une entrée de `catalogue.json` (objets à image).
  /// `base` est ajoutée devant le chemin de l'image (catalogue distant).
  factory Objet.depuisJson(Map<String, dynamic> j, {String base = ''}) => Objet(
        id: j['id'] as String,
        type: j['type'] == 'couverture' ? TypeObjet.couverture : TypeObjet.avatar,
        nom: j['nom'] as String,
        rarete: Rarete.values.firstWhere((r) => r.name == j['rarete'], orElse: () => Rarete.commun),
        prix: (j['prix'] as int?) ?? 0,
        image: j['image'] == null ? null : '$base${j['image']}',
        couleurs: (j['couleurs'] as List?)?.map((c) => hexVersCouleur(c as String)).toList(),
        succesRequis: j['succesRequis'] as String?,
        collectionRequise: j['collectionRequise'] as String?,
        saison: j['saison'] as String?,
      );

  final String id;
  final TypeObjet type;
  final String nom;
  final Rarete rarete;

  /// En Bulles ; 0 = gratuit (kit de départ).
  final int prix;

  /// Avatar du kit : pictogramme blanc sur la couleur du membre.
  final IconData? icone;

  /// Couverture du kit : une couleur = fond uni, plusieurs = dégradé.
  final List<Color>? couleurs;

  /// Objet de boutique : chemin de l'image dans le catalogue distant.
  final String? image;

  /// Objet exclusif : ne s'achète pas, il se gagne avec ce succès.
  final String? succesRequis;

  /// Objet exclusif de saison : il s'obtient en complétant la collection de
  /// cette saison (identifiant de la saison).
  final String? collectionRequise;

  /// Collection d'origine (ex. « lancement », « saison-1-hiver »).
  final String? saison;

  bool get estGratuit => prix == 0 && succesRequis == null && collectionRequise == null;
  bool get estAchetable => prix > 0 && succesRequis == null && collectionRequise == null;
  bool get estExclusif => succesRequis != null || collectionRequise != null;
}

DateTime _jour(String iso) {
  final p = iso.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// Une saison : une collection en vente pendant certains mois, CHAQUE ANNÉE.
/// Les quatre saisons coupent l'année en trimestres (mois contigus, sans
/// passer le 31 décembre).
class Saison {
  const Saison({required this.id, required this.nom, required this.theme, required this.debut, required this.mois});

  factory Saison.depuisJson(Map<String, dynamic> j) => Saison(
        id: j['id'] as String,
        nom: j['nom'] as String,
        theme: (j['theme'] as String?) ?? '',
        debut: (j['debut'] as String?) ?? '0000-01-01',
        mois: ((j['mois'] as List?) ?? List.generate(12, (i) => i + 1)).cast<int>(),
      );

  final String id;
  final String nom;
  final String theme;

  /// Première sortie (« AAAA-MM-JJ ») : avant, la saison n'existe pas.
  final String debut;

  /// Mois de vente, chaque année (1 = janvier).
  final List<int> mois;

  /// En vente à cette date ? (déjà sortie ET dans ses mois)
  bool enCours(DateTime maintenant) => !maintenant.isBefore(_jour(debut)) && mois.contains(maintenant.month);

  /// Jamais encore sortie.
  bool pasEncoreSortie(DateTime maintenant) => maintenant.isBefore(_jour(debut));

  /// Dernier jour de la vente en cours.
  DateTime fin(DateTime maintenant) => DateTime(maintenant.year, mois.last + 1, 0);

  int joursRestants(DateTime maintenant) =>
      fin(maintenant).difference(DateTime(maintenant.year, maintenant.month, maintenant.day)).inDays;

  /// Premier jour de la prochaine vente (pour une saison hors vente).
  DateTime prochainRetour(DateTime maintenant) {
    final d = _jour(debut);
    final ref = maintenant.isBefore(d) ? DateTime(d.year, d.month, d.day - 1) : DateTime(maintenant.year, maintenant.month, maintenant.day);
    var jour = DateTime(ref.year, ref.month, ref.day + 1);
    for (var i = 0; i < 800; i++) {
      if (mois.contains(jour.month)) return jour;
      jour = DateTime(jour.year, jour.month, jour.day + 1);
    }
    return jour;
  }

  /// Clé du cadeau de saison de l'année en cours (ex. « saison-1-hiver-2026 »).
  String cleDotation(DateTime maintenant) => '$id-${maintenant.year}';
}

/// Saison d'un objet, ou null : objet PERMANENT (kit, boutique de lancement).
Saison? saisonPour(String? id) {
  for (final s in saisonsDistantes.value) {
    if (s.id == id) return s;
  }
  return null;
}

/// À vendre en ce moment ? Un objet saisonnier ne l'est que pendant sa
/// saison ; un objet permanent l'est toujours ; un exclusif ne l'est jamais
/// (il se gagne).
bool estEnVente(Objet o, DateTime maintenant) {
  if (!o.estAchetable) return false;
  final s = saisonPour(o.saison);
  return s == null || s.enCours(maintenant);
}

/// Les états possibles d'un objet pour un joueur : décident du bouton.
enum EtatObjet { equipe, possede, achetable, pasAssez, exclusif, horsSaison, bientot }

EtatObjet etatObjet(
  Objet o, {
  required Set<String> possedes,
  required String? equipeId,
  required int solde,
  required DateTime maintenant,
}) {
  if (possedes.contains(o.id)) return o.id == equipeId ? EtatObjet.equipe : EtatObjet.possede;
  if (o.estExclusif) return EtatObjet.exclusif;
  final s = saisonPour(o.saison);
  if (s != null && !s.enCours(maintenant)) return s.pasEncoreSortie(maintenant) ? EtatObjet.bientot : EtatObjet.horsSaison;
  return solde >= o.prix ? EtatObjet.achetable : EtatObjet.pasAssez;
}

/// Prix de la boutique selon la rareté (en Bulles).
int prixParRarete(Rarete r) => switch (r) {
      Rarete.commun => 40,
      Rarete.rare => 100,
      Rarete.epique => 250,
      Rarete.legendaire => 600,
    };

/// Boutique de lancement — contenu PROVISOIRE (pictogrammes et dégradés) pour
/// faire vivre la boutique avant l'arrivée des visuels des saisons (étapes 3
/// et 4). Le remplacer par `catalogue.json` ne change rien au reste du code.
final boutique = <Objet>[
  // Avatars à acheter
  Objet(id: 'casque', type: TypeObjet.avatar, nom: 'Casque', rarete: Rarete.commun, prix: prixParRarete(Rarete.commun), icone: Icons.headphones, saison: 'lancement'),
  Objet(id: 'disque', type: TypeObjet.avatar, nom: 'Disque', rarete: Rarete.commun, prix: prixParRarete(Rarete.commun), icone: Icons.album, saison: 'lancement'),
  Objet(id: 'robot', type: TypeObjet.avatar, nom: 'Robot', rarete: Rarete.commun, prix: prixParRarete(Rarete.commun), icone: Icons.smart_toy, saison: 'lancement'),
  Objet(id: 'voilier', type: TypeObjet.avatar, nom: 'Voilier', rarete: Rarete.commun, prix: prixParRarete(Rarete.commun), icone: Icons.sailing, saison: 'lancement'),
  Objet(id: 'boussole', type: TypeObjet.avatar, nom: 'Boussole', rarete: Rarete.rare, prix: prixParRarete(Rarete.rare), icone: Icons.explore, saison: 'lancement'),
  Objet(id: 'ancre', type: TypeObjet.avatar, nom: 'Ancre', rarete: Rarete.rare, prix: prixParRarete(Rarete.rare), icone: Icons.anchor, saison: 'lancement'),
  Objet(id: 'circuit', type: TypeObjet.avatar, nom: 'Circuit', rarete: Rarete.rare, prix: prixParRarete(Rarete.rare), icone: Icons.memory, saison: 'lancement'),
  Objet(id: 'platine', type: TypeObjet.avatar, nom: 'Platine', rarete: Rarete.rare, prix: prixParRarete(Rarete.rare), icone: Icons.graphic_eq, saison: 'lancement'),
  Objet(id: 'chateau', type: TypeObjet.avatar, nom: 'Château', rarete: Rarete.epique, prix: prixParRarete(Rarete.epique), icone: Icons.castle, saison: 'lancement'),
  Objet(id: 'galaxie', type: TypeObjet.avatar, nom: 'Galaxie', rarete: Rarete.epique, prix: prixParRarete(Rarete.epique), icone: Icons.auto_awesome, saison: 'lancement'),
  Objet(id: 'trone', type: TypeObjet.avatar, nom: 'Trône de balais', rarete: Rarete.legendaire, prix: prixParRarete(Rarete.legendaire), icone: Icons.chair, saison: 'lancement'),
  // Avatars exclusifs : se gagnent, ne s'achètent pas
  Objet(id: 'trophee', type: TypeObjet.avatar, nom: 'Trophée', rarete: Rarete.legendaire, icone: Icons.emoji_events, succesRequis: 'cinqcents', saison: 'lancement'),
  Objet(id: 'diamant', type: TypeObjet.avatar, nom: 'Diamant', rarete: Rarete.legendaire, icone: Icons.diamond, succesRequis: 'serie30', saison: 'lancement'),
  Objet(id: 'foudre', type: TypeObjet.avatar, nom: 'Foudre', rarete: Rarete.rare, icone: Icons.flash_on, succesRequis: 'serie7', saison: 'lancement'),
  // Couvertures à acheter
  Objet(id: 'aurore', type: TypeObjet.couverture, nom: 'Aurore', rarete: Rarete.commun, prix: prixParRarete(Rarete.commun), couleurs: [Color(0xFFF2A65A), Color(0xFFF6D6A0)], saison: 'lancement'),
  Objet(id: 'ocean', type: TypeObjet.couverture, nom: 'Océan', rarete: Rarete.commun, prix: prixParRarete(Rarete.commun), couleurs: [Color(0xFF5AA9E6), Color(0xFFB5DCF7)], saison: 'lancement'),
  Objet(id: 'neon', type: TypeObjet.couverture, nom: 'Néon', rarete: Rarete.rare, prix: prixParRarete(Rarete.rare), couleurs: [Color(0xFF8A3FC7), Color(0xFF2F6FB5)], saison: 'lancement'),
  Objet(id: 'braise-vive', type: TypeObjet.couverture, nom: 'Braise vive', rarete: Rarete.rare, prix: prixParRarete(Rarete.rare), couleurs: [Color(0xFFB4321F), Color(0xFFF2A65A)], saison: 'lancement'),
  Objet(id: 'nuit-etoilee', type: TypeObjet.couverture, nom: 'Nuit étoilée', rarete: Rarete.epique, prix: prixParRarete(Rarete.epique), couleurs: [Color(0xFF1B2A49), Color(0xFF5B6EA8)], saison: 'lancement'),
  Objet(id: 'or', type: TypeObjet.couverture, nom: 'Or', rarete: Rarete.legendaire, prix: prixParRarete(Rarete.legendaire), couleurs: [Color(0xFFB8860B), Color(0xFFFFE08A)], saison: 'lancement'),
  // Couverture exclusive
  Objet(id: 'sommet', type: TypeObjet.couverture, nom: 'Sommet', rarete: Rarete.legendaire, couleurs: [Color(0xFF16150F), Color(0xFFB8860B)], succesRequis: 'niveau10', saison: 'lancement'),
];

/// Kit + boutique de lancement + objets distants. Un id déjà connu localement
/// n'est jamais écrasé par le catalogue distant.
List<Objet> get tousLesObjets {
  final locaux = <Objet>[...kitAvatars, ...kitCouvertures, ...boutique];
  final ids = locaux.map((o) => o.id).toSet();
  return [...locaux, ...objetsDistants.value.where((o) => !ids.contains(o.id))];
}

/// Ce que possède un membre : le kit gratuit, ses achats, et les exclusifs
/// dont il a débloqué le succès.
List<Objet> objetsPossedes(TypeObjet type, List<dynamic>? achats, Set<String> succesDebloques, {List<dynamic>? collections}) {
  final cles = (collections ?? const []).whereType<String>().toSet();
  final ids = (achats ?? const []).whereType<String>().toSet();
  return tousLesObjets
      .where((o) => o.type == type)
      .where((o) => o.estGratuit || ids.contains(o.id) && o.estAchetable || (o.succesRequis != null && succesDebloques.contains(o.succesRequis)) || (o.collectionRequise != null && cles.contains('${o.collectionRequise}:complete')))
      .toList();
}

int bullesDepensees(List<dynamic>? achats) {
  final ids = (achats ?? const []).whereType<String>().toSet();
  return tousLesObjets.where((o) => o.estAchetable && ids.contains(o.id)).fold(0, (a, o) => a + o.prix);
}

/// Solde = gagné (niveaux, succès) + bonus (connexion, cadeaux de saison) − dépensé (jamais négatif : annuler une tâche peut faire
/// redescendre le gagné sous le dépensé).
int soldeBulles(int gagnees, List<dynamic>? achats, {int bonus = 0}) {
  final solde = gagnees + bonus - bullesDepensees(achats);
  return solde < 0 ? 0 : solde;
}

/// Avatars gratuits. Le premier est le défaut : l'initiale du prénom.
const kitAvatars = <Objet>[
  Objet(id: 'initiale', type: TypeObjet.avatar, nom: 'Initiale'),
  Objet(id: 'balai', type: TypeObjet.avatar, nom: 'Balai', icone: Icons.cleaning_services),
  Objet(id: 'savon', type: TypeObjet.avatar, nom: 'Savon', icone: Icons.soap),
  Objet(id: 'goutte', type: TypeObjet.avatar, nom: 'Goutte', icone: Icons.water_drop),
  Objet(id: 'flamme', type: TypeObjet.avatar, nom: 'Flamme', icone: Icons.local_fire_department),
  Objet(id: 'eclair', type: TypeObjet.avatar, nom: 'Éclair', icone: Icons.bolt),
  Objet(id: 'etoile', type: TypeObjet.avatar, nom: 'Étoile', icone: Icons.star),
  Objet(id: 'feuille', type: TypeObjet.avatar, nom: 'Feuille', icone: Icons.eco),
  Objet(id: 'note', type: TypeObjet.avatar, nom: 'Note', icone: Icons.music_note),
  Objet(id: 'fusee', type: TypeObjet.avatar, nom: 'Fusée', icone: Icons.rocket_launch),
  Objet(id: 'bouclier', type: TypeObjet.avatar, nom: 'Bouclier', icone: Icons.shield),
];

/// Couvertures gratuites : des fonds unis (mêmes couleurs que les profils).
const kitCouvertures = <Objet>[
  Objet(id: 'encre', type: TypeObjet.couverture, nom: 'Encre', couleurs: [Color(0xFF16150F)]),
  Objet(id: 'aube', type: TypeObjet.couverture, nom: 'Orange', couleurs: [Color(0xFFF2A65A)]),
  Objet(id: 'ciel', type: TypeObjet.couverture, nom: 'Bleu', couleurs: [Color(0xFF5AA9E6)]),
  Objet(id: 'foret', type: TypeObjet.couverture, nom: 'Vert', couleurs: [Color(0xFF2E6B4E)]),
  Objet(id: 'orchidee', type: TypeObjet.couverture, nom: 'Violet', couleurs: [Color(0xFFC77DFF)]),
  Objet(id: 'braise', type: TypeObjet.couverture, nom: 'Rouge', couleurs: [Color(0xFFB4321F)]),
];

/// L'avatar d'un id. Un id inconnu (ancien emoji, objet retiré) donne
/// l'initiale : un profil ne peut jamais se retrouver sans avatar.
Objet avatarPourId(String? id) =>
    tousLesObjets.firstWhere((a) => a.type == TypeObjet.avatar && a.id == id, orElse: () => kitAvatars.first);

Objet couverturePourId(String? id) =>
    tousLesObjets.firstWhere((c) => c.type == TypeObjet.couverture && c.id == id, orElse: () => kitCouvertures.first);

/// Fond d'une couverture : image si l'objet en a une, sinon couleur unie ou
/// dégradé.
BoxDecoration decorationCouverture(Objet c) {
  if (c.image != null) {
    return BoxDecoration(image: DecorationImage(image: CachedNetworkImageProvider(c.image!), fit: BoxFit.cover));
  }
  final couleurs = c.couleurs ?? const [Color(0xFF16150F)];
  if (couleurs.length == 1) return BoxDecoration(color: couleurs.first);
  return BoxDecoration(gradient: LinearGradient(colors: couleurs, begin: Alignment.topLeft, end: Alignment.bottomRight));
}
