import 'dart:async';

import 'package:flutter/material.dart';

import 'donnees.dart';
import 'ecran_fiche.dart';
import 'palette.dart';

/// Nombre de réalisations chargées par l'écran Historique complet (les plus
/// récentes de la maison). L'historique entier d'une tâche est dans sa fiche.
const _limiteHistorique = 100;

/// « Aujourd'hui », « Hier », sinon la date courte (jj/mm, avec l'année si
/// ce n'est pas l'année en cours).
String libelleJour(String dateISO) {
  final aujourdhui = dateAujourdhui();
  if (dateISO == aujourdhui) return "Aujourd'hui";
  if (dateISO == ajouterJours(aujourdhui, -1)) return 'Hier';
  final x = dateISO.split('-');
  final annee = DateTime.now().year.toString() == x[0] ? '' : '/${x[0]}';
  return '${x[2]}/${x[1]}$annee';
}

/// Plus récente d'abord : par date de réalisation, puis par heure
/// d'enregistrement (deux coches le même jour).
int comparerRealisations(Map<String, dynamic> a, Map<String, dynamic> b) {
  final parDate = (b['dateRealisation'] as String).compareTo(a['dateRealisation'] as String);
  if (parDate != 0) return parDate;
  return ((b['enregistreLe'] as String?) ?? '').compareTo((a['enregistreLe'] as String?) ?? '');
}

/// Écran "Historique" — équivalent Flutter de `afficherEcranHistorique`
/// (public/v2/js/app.js) : les Réalisations groupées par jour, la plus
/// récente en premier, avec le pictogramme de la tâche et le jeton du
/// membre qui l'a faite. Ouvert depuis l'onglet Équipe (§ 31).
class EcranHistorique extends StatefulWidget {
  const EcranHistorique({super.key, required this.maisonId});

  final String maisonId;

  @override
  State<EcranHistorique> createState() => _EcranHistoriqueState();
}

class _EcranHistoriqueState extends State<EcranHistorique> {
  List<Map<String, dynamic>> _taches = [];
  List<Map<String, dynamic>> _membres = [];
  List<Map<String, dynamic>>? _realisations;
  Object? _erreur;
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
    _subRealisations = ecouterRealisations(widget.maisonId, limite: _limiteHistorique).listen((r) {
      if (mounted) setState(() => _realisations = r);
    }, onError: (Object e) {
      if (mounted) setState(() => _erreur = e);
    });
  }

  @override
  void dispose() {
    _subTaches?.cancel();
    _subMembres?.cancel();
    _subRealisations?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final realisations = _realisations;
    final Widget corps;
    if (_erreur != null) {
      corps = Padding(
        padding: const EdgeInsets.all(22),
        child: Text("Impossible d'afficher l'historique. ${texteErreur(_erreur!)}", style: const TextStyle(color: Palette.rouge)),
      );
    } else if (realisations == null) {
      corps = const Center(child: CircularProgressIndicator(color: Palette.encre));
    } else if (realisations.isEmpty) {
      corps = const Padding(
        padding: EdgeInsets.all(22),
        child: Text("Aucune réalisation pour l'instant. Chaque tâche cochée « Fait » apparaîtra ici.",
            style: TextStyle(color: Palette.encreDouce)),
      );
    } else {
      corps = _liste(realisations);
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.papier,
        foregroundColor: Palette.encre,
        elevation: 0,
        title: const Text('Historique', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: corps,
    );
  }

  Widget _liste(List<Map<String, dynamic>> realisations) {
    final parJour = <String, List<Map<String, dynamic>>>{};
    for (final r in realisations) {
      (parJour[r['dateRealisation'] as String] ??= []).add(r);
    }
    final jours = parJour.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
      children: [
        for (final jour in jours) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6),
            child: Text(libelleJour(jour).toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Palette.encreFaible)),
          ),
          for (final r in parJour[jour]!)
            LigneRealisation(
              realisation: r,
              taches: _taches,
              membres: _membres,
              onSupprimer: (nomTache) => _supprimer(r, nomTache),
            ),
        ],
        if (realisations.length >= _limiteHistorique)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              'Seules les $_limiteHistorique dernières réalisations sont affichées ici. '
              "L'historique complet de chaque tâche est dans sa fiche (touchez la tâche sur l'accueil).",
              style: TextStyle(fontSize: 12, color: Palette.encreFaible),
            ),
          ),
      ],
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
      if (mounted) signalerErreur(context, e);
    }
  }
}

/// Une ligne d'historique : qui (jeton du membre), quoi (pictogramme et nom
/// de la tâche). `avecDate` ajoute le jour, quand la liste n'est pas déjà
/// groupée par jour (onglet Équipe). `onSupprimer` ajoute la corbeille.
class LigneRealisation extends StatelessWidget {
  const LigneRealisation({
    super.key,
    required this.realisation,
    required this.taches,
    required this.membres,
    this.avecDate = false,
    this.onSupprimer,
  });

  final Map<String, dynamic> realisation;
  final List<Map<String, dynamic>> taches;
  final List<Map<String, dynamic>> membres;
  final bool avecDate;
  final void Function(String? nomTache)? onSupprimer;

  @override
  Widget build(BuildContext context) {
    final r = realisation;
    final tache = taches.where((t) => t['id'] == r['tacheId']).firstOrNull;
    final membre = membres.where((m) => m['id'] == r['realiseParId']).firstOrNull;
    final par = 'par ${membre != null ? membre['prenom'] as String : '?'}';

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
                    text: avecDate ? '\n${libelleJour(r['dateRealisation'] as String)} · $par' : '  $par',
                    style: const TextStyle(fontWeight: FontWeight.normal, color: Palette.encreFaible, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (onSupprimer != null)
            IconButton(
              tooltip: 'Supprimer (fait par erreur)',
              onPressed: () => onSupprimer!(tache?['nom'] as String?),
              icon: const Icon(Icons.delete_outline, color: Palette.encreFaible, size: 20),
            ),
        ],
      ),
    );
  }
}

/// Historique complet d'une seule tâche, pour sa fiche : chaque passage
/// (jour, qui) et l'écart avec le précédent, plus un résumé du rythme réel
/// comparé à la fréquence prévue — « comment elle est nettoyée » (§ 31).
class HistoriqueTache extends StatefulWidget {
  const HistoriqueTache({
    super.key,
    required this.maisonId,
    required this.tacheId,
    required this.frequenceJours,
    required this.membres,
  });

  final String maisonId;
  final String tacheId;
  final int frequenceJours;
  final List<Map<String, dynamic>> membres;

  @override
  State<HistoriqueTache> createState() => _HistoriqueTacheState();
}

class _HistoriqueTacheState extends State<HistoriqueTache> {
  static const _apercu = 10;
  bool _toutAfficher = false;
  late final Stream<List<Map<String, dynamic>>> _flux = ecouterRealisationsTache(widget.maisonId, widget.tacheId);

  static int _ecartJours(String recente, String ancienne) {
    DateTime lire(String s) {
      final x = s.split('-').map(int.parse).toList();
      return DateTime.utc(x[0], x[1], x[2]);
    }

    return lire(recente).difference(lire(ancienne)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _flux,
      builder: (contexte, instantane) {
        final Widget contenu;
        if (instantane.hasError) {
          contenu = Text("Impossible d'afficher l'historique. ${texteErreur(instantane.error!)}",
              style: const TextStyle(color: Palette.rouge, fontSize: 13));
        } else if (!instantane.hasData) {
          contenu = const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Palette.encre))),
          );
        } else {
          contenu = _liste(instantane.data!);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(color: Palette.encre, thickness: 2, height: 32),
            const Text('HISTORIQUE DE CETTE TÂCHE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Palette.encreFaible)),
            const SizedBox(height: 8),
            contenu,
          ],
        );
      },
    );
  }

  Widget _liste(List<Map<String, dynamic>> realisations) {
    if (realisations.isEmpty) {
      return const Text("Jamais faite pour l'instant. Chaque « Fait » s'ajoutera ici.",
          style: TextStyle(color: Palette.encreDouce, fontSize: 13));
    }
    final n = realisations.length;
    final String resume;
    if (n == 1) {
      resume = 'Faite 1 fois.';
    } else {
      final etendue = _ecartJours(realisations.first['dateRealisation'] as String, realisations.last['dateRealisation'] as String);
      final moyenne = (etendue / (n - 1)).round();
      resume = 'Faite $n fois · en moyenne tous les $moyenne j (prévu : tous les ${widget.frequenceJours} j).';
    }
    final visibles = _toutAfficher ? realisations : realisations.take(_apercu).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(resume, style: const TextStyle(color: Palette.encreDouce, fontSize: 13)),
        const SizedBox(height: 6),
        for (var i = 0; i < visibles.length; i++) _ligne(visibles[i], i + 1 < realisations.length ? realisations[i + 1] : null),
        if (!_toutAfficher && n > _apercu)
          TextButton(
            onPressed: () => setState(() => _toutAfficher = true),
            child: Text('Afficher les ${n - _apercu} plus anciennes', style: const TextStyle(color: Palette.encreDouce)),
          ),
      ],
    );
  }

  Widget _ligne(Map<String, dynamic> r, Map<String, dynamic>? precedente) {
    final membre = widget.membres.where((m) => m['id'] == r['realiseParId']).firstOrNull;
    final date = r['dateRealisation'] as String;
    final ecart = precedente == null ? null : _ecartJours(date, precedente['dateRealisation'] as String);
    final enRetard = ecart != null && ecart > widget.frequenceJours;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          PastilleMembre(membre: membre, taille: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(color: Palette.encre, fontSize: 14),
                children: [
                  TextSpan(text: libelleJour(date), style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(
                    text: '  par ${membre != null ? membre['prenom'] as String : 'un ancien membre'}',
                    style: const TextStyle(color: Palette.encreFaible, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (ecart != null)
            Text(
              ecart == 0 ? 'même jour' : '$ecart j après',
              style: TextStyle(fontSize: 12, color: enRetard ? Palette.rouge : Palette.encreFaible, fontWeight: enRetard ? FontWeight.w600 : FontWeight.normal),
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
