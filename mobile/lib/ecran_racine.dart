import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalogue_distant.dart';
import 'donnees.dart';
import 'ecran_accueil.dart';
import 'ecran_astuces.dart';
import 'ecran_equipe.dart';
import 'jeu.dart';
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

  // Suivi de progression : on compare ce que l'on vient de calculer à ce que
  // l'on avait déjà « vu » sur cet appareil, pour fêter un nouveau niveau ou
  // un nouveau succès (§ 25). La première fois, on enregistre sans fêter :
  // sinon l'historique d'avant le jeu déclencherait une avalanche.
  List<Map<String, dynamic>> _membres = [];
  List<Map<String, dynamic>> _taches = [];
  List<Map<String, dynamic>> _realisations = [];
  final _recus = <String>{};
  final _abonnements = <StreamSubscription>[];
  bool _celebrationOuverte = false;
  bool _bonusDemande = false;

  String get _cleVu => 'nickel-vu-${widget.maisonId}-${widget.profil.id}';

  @override
  void initState() {
    super.initState();
    chargerCatalogue(); // nouveautés de la boutique (n'attend pas, ne bloque rien)
    _abonnements.add(ecouterMembres(widget.maisonId).listen((m) {
      _membres = m;
      _recus.add('membres');
      _bonusConnexion();
      _verifierProgression();
    }));
    _abonnements.add(ecouterTaches(widget.maisonId).listen((t) {
      _taches = t;
      _recus.add('taches');
      _verifierProgression();
    }));
    _abonnements.add(ecouterToutesRealisations(widget.maisonId).listen((r) {
      _realisations = r;
      _recus.add('realisations');
      _verifierProgression();
    }));
  }

  @override
  void dispose() {
    for (final a in _abonnements) {
      a.cancel();
    }
    super.dispose();
  }

  /// Bonus de connexion : une fois par jour, dès que la fiche du membre est
  /// connue. Silencieux s'il est déjà pris aujourd'hui.
  Future<void> _bonusConnexion() async {
    if (_bonusDemande || !_membres.any((m) => m['id'] == widget.profil.id)) return;
    _bonusDemande = true;
    try {
      final r = await reclamerBonusConnexion(widget.maisonId, widget.profil.id);
      if (r.montant > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Bonus de connexion : +${r.montant} Bulles · ${r.serie} jour${r.serie > 1 ? 's' : ''} de suite'),
        ));
      }
    } catch (_) {
      // hors connexion : on réessaiera à la prochaine ouverture
      _bonusDemande = false;
    }
  }

  Future<void> _verifierProgression() async {
    if (_recus.length < 3 || _celebrationOuverte || !mounted) return;
    if (!_membres.any((m) => m['id'] == widget.profil.id)) return;

    final stats = calculerStats(widget.profil.id, _realisations, _taches);
    final contexte = contexteMaison(_membres, _realisations, _taches);
    final debloques = succesDebloques(stats, contexte);

    final prefs = await SharedPreferences.getInstance();
    final vu = prefs.getString(_cleVu);
    final niveauVu = vu == null ? stats.niveau : int.tryParse(vu.split(';').first) ?? stats.niveau;
    final idsVus = vu == null ? debloques : vu.split(';').last.split(',').where((e) => e.isNotEmpty).toSet();

    final nouveaux = succes.where((s) => debloques.contains(s.id) && !idsVus.contains(s.id)).toList();
    final montee = stats.niveau > niveauVu;

    await prefs.setString(
      _cleVu,
      '${stats.niveau > niveauVu ? stats.niveau : niveauVu};${{...idsVus, ...debloques}.join(',')}',
    );
    if (vu == null || (!montee && nouveaux.isEmpty) || !mounted) return;

    _celebrationOuverte = true;
    await showDialog<void>(
      context: context,
      builder: (contexteDialogue) => AlertDialog(
        backgroundColor: Palette.papier,
        shape: const RoundedRectangleBorder(),
        title: Text(montee ? 'Niveau ${stats.niveau} !' : 'Succès débloqué !',
            style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.encre)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (montee)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('Vous êtes maintenant « ${titreNiveau(stats.niveau)} ». +${[for (var n = niveauVu + 1; n <= stats.niveau; n++) bullesNiveau(n)].fold(0, (a, b) => a + b)} Bulles.',
                    style: const TextStyle(color: Palette.encreDouce)),
              ),
            for (final s in nouveaux)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(s.icone, size: 34, color: s.rarete.couleur),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.nom, style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.encre)),
                          Text(s.rarete.libelle.toUpperCase(),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: s.rarete.couleurTexte)),
                          Text('${s.description} · +${bullesSucces(s.rarete)} Bulles', style: const TextStyle(fontSize: 12, color: Palette.encreDouce)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexteDialogue), child: const Text('SUPER !', style: TextStyle(color: Palette.encre, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    _celebrationOuverte = false;
  }

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
