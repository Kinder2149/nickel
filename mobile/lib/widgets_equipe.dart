import 'package:flutter/material.dart';

import 'ecran_fiche.dart';
import 'jeu.dart';
import 'palette.dart';
import 'widgets_fiche.dart';

/// Carte d'un membre dans l'onglet « Équipe » : pastille, nom, niveau, badges,
/// barre d'XP et les 3 chiffres. Sans Firebase : tout arrive en paramètres.
class CarteMembre extends StatelessWidget {
  const CarteMembre({
    super.key,
    required this.membre,
    required this.estMoi,
    required this.stats,
    required this.badges,
    required this.onTap,
  });

  final Map<String, dynamic> membre;
  final bool estMoi;
  final StatsMembre stats;
  final List<String> badges;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grande = grandePolice(context);
    final chiffres = [
      _chiffre('${stats.semaine}', 'cette semaine'),
      _chiffre('${stats.taches}', 'au total'),
      _chiffre('${stats.serie} j', 'de série'),
    ];
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Palette.papierClair, border: Border.all(color: Palette.trait, width: 1.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PastilleMembre(membre: membre, taille: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(estMoi ? '${membre['prenom']} (vous)' : membre['prenom'] as String,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Palette.encre)),
                      Text('Niveau ${stats.niveau} · ${titreNiveau(stats.niveau)}',
                          style: const TextStyle(fontSize: 12, color: Palette.encreDouce)),
                    ],
                  ),
                ),
                // À grande police, les badges passent sous le nom (pas de place à côté).
                if (!grande)
                  for (final b in badges) _icone(b),
                const Icon(Icons.chevron_right, color: Palette.encreFaible),
              ],
            ),
            if (grande && badges.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(children: [for (final b in badges) _icone(b)])),
            const SizedBox(height: 10),
            BarreXp(xp: stats.xp),
            const SizedBox(height: 10),
            // À grande police, les 3 chiffres s'empilent au lieu de se partager la ligne.
            if (grande)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final c in chiffres) Padding(padding: const EdgeInsets.only(bottom: 4), child: c)])
            else
              Row(children: [for (final c in chiffres) Expanded(child: c)]),
          ],
        ),
      ),
    );
  }

  Widget _icone(String b) {
    final s = succes.firstWhere((s) => s.id == b);
    return Padding(padding: const EdgeInsets.only(left: 4), child: Icon(s.icone, size: 22, color: s.rarete.couleur));
  }

  Widget _chiffre(String valeur, String libelle) => Row(
        children: [
          Text(valeur, style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.encre)),
          const SizedBox(width: 4),
          Flexible(child: Text(libelle, style: const TextStyle(fontSize: 12, color: Palette.encreDouce))),
        ],
      );
}

/// Menu du bas (Maison, Équipe, Astuces) : mis en widget pour être testé.
class MenuBas extends StatelessWidget {
  const MenuBas({super.key, required this.onglet, required this.onChoix, required this.questesPretes});

  final int onglet;
  final ValueChanged<int> onChoix;
  final int questesPretes;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      backgroundColor: Palette.papierClair,
      indicatorColor: Palette.encre,
      selectedIndex: onglet,
      onDestinationSelected: onChoix,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined, color: Palette.encreDouce),
          selectedIcon: Icon(Icons.home, color: Palette.papier),
          label: 'Maison',
        ),
        NavigationDestination(
          icon: Badge(isLabelVisible: questesPretes > 0, label: Text('$questesPretes'), child: const Icon(Icons.emoji_events_outlined, color: Palette.encreDouce)),
          selectedIcon: Badge(isLabelVisible: questesPretes > 0, label: Text('$questesPretes'), child: const Icon(Icons.emoji_events, color: Palette.papier)),
          label: 'Équipe',
        ),
        const NavigationDestination(
          icon: Icon(Icons.lightbulb_outline, color: Palette.encreDouce),
          selectedIcon: Icon(Icons.lightbulb, color: Palette.papier),
          label: 'Astuces',
        ),
      ],
    );
  }
}
