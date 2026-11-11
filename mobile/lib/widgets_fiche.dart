import 'package:flutter/material.dart';

import 'jeu.dart';
import 'palette.dart';

/// Vrai quand l'utilisateur a agrandi la police du téléphone : les blocs de la
/// fiche se réorganisent alors (2 × 2, une colonne, actions regroupées).
bool grandePolice(BuildContext context) => MediaQuery.textScalerOf(context).scale(14) / 14 > 1.3;

/// Barre du haut de la fiche. À police normale : titre et boutons côte à côte.
/// À grande police : les trois actions sont regroupées dans un seul menu pour
/// laisser la place au titre, qui se réduit plutôt que d'être coupé.
AppBar barreFiche(
  BuildContext context, {
  required String titre,
  required bool estMoi,
  required VoidCallback onAide,
  VoidCallback? onMarche,
  VoidCallback? onModifier,
}) {
  final grande = grandePolice(context);
  return AppBar(
    backgroundColor: Palette.papier,
    foregroundColor: Palette.encre,
    elevation: 0,
    title: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(titre, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w900)),
    ),
    actions: grande
        ? [
            PopupMenuButton<int>(
              tooltip: 'Menu du profil',
              onSelected: (i) {
                if (i == 0) onAide();
                if (i == 1) onMarche?.call();
                if (i == 2) onModifier?.call();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 0, child: Text('Comment ça marche ?')),
                if (estMoi) const PopupMenuItem(value: 1, child: Text('Marché')),
                if (estMoi) const PopupMenuItem(value: 2, child: Text('MODIFIER')),
              ],
            ),
          ]
        : [
            IconButton(tooltip: 'Comment ça marche ?', icon: const Icon(Icons.help_outline), onPressed: onAide),
            if (estMoi) IconButton(tooltip: 'Marché', icon: const Icon(Icons.storefront_outlined), onPressed: onMarche),
            if (estMoi)
              TextButton(
                onPressed: onModifier,
                child: const Text('MODIFIER', style: TextStyle(fontWeight: FontWeight.bold, color: Palette.encre)),
              ),
          ],
  );
}

/// Les 4 statistiques : une rangée à police normale, 2 × 2 à grande police.
class StatsFiche extends StatelessWidget {
  const StatsFiche({super.key, required this.taches, required this.semaine, required this.serie, required this.meilleureSerie});

  final int taches;
  final int semaine;
  final int serie;
  final int meilleureSerie;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _stat('$taches', 'Tâches faites'),
      _stat('$semaine', 'Cette semaine'),
      _stat('$serie j', 'Série en cours'),
      _stat('$meilleureSerie j', 'Meilleure série'),
    ];
    if (!grandePolice(context)) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: stats);
    return Column(
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: stats.sublist(0, 2)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: stats.sublist(2)),
      ],
    );
  }

  Widget _stat(String valeur, String libelle) {
    return Expanded(
      child: Column(
        children: [
          Text(valeur, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.encre)),
          const SizedBox(height: 2),
          Text(libelle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Palette.encreDouce)),
        ],
      ),
    );
  }
}

/// Les 3 emplacements de badge : côte à côte, ou l'un sous l'autre à grande police.
class RangeeBadges extends StatelessWidget {
  const RangeeBadges({super.key, required this.badges});

  /// Toujours 3 entrées ; null = emplacement vide.
  final List<Succes?> badges;

  @override
  Widget build(BuildContext context) {
    final cases = [for (final s in badges) _emplacement(s, grandePolice(context))];
    if (!grandePolice(context)) {
      return Row(
        children: [
          for (var i = 0; i < cases.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: cases[i]),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cases.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          cases[i],
        ],
      ],
    );
  }

  Widget _emplacement(Succes? s, bool grande) {
    return Semantics(
      label: s == null ? 'Emplacement de badge vide' : 'Badge ${s.nom}, ${s.rarete.libelle}',
      child: ExcludeSemantics(child: CaseBadge(succes: s, grande: grande)),
    );
  }
}

/// Une case de badge : hauteur minimale (elle grandit avec le texte).
class CaseBadge extends StatelessWidget {
  const CaseBadge({super.key, required this.succes, this.grande = false});

  final Succes? succes;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final s = succes;
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: grande ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Palette.papierClair,
        border: Border.all(color: s != null ? s.rarete.couleur : Palette.trait, width: s != null ? 2.5 : 1.5),
      ),
      alignment: Alignment.center,
      child: s == null
          ? const Text('—', style: TextStyle(fontSize: 22, color: Palette.encreFaible))
          : Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s.icone, size: 30, color: s.rarete.couleur),
                const SizedBox(height: 4),
                Text(s.nom,
                    textAlign: TextAlign.center,
                    maxLines: grande ? null : 2,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Palette.encre)),
              ],
            ),
    );
  }
}

/// Une ligne de la liste des succès (débloqué ou à découvrir).
class LigneSucces extends StatelessWidget {
  const LigneSucces({super.key, required this.succes, required this.valeur, required this.debloque});

  final Succes succes;
  final int valeur;
  final bool debloque;

  @override
  Widget build(BuildContext context) {
    final s = succes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Palette.papierClair,
              border: Border.all(color: debloque ? s.rarete.couleur : Palette.trait, width: debloque ? 2.5 : 1.5),
            ),
            child: ExcludeSemantics(child: Icon(debloque ? s.icone : Icons.lock_outline, size: 24, color: debloque ? s.rarete.couleur : Palette.encreFaible)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(s.nom, style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.encre)),
                    Text(s.rarete.libelle.toUpperCase(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: s.rarete.couleurTexte)),
                  ],
                ),
                Text(s.description, style: const TextStyle(fontSize: 12, color: Palette.encreDouce)),
                if (!debloque && s.objectif > 1) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: valeur / s.objectif,
                          minHeight: 6,
                          color: s.rarete.couleur,
                          backgroundColor: Palette.trait,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$valeur / ${s.objectif}', style: const TextStyle(fontSize: 12, color: Palette.encreDouce)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
