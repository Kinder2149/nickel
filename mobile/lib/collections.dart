// NICKEL — les collections de saison (§ 30, mission 3).
//
// Posséder les objets d'une saison fait gagner des paliers, et la collection
// complète débloque un objet exclusif. Les paliers sont calculés à partir du
// catalogue (donc automatiques pour chaque nouvelle saison) et sont RELATIFS à
// la taille de la saison. Une fois atteint, un palier est enregistré et payé
// une seule fois : si la saison grossit plus tard, ce qui a été gagné ne se
// perd pas.

import 'catalogue.dart';
import 'catalogue_distant.dart';
import 'jeu.dart';

/// Bulles versées pour chaque palier.
const recompensePalier5 = 30;
const recompensePalierCommunsRares = 80;
const recompensePalierComplete = 200;

enum TypePalier { cinqObjets, communsEtRares, complete }

class PalierCollection {
  const PalierCollection({required this.cle, required this.type, required this.libelle, required this.requis, required this.possedes, required this.recompense});

  /// Clé enregistrée sur la fiche (« saison:5 », « saison:cr », « saison:complete »).
  final String cle;
  final TypePalier type;
  final String libelle;

  /// Objets à posséder pour atteindre le palier.
  final int requis;
  final int possedes;
  final int recompense;

  bool get atteint => possedes >= requis;
}

class EtatCollection {
  const EtatCollection({required this.saison, required this.total, required this.possedes, required this.paliers, required this.exclusif});

  final Saison saison;
  final int total; // objets achetables de la saison
  final int possedes;
  final List<PalierCollection> paliers;

  /// L'objet exclusif offert pour la collection complète, s'il existe.
  final Objet? exclusif;
}

/// Les objets qui comptent dans la collection d'une saison : ceux qui
/// s'achètent (ni les exclusifs de succès, ni celui de la collection).
List<Objet> objetsDeCollection(Saison s) => tousLesObjets.where((o) => o.saison == s.id && o.estAchetable).toList();

/// Clés des paliers déjà atteints par un joueur, toutes saisons confondues,
/// d'après ses achats.
EtatCollection etatCollection(Saison s, Set<String> achatsIds) {
  final objets = objetsDeCollection(s);
  final total = objets.length;
  final possedes = objets.where((o) => achatsIds.contains(o.id)).length;
  final cr = objets.where((o) => o.rarete.index <= Rarete.rare.index).toList();
  final crPossedes = cr.where((o) => achatsIds.contains(o.id)).length;
  final paliers = <PalierCollection>[];
  if (total > 5) {
    paliers.add(PalierCollection(
        cle: '${s.id}:5', type: TypePalier.cinqObjets, libelle: '5 objets', requis: 5, possedes: possedes, recompense: recompensePalier5));
  }
  // « communs et rares » n'a de sens que s'il diffère de la collection complète
  if (cr.isNotEmpty && cr.length < total) {
    paliers.add(PalierCollection(
        cle: '${s.id}:cr',
        type: TypePalier.communsEtRares,
        libelle: 'Tous les communs et rares',
        requis: cr.length,
        possedes: crPossedes,
        recompense: recompensePalierCommunsRares));
  }
  if (total > 0) {
    paliers.add(PalierCollection(
        cle: '${s.id}:complete',
        type: TypePalier.complete,
        libelle: 'Collection complète',
        requis: total,
        possedes: possedes,
        recompense: recompensePalierComplete));
  }
  final exclusif = tousLesObjets.where((o) => o.collectionRequise == s.id).firstOrNull;
  return EtatCollection(saison: s, total: total, possedes: possedes, paliers: paliers, exclusif: exclusif);
}

/// Les collections à afficher : les saisons déjà sorties au moins une fois.
List<EtatCollection> toutesLesCollections(List<dynamic>? achats, DateTime maintenant) {
  final ids = (achats ?? const []).whereType<String>().toSet();
  return [
    for (final s in saisonsDistantes.value)
      if (!s.pasEncoreSortie(maintenant)) etatCollection(s, ids),
  ];
}

/// Paliers atteints mais pas encore crédités (d'après la liste « collections »
/// déjà enregistrée sur la fiche).
List<PalierCollection> paliersACrediter(List<dynamic>? achats, List<dynamic>? deja, DateTime maintenant) {
  final credites = (deja ?? const []).whereType<String>().toSet();
  return [
    for (final c in toutesLesCollections(achats, maintenant))
      for (final p in c.paliers)
        if (p.atteint && !credites.contains(p.cle)) p,
  ];
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
