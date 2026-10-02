import 'package:flutter/material.dart';

import 'collections.dart';
import 'palette.dart';
import 'widgets_objet.dart';

/// Une collection de saison : avancement, paliers et objet exclusif offert.
class LigneCollection extends StatelessWidget {
  const LigneCollection({super.key, required this.etat, required this.credites, required this.couleur});

  final EtatCollection etat;

  /// Paliers déjà payés (clés enregistrées sur la fiche).
  final Set<String> credites;

  /// Couleur du joueur (aperçu de l'objet exclusif).
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final e = etat;
    final complete = e.total > 0 && e.possedes >= e.total;
    return Semantics(
      container: true,
      label: 'Collection ${e.saison.nom} : ${e.possedes} objets sur ${e.total}'
          '${e.paliers.map((p) => '. ${p.libelle} : ${p.atteint ? 'atteint' : 'à atteindre'}, ${p.recompense} Bulles').join()}',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Palette.papierClair, border: Border.all(color: complete ? Palette.vert : Palette.trait, width: complete ? 2.5 : 1.5)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Collection ${e.saison.nom}', style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.encre))),
                  Text('${e.possedes} / ${e.total}', style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.encre)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: e.total == 0 ? 0 : e.possedes / e.total,
                minHeight: 8,
                color: complete ? Palette.vert : Palette.encre,
                backgroundColor: Palette.trait,
              ),
              const SizedBox(height: 10),
              for (final p in e.paliers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(p.atteint ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: p.atteint ? Palette.vert : Palette.encreFaible),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${p.libelle}${p.atteint ? '' : ' (${p.possedes} / ${p.requis})'}',
                          style: TextStyle(color: p.atteint ? Palette.encre : Palette.encreDouce, fontWeight: p.atteint ? FontWeight.w700 : FontWeight.w500),
                        ),
                      ),
                      const Icon(Icons.bubble_chart, size: 14, color: Palette.encreDouce),
                      const SizedBox(width: 2),
                      Text('+${p.recompense}', style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.encre)),
                    ],
                  ),
                ),
              if (e.exclusif != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    ApercuObjet(objet: e.exclusif!, couleur: couleur, taille: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        complete ? 'Exclusif débloqué : ${e.exclusif!.nom}' : 'Exclusif offert à la fin : ${e.exclusif!.nom}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: complete ? Palette.vert : Palette.encre),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
