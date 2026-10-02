import 'package:flutter/material.dart';

import 'palette.dart';
import 'quetes.dart';

/// Une ligne de quête : titre, difficulté, barre d'avancement, récompense, et
/// le bouton « RÉCUPÉRER » quand elle est terminée.
class LigneQuete extends StatelessWidget {
  const LigneQuete({super.key, required this.donnees, required this.onRecuperer});

  final LigneQueteDonnees donnees;
  final VoidCallback onRecuperer;

  @override
  Widget build(BuildContext context) {
    final d = donnees;
    final couleur = d.commune ? Palette.vert : Palette.encre;
    return Semantics(
      container: true,
      label: '${d.commune ? 'Quête commune' : 'Quête'} : ${d.titre}, ${d.valeur} sur ${d.objectif}, récompense ${d.recompense} Bulles'
          '${d.reclamee ? ', récupérée' : d.terminee ? ', terminée, à récupérer' : ''}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Palette.papierClair,
          border: Border.all(color: d.aRecuperer ? Palette.vert : Palette.trait, width: d.aRecuperer ? 2.5 : 1.5),
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.sousTitre.toUpperCase(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: couleur == Palette.encre ? Palette.encreDouce : couleur)),
                        const SizedBox(height: 2),
                        Text(d.titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Palette.encre)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bubble_chart, size: 16, color: Palette.encreDouce),
                      const SizedBox(width: 3),
                      Text('+${d.recompense}', style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.encre)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (d.reclamee)
                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Palette.vert),
                    SizedBox(width: 6),
                    Text('Récupérée', style: TextStyle(fontWeight: FontWeight.w700, color: Palette.vert)),
                  ],
                )
              else if (d.terminee)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onRecuperer,
                    style: boutonPrincipal().copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48))),
                    child: Text('RÉCUPÉRER +${d.recompense} BULLES', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: d.objectif == 0 ? 0 : d.valeur / d.objectif,
                        minHeight: 8,
                        color: couleur,
                        backgroundColor: Palette.trait,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${d.valeur} / ${d.objectif}', style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.encreDouce)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
