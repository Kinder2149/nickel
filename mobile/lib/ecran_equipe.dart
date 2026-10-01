import 'dart:async';

import 'package:flutter/material.dart';

import 'donnees.dart';
import 'ecran_fiche.dart';
import 'ecran_guide.dart';
import 'jeu.dart';
import 'palette.dart';

/// Onglet « Équipe » : où en est la maison, et où en est chacun. Esprit
/// coopératif : le niveau de la maison passe en premier, et les membres ne
/// sont pas classés (ordre d'arrivée dans la maison).
class EcranEquipe extends StatefulWidget {
  const EcranEquipe({super.key, required this.profil, required this.maisonId});

  final Profil profil;
  final String maisonId;

  @override
  State<EcranEquipe> createState() => _EcranEquipeState();
}

class _EcranEquipeState extends State<EcranEquipe> {
  List<Map<String, dynamic>> _membres = [];
  List<Map<String, dynamic>> _taches = [];
  List<Map<String, dynamic>> _realisations = [];
  final _abonnements = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    _abonnements.add(ecouterMembres(widget.maisonId).listen((m) {
      if (mounted) setState(() => _membres = m);
    }));
    _abonnements.add(ecouterTaches(widget.maisonId).listen((t) {
      if (mounted) setState(() => _taches = t);
    }));
    _abonnements.add(ecouterToutesRealisations(widget.maisonId).listen((r) {
      if (mounted) setState(() => _realisations = r);
    }));
  }

  @override
  void dispose() {
    for (final a in _abonnements) {
      a.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contexte = contexteMaison(_membres, _realisations, _taches);
    final niveauMaison = niveauPourXp(contexte.xpMaison, echelle: echelleMaison);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.papier,
        foregroundColor: Palette.encre,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Équipe', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Comment ça marche ?',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EcranGuide())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Palette.encre,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NIVEAU DE LA MAISON', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Color(0xFFA29B85))),
                const SizedBox(height: 4),
                Text('Niveau $niveauMaison · ${titreNiveau(niveauMaison)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Palette.papier)),
                const SizedBox(height: 10),
                BarreXp(xp: contexte.xpMaison, echelle: echelleMaison, couleur: Palette.papier),
                const SizedBox(height: 4),
                Text('${contexte.xpMaison} XP gagnés ensemble',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFA29B85))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final membre in _membres) _carteMembre(membre, contexte),
        ],
      ),
    );
  }

  Widget _carteMembre(Map<String, dynamic> membre, ContexteMaison contexte) {
    final id = membre['id'] as String;
    final stats = calculerStats(id, _realisations, _taches);
    final debloques = succesDebloques(stats, contexte);
    final badges = badgesAffiches(membre['badges'] as List?, debloques);
    final estMoi = id == widget.profil.id;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EcranFiche(maisonId: widget.maisonId, profil: widget.profil, membreId: id)),
      ),
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
                for (final b in badges)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(succes.firstWhere((s) => s.id == b).icone, size: 22, color: succes.firstWhere((s) => s.id == b).rarete.couleur),
                  ),
                const Icon(Icons.chevron_right, color: Palette.encreFaible),
              ],
            ),
            const SizedBox(height: 10),
            BarreXp(xp: stats.xp),
            const SizedBox(height: 10),
            Row(
              children: [
                _chiffre('${stats.semaine}', 'cette semaine'),
                _chiffre('${stats.taches}', 'au total'),
                _chiffre('${stats.serie} j', 'de série'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chiffre(String valeur, String libelle) => Expanded(
        child: Row(
          children: [
            Text(valeur, style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.encre)),
            const SizedBox(width: 4),
            Flexible(child: Text(libelle, style: const TextStyle(fontSize: 11, color: Palette.encreDouce))),
          ],
        ),
      );
}
