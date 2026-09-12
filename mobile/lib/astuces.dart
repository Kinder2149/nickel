import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Bibliothèque d'astuces ménage — embarquée dans l'app, identique pour
/// toutes les maisons (§ 21). C'est un contenu éditorial, pas des données
/// de foyer : il ne vit donc pas dans Firestore, fonctionne hors connexion
/// et se met à jour avec une nouvelle version de l'app.

enum Fiabilite { solide, limites, mythe }

Fiabilite _lireFiabilite(String? valeur) => switch (valeur) {
      'mythe' => Fiabilite.mythe,
      'limites' => Fiabilite.limites,
      _ => Fiabilite.solide,
    };

extension FiabiliteAffichage on Fiabilite {
  String get libelle => switch (this) {
        Fiabilite.solide => 'Ça marche',
        Fiabilite.limites => 'Marche, avec des limites',
        Fiabilite.mythe => 'Fausse bonne idée',
      };
}

class Astuce {
  Astuce({
    required this.id,
    required this.categorie,
    required this.sujet,
    required this.titre,
    required this.texte,
    required this.fiabilite,
  });

  final String id;
  final String categorie;
  final String sujet;
  final String titre;
  final String texte;
  final Fiabilite fiabilite;

  late final String _titreRecherche = _sansAccent('$titre $sujet');
  late final String _texteRecherche = _sansAccent('$texte $categorie');

  /// 0 = ne correspond pas. Plus le score est haut, plus la correspondance
  /// est pertinente : chercher "vin" doit remonter « tache de vin » avant
  /// les astuces qui parlent de vinaigre — d'où la priorité au mot entier.
  int pertinence(String requeteSansAccent) {
    final motEntier = RegExp('\\b${RegExp.escape(requeteSansAccent)}\\b');
    if (motEntier.hasMatch(_titreRecherche)) return 4;
    if (_titreRecherche.contains(requeteSansAccent)) return 3;
    if (motEntier.hasMatch(_texteRecherche)) return 2;
    if (_texteRecherche.contains(requeteSansAccent)) return 1;
    return 0;
  }
}

class Produit {
  const Produit({required this.nom, required this.famille, required this.sertA, required this.jamaisAvec});
  final String nom;
  final String famille;
  final String sertA;
  final String jamaisAvec;
}

class Recette {
  const Recette({required this.nom, required this.methode});
  final String nom;
  final String methode;
}

class Bibliotheque {
  const Bibliotheque({
    required this.astuces,
    required this.securite,
    required this.methode,
    required this.produits,
    required this.recettes,
  });

  final List<Astuce> astuces;
  final List<String> securite;
  final List<Astuce> methode;
  final List<Produit> produits;
  final List<Recette> recettes;

  List<String> get categories {
    final vues = <String>[];
    for (final a in astuces) {
      if (!vues.contains(a.categorie)) vues.add(a.categorie);
    }
    return vues;
  }
}

String _sansAccent(String texte) {
  const avec = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const sans = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  var resultat = texte.toLowerCase();
  for (var i = 0; i < avec.length; i++) {
    resultat = resultat.replaceAll(avec[i], sans[i]);
  }
  return resultat;
}

String normaliserRecherche(String texte) => _sansAccent(texte.trim());

Bibliotheque? _cache;

Future<Bibliotheque> chargerBibliotheque() async {
  if (_cache != null) return _cache!;

  final brut = jsonDecode(await rootBundle.loadString('assets/astuces/bibliotheque.json')) as Map<String, dynamic>;

  final astuces = <Astuce>[
    for (final a in (brut['astuces'] as List))
      Astuce(
        id: a['id'] as String,
        categorie: a['categorie'] as String,
        sujet: a['sujet'] as String,
        titre: a['titre'] as String,
        texte: a['texte'] as String,
        fiabilite: _lireFiabilite(a['fiabilite'] as String?),
      ),
    // Le détachage et les fausses bonnes idées deviennent des astuces
    // comme les autres : une seule liste, une seule recherche.
    for (final (i, d) in (brut['detachage'] as List).indexed)
      Astuce(
        id: 'D${i + 1}',
        categorie: 'Détachage',
        sujet: d['tache'] as String,
        titre: 'Tache de ${(d['tache'] as String).toLowerCase()}',
        texte: '${d['methode']}\n\nÀ éviter : ${d['eviter']}',
        fiabilite: Fiabilite.solide,
      ),
    for (final (i, m) in (brut['mythes'] as List).indexed)
      Astuce(
        id: 'M${i + 1}',
        categorie: 'Fausses bonnes idées',
        sujet: m['astuce'] as String,
        titre: m['astuce'] as String,
        texte: m['pourquoi'] as String,
        fiabilite: _lireFiabilite(m['fiabilite'] as String?),
      ),
  ];

  _cache = Bibliotheque(
    astuces: astuces,
    securite: [for (final r in (brut['securite'] as List)) r as String],
    methode: [
      for (final (i, m) in (brut['methode'] as List).indexed)
        Astuce(
          id: 'P${i + 1}',
          categorie: 'Méthode',
          sujet: 'Méthode générale',
          titre: m['titre'] as String,
          texte: m['texte'] as String,
          fiabilite: _lireFiabilite(m['fiabilite'] as String?),
        ),
    ],
    produits: [
      for (final p in (brut['produits'] as List))
        Produit(
          nom: p['nom'] as String,
          famille: p['famille'] as String,
          sertA: p['sertA'] as String,
          jamaisAvec: p['jamaisAvec'] as String,
        ),
    ],
    recettes: [
      for (final r in (brut['recettes'] as List)) Recette(nom: r['nom'] as String, methode: r['methode'] as String),
    ],
  );
  return _cache!;
}
