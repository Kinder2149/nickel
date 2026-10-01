import 'dart:async';

import 'package:flutter/material.dart';

import 'donnees.dart';
import 'ecran_fiche.dart';
import 'palette.dart';

/// Écran "Historique" — équivalent Flutter de `afficherEcranHistorique`
/// (public/v2/js/app.js) : les Réalisations groupées par jour, la plus
/// récente en premier, avec le pictogramme de la tâche et le jeton du
/// membre qui l'a faite.
class EcranHistorique extends StatefulWidget {
  const EcranHistorique({super.key, required this.maisonId});

  final String maisonId;

  @override
  State<EcranHistorique> createState() => _EcranHistoriqueState();
}

class _EcranHistoriqueState extends State<EcranHistorique> {
  List<Map<String, dynamic>> _taches = [];
  List<Map<String, dynamic>> _membres = [];
  List<Map<String, dynamic>> _realisations = [];
  StreamSubscription? _subTaches;
  StreamSubscription? _subMembres;
  StreamSubscription? _subRealisations;

  @override
  void initState() {
    super.initState();
    _subTaches = ecouterTaches(widget.maisonId).listen((t) {
      if (mounted) setState(() => _taches = t);
    });
    _subMembres = ecouterMembres(widget.maisonId).listen((m) {
      if (mounted) setState(() => _membres = m);
    });
    _subRealisations = ecouterRealisations(widget.maisonId).listen((r) {
      if (mounted) setState(() => _realisations = r);
    });
  }

  @override
  void dispose() {
    _subTaches?.cancel();
    _subMembres?.cancel();
    _subRealisations?.cancel();
    super.dispose();
  }

  String _libelleJour(String dateISO) {
    final aujourdhui = dateAujourdhui();
    final hier = ajouterJours(aujourdhui, -1);
    if (dateISO == aujourdhui) return "Aujourd'hui";
    if (dateISO == hier) return 'Hier';
    return dateISO;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.papier,
        foregroundColor: Palette.encre,
        elevation: 0,
        title: const Text('Historique', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: _realisations.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(22),
              child: Text("Aucune réalisation pour l'instant.", style: TextStyle(color: Palette.encreDouce)),
            )
          : _liste(),
    );
  }

  Widget _liste() {
    final parJour = <String, List<Map<String, dynamic>>>{};
    for (final r in _realisations) {
      (parJour[r['dateRealisation'] as String] ??= []).add(r);
    }
    final jours = parJour.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
      children: [
        for (final jour in jours) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6),
            child: Text(_libelleJour(jour).toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Palette.encreFaible)),
          ),
          for (final r in parJour[jour]!) _ligneRealisation(r),
        ],
      ],
    );
  }

  Widget _ligneRealisation(Map<String, dynamic> r) {
    final tache = _taches.where((t) => t['id'] == r['tacheId']).firstOrNull;
    final membre = _membres.where((m) => m['id'] == r['realiseParId']).firstOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          PastilleMembre(membre: membre, taille: 32),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Palette.papierClair, border: Border.all(color: Palette.trait)),
            child: Text(tache != null ? ((tache['emoji'] as String?) ?? '🧹') : '❔', style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.encre, fontSize: 14),
                children: [
                  TextSpan(text: tache != null ? tache['nom'] as String : 'Tâche supprimée'),
                  TextSpan(
                    text: '  par ${membre != null ? membre['prenom'] as String : '?'}',
                    style: const TextStyle(fontWeight: FontWeight.normal, color: Palette.encreFaible, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Supprimer (fait par erreur)',
            onPressed: () => _supprimer(r, tache?['nom'] as String?),
            icon: const Icon(Icons.delete_outline, color: Palette.encreFaible, size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _supprimer(Map<String, dynamic> r, String? nomTache) async {
    final date = (r['dateRealisation'] as String).split('-');
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Supprimer cette réalisation ?'),
        content: Text(
          '« ${nomTache ?? 'Tâche supprimée'} » du ${date[2]}/${date[1]} sera retirée de l\'historique, '
          'et la prochaine échéance de la tâche sera recalculée.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexte, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(contexte, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await supprimerRealisation(widget.maisonId, r['id'] as String, r['tacheId'] as String);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression impossible : $e'), backgroundColor: Palette.rouge),
      );
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
