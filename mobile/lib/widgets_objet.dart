// NICKEL — blocs génériques pour afficher un objet (§ 27).
//
// Un seul jeu de blocs sert partout (marché, fiche d'un objet, éditeur de
// profil) : l'aperçu d'un objet selon son type, son étiquette de rareté, et
// le bouton qui dépend de son état (acheter, équiper, hors saison…). Ajouter
// un type d'objet = ajouter un cas dans `ApercuObjet`, rien d'autre.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'catalogue.dart';
import 'jeu.dart';
import 'palette.dart';

const _mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

String dateLongue(DateTime d) => '${d.day == 1 ? '1er' : d.day} ${_mois[d.month - 1]}${d.year != DateTime.now().year ? ' ${d.year}' : ''}';

/// « octobre à décembre » pour une saison.
String plageMois(List<int> mois) =>
    mois.length <= 1 ? _mois[mois.first - 1] : '${_mois[mois.first - 1]} à ${_mois[mois.last - 1]}';

/// Aperçu d'un objet : un rond pour un avatar (sur la couleur du joueur), une
/// bande pour une couverture.
class ApercuObjet extends StatelessWidget {
  const ApercuObjet({super.key, required this.objet, required this.couleur, this.taille = 72});

  final Objet objet;

  /// Couleur du joueur : fond des avatars à pictogramme.
  final Color couleur;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final nature = objet.type == TypeObjet.couverture ? 'Couverture' : 'Avatar';
    return Semantics(
      image: true,
      label: '$nature ${objet.nom}',
      child: ExcludeSemantics(child: _dessin()),
    );
  }

  Widget _dessin() {
    if (objet.type == TypeObjet.couverture) {
      return Container(width: double.infinity, height: taille * 0.9, decoration: decorationCouverture(objet));
    }
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
      child: objet.image != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: objet.image!,
                width: taille,
                height: taille,
                fit: BoxFit.cover,
                errorWidget: (contexte, url, erreur) => Icon(Icons.image_not_supported_outlined, color: Colors.white, size: taille * 0.4),
              ),
            )
          : objet.icone != null
              ? Icon(objet.icone, size: taille * 0.52, color: Colors.white)
              : Text(objet.nom.isEmpty ? '?' : objet.nom.substring(0, 1).toUpperCase(),
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: taille * 0.4)),
    );
  }
}

/// Petite étiquette « COMMUN / RARE / ÉPIQUE / LÉGENDAIRE ».
class EtiquetteRarete extends StatelessWidget {
  const EtiquetteRarete(this.rarete, {super.key});

  final Rarete rarete;

  @override
  Widget build(BuildContext context) => Text(
        rarete.libelle.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: rarete.couleurTexte),
      );
}

/// Le bouton d'un objet, identique partout : son libellé et son action
/// dépendent de l'état.
class BoutonObjet extends StatelessWidget {
  const BoutonObjet({
    super.key,
    required this.objet,
    required this.etat,
    required this.solde,
    required this.maintenant,
    this.onAcheter,
    this.onEquiper,
    this.nomSucces,
  });

  final Objet objet;
  final EtatObjet etat;
  final int solde;
  final DateTime maintenant;
  final VoidCallback? onAcheter;
  final VoidCallback? onEquiper;

  /// Nom du succès à obtenir (état « exclusif »).
  final String? nomSucces;

  Widget _etiquette(String texte, {Color couleur = Palette.encreDouce, IconData? icone}) => Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(border: Border.all(color: Palette.trait, width: 1.5)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[Icon(icone, size: 14, color: couleur), const SizedBox(width: 4)],
            Flexible(child: Text(texte, maxLines: 2, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: couleur))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    switch (etat) {
      case EtatObjet.equipe:
        return _etiquette('ÉQUIPÉ', couleur: Palette.vert, icone: Icons.check);
      case EtatObjet.possede:
        return SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onEquiper,
            style: boutonSecondaire().copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48))),
            child: const Text('ÉQUIPER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
          ),
        );
      case EtatObjet.achetable:
        return SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onAcheter,
            style: boutonPrincipal().copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bubble_chart, size: 16),
                const SizedBox(width: 4),
                Text('${objet.prix}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        );
      case EtatObjet.pasAssez:
        return _etiquette('${objet.prix} · il manque ${objet.prix - solde}', icone: Icons.bubble_chart, couleur: Palette.encreFaible);
      case EtatObjet.exclusif:
        if (objet.collectionRequise != null) {
          final nom = saisonPour(objet.collectionRequise)?.nom ?? 'la saison';
          return _etiquette('Collection « $nom » complète', icone: Icons.lock_outline);
        }
        return _etiquette('Succès : ${nomSucces ?? '?'}', icone: Icons.lock_outline);
      case EtatObjet.horsSaison:
        final s = saisonPour(objet.saison);
        return _etiquette(s == null ? 'Hors saison' : 'Revient le ${dateLongue(s.prochainRetour(maintenant))}', icone: Icons.event_outlined);
      case EtatObjet.bientot:
        final s = saisonPour(objet.saison);
        return _etiquette(s == null ? 'Bientôt' : 'Sort le ${dateLongue(s.prochainRetour(maintenant))}', icone: Icons.event_outlined);
    }
  }
}

/// La carte d'un objet : aperçu, nom, rareté, bouton. Toucher la carte ouvre
/// sa fiche détaillée.
class CarteObjet extends StatelessWidget {
  const CarteObjet({super.key, required this.objet, required this.couleur, required this.bouton, this.onTap, this.estompe = false});

  final Objet objet;
  final Color couleur;
  final Widget bouton;
  final VoidCallback? onTap;
  final bool estompe;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: estompe ? 0.6 : 1,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          container: true,
          label: '${objet.nom}, ${objet.rarete.libelle}${objet.prix > 0 ? ', ${objet.prix} Bulles' : ''}',
          hint: 'Toucher pour voir la fiche',
          child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Palette.papierClair, border: Border.all(color: objet.rarete.couleur, width: 2)),
          child: Column(
            children: [
              Expanded(child: Center(child: ApercuObjet(objet: objet, couleur: couleur))),
              const SizedBox(height: 6),
              Text(objet.nom, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.encre)),
              EtiquetteRarete(objet.rarete),
              const SizedBox(height: 8),
              bouton,
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// Grille d'objets (2 colonnes), à poser dans une liste défilante.
class GrilleObjets extends StatelessWidget {
  const GrilleObjets({super.key, required this.enfants});

  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.62,
      children: enfants,
    );
  }
}

/// L'objet que le joueur vise : aperçu, nom et barre de progression vers son prix.
class BarreObjectif extends StatelessWidget {
  const BarreObjectif({super.key, required this.objet, required this.solde, required this.couleur, required this.maintenant, this.surMarche = false});

  final Objet objet;
  final int solde;
  final Color couleur;
  final DateTime maintenant;

  /// Sur le fond sombre de l'en-tête du marché.
  final bool surMarche;

  @override
  Widget build(BuildContext context) {
    final prix = objet.prix;
    final enVente = estEnVente(objet, maintenant);
    final s = saisonPour(objet.saison);
    final String etat;
    if (!enVente && s != null) {
      etat = 'Revient le ${dateLongue(s.prochainRetour(maintenant))}';
    } else if (solde >= prix) {
      etat = 'Vous pouvez l\'acheter !';
    } else {
      etat = 'Il manque ${prix - solde} Bulles';
    }
    final texte = surMarche ? Palette.papier : Palette.encre;
    final discret = surMarche ? const Color(0xFFD8CFB8) : Palette.encreDouce;
    return Semantics(
      label: 'Mon objectif : ${objet.nom}, $solde sur $prix Bulles. $etat',
      child: ExcludeSemantics(
        child: Row(
          children: [
            ApercuObjet(objet: objet, couleur: couleur, taille: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mon objectif : ${objet.nom}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: texte)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: prix == 0 ? 1 : (solde / prix).clamp(0.0, 1.0),
                    minHeight: 8,
                    color: solde >= prix ? Palette.vert : (surMarche ? Palette.papier : Palette.encre),
                    backgroundColor: surMarche ? const Color(0xFF4A463A) : Palette.trait,
                  ),
                  const SizedBox(height: 3),
                  Text('${solde.clamp(0, prix)} / $prix Bulles · $etat', style: TextStyle(fontSize: 12, color: discret)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fiche détaillée d'un objet (feuille modale).
class FicheObjet extends StatelessWidget {
  const FicheObjet({super.key, required this.objet, required this.couleur, required this.bouton, required this.commentObtenir, this.actionSecondaire});

  final Objet objet;
  final Color couleur;
  final Widget bouton;
  final String commentObtenir;

  /// Sous le bouton principal (ex. définir comme objectif).
  final Widget? actionSecondaire;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: ApercuObjet(objet: objet, couleur: couleur, taille: 150)),
            const SizedBox(height: 14),
            Text(objet.nom, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.encre)),
            Center(child: EtiquetteRarete(objet.rarete)),
            const SizedBox(height: 6),
            Text(objet.type == TypeObjet.avatar ? 'Avatar' : 'Couverture', textAlign: TextAlign.center, style: const TextStyle(color: Palette.encreDouce)),
            const SizedBox(height: 10),
            Text(commentObtenir, textAlign: TextAlign.center, style: const TextStyle(color: Palette.encre)),
            const SizedBox(height: 16),
            bouton,
            if (actionSecondaire != null) ...[const SizedBox(height: 6), actionSecondaire!],
          ],
        ),
      ),
    );
  }
}
