// NICKEL — catalogue d'objets de personnalisation (§ 27).
//
// Un « objet » est un avatar ou une couverture. Le kit gratuit ci-dessous est
// embarqué dans l'app et disponible dès le premier jour, sans emoji : des
// pictogrammes simples et des fonds unis. Les objets de la boutique et des
// saisons (images) suivront le même modèle, lus depuis `catalogue.json`.

import 'package:flutter/material.dart';

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
  });

  /// Lu depuis une entrée de `catalogue.json` (objets à image).
  factory Objet.depuisJson(Map<String, dynamic> j) => Objet(
        id: j['id'] as String,
        type: j['type'] == 'couverture' ? TypeObjet.couverture : TypeObjet.avatar,
        nom: j['nom'] as String,
        rarete: Rarete.values.firstWhere((r) => r.name == j['rarete'], orElse: () => Rarete.commun),
        prix: (j['prix'] as int?) ?? 0,
        image: j['image'] as String?,
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
Objet avatarPourId(String? id) => kitAvatars.firstWhere((a) => a.id == id, orElse: () => kitAvatars.first);

Objet couverturePourId(String? id) => kitCouvertures.firstWhere((c) => c.id == id, orElse: () => kitCouvertures.first);

/// Fond d'une couverture : image si l'objet en a une, sinon couleur unie ou
/// dégradé.
BoxDecoration decorationCouverture(Objet c) {
  if (c.image != null) {
    return BoxDecoration(image: DecorationImage(image: NetworkImage(c.image!), fit: BoxFit.cover));
  }
  final couleurs = c.couleurs ?? const [Color(0xFF16150F)];
  if (couleurs.length == 1) return BoxDecoration(color: couleurs.first);
  return BoxDecoration(gradient: LinearGradient(colors: couleurs, begin: Alignment.topLeft, end: Alignment.bottomRight));
}
