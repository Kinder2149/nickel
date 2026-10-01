import 'package:flutter/material.dart';

import 'donnees.dart';
import 'ecran_accueil.dart';
import 'ecran_astuces.dart';
import 'ecran_equipe.dart';
import 'palette.dart';

/// Les trois portes de l'app (§ 21, § 25) : je fais ce qui est à faire chez
/// moi, je vois où en est l'équipe, ou je cherche une astuce. L'accueil reste la vitrine — les
/// astuces sont un second temps, jamais le premier écran.
class EcranRacine extends StatefulWidget {
  const EcranRacine({super.key, required this.profil, required this.maisonId});

  final Profil profil;
  final String maisonId;

  @override
  State<EcranRacine> createState() => _EcranRacineState();
}

class _EcranRacineState extends State<EcranRacine> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack : revenir sur l'accueil ne recharge pas la maison, et
      // un "Fait" en attente d'annulation n'est pas interrompu par un
      // aller-retour vers les astuces.
      body: IndexedStack(
        index: _onglet,
        children: [
          EcranAccueil(profil: widget.profil, maisonId: widget.maisonId),
          EcranEquipe(profil: widget.profil, maisonId: widget.maisonId),
          const EcranAstuces(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Palette.papierClair,
        indicatorColor: Palette.encre,
        selectedIndex: _onglet,
        onDestinationSelected: (i) => setState(() => _onglet = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Palette.encreDouce),
            selectedIcon: Icon(Icons.home, color: Palette.papier),
            label: 'Maison',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined, color: Palette.encreDouce),
            selectedIcon: Icon(Icons.emoji_events, color: Palette.papier),
            label: 'Équipe',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline, color: Palette.encreDouce),
            selectedIcon: Icon(Icons.lightbulb, color: Palette.papier),
            label: 'Astuces',
          ),
        ],
      ),
    );
  }
}
