import 'dart:async';

import 'package:flutter/material.dart';

import 'donnees.dart';
import 'palette.dart';

const _emojiParDefaut = '🧹';

const _libelleSection = {
  'retard': 'En retard',
  'aujourdhui': "À faire aujourd'hui",
  'avenir': 'À venir',
  'jamais': 'Jamais renseignées',
};

const _ordreSections = ['retard', 'aujourdhui', 'avenir', 'jamais'];

class _EnAttente {
  _EnAttente({required this.tache, required this.forcerEnregistrement, required this.annuler});
  final Map<String, dynamic> tache;
  final VoidCallback forcerEnregistrement;
  final VoidCallback annuler;
}

/// Écran "À faire" — équivalent Flutter de `afficherEcranAFaire`
/// (public/v2/js/app.js), déjà avec le correctif du peaufinage (§ 16
/// point 3) : une tâche cochée quitte immédiatement sa section pour un
/// bloc "Fait ✓" à part, écrite en base seulement après un délai de 5
/// secondes (annulable). Pas de confirmation sur ce geste — le plus
/// fréquent de l'app, doit rester fluide (décision du 2026-09-08).
class EcranAFaire extends StatefulWidget {
  const EcranAFaire({super.key, required this.profil, required this.maisonId});

  final Profil profil;
  final String maisonId;

  @override
  State<EcranAFaire> createState() => _EcranAFaireState();
}

class _EcranAFaireState extends State<EcranAFaire> {
  static const _delaiAnnulation = Duration(seconds: 5);

  final Map<String, _EnAttente> _enAttente = {};

  @override
  void dispose() {
    // Un "Fait" en attente d'annulation qui n'a pas encore expiré doit tout
    // de même s'enregistrer si on quitte l'écran — sinon un geste réel se
    // perdrait silencieusement juste parce qu'on a changé d'écran (même
    // règle que sur la V2 web, § 16 point 1).
    for (final entree in _enAttente.values) {
      entree.forcerEnregistrement();
    }
    super.dispose();
  }

  void _cocher(Map<String, dynamic> tache) {
    final tacheId = tache['id'] as String;
    final aujourdhui = dateAujourdhui();
    final prochaineEcheance = ajouterJours(aujourdhui, tache['frequenceJours'] as int);

    var enregistre = false;
    late Timer minuteur;

    void enregistrer() {
      if (enregistre) return;
      enregistre = true;
      if (mounted) setState(() => _enAttente.remove(tacheId));
      enregistrerRealisation(widget.maisonId, tacheId, widget.profil.id, aujourdhui, prochaineEcheance);
    }

    minuteur = Timer(_delaiAnnulation, enregistrer);

    setState(() {
      _enAttente[tacheId] = _EnAttente(
        tache: tache,
        forcerEnregistrement: () {
          minuteur.cancel();
          enregistrer();
        },
        annuler: () {
          if (enregistre) return;
          minuteur.cancel();
          enregistre = true;
          setState(() => _enAttente.remove(tacheId));
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.papier,
        foregroundColor: Palette.encre,
        elevation: 0,
        title: const Text('À faire', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ecouterTaches(widget.maisonId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}', style: const TextStyle(color: Palette.rouge)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Palette.encre));
          }

          final taches = snapshot.data!;
          if (taches.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(22),
              child: Text('Aucune tâche. Ajoutez-en depuis "Pièces et tâches".', style: TextStyle(color: Palette.encreDouce)),
            );
          }

          final tachesRestantes = taches.where((t) => !_enAttente.containsKey(t['id'])).toList();
          final groupes = <String, List<Map<String, dynamic>>>{
            'retard': [],
            'aujourdhui': [],
            'avenir': [],
            'jamais': [],
          };
          for (final t in tachesRestantes) {
            groupes[statutTache(t)]!.add(t);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
            children: [
              if (_enAttente.isNotEmpty) ...[
                _bandeau('FAIT ✓', Palette.vert),
                ..._enAttente.values.map((e) => _ligneFait(e)),
                const SizedBox(height: 20),
              ],
              for (final section in _ordreSections)
                if (groupes[section]!.isNotEmpty) ...[
                  _bandeau(_libelleSection[section]!.toUpperCase(), section == 'retard' ? Palette.rouge : Palette.encre),
                  ...groupes[section]!.map((t) => _ligneTache(t, section)),
                  const SizedBox(height: 20),
                ],
            ],
          );
        },
      ),
    );
  }

  Widget _bandeau(String texte, Color couleur) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: couleur,
      child: Text(texte, style: const TextStyle(color: Palette.papier, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
    );
  }

  Widget _ligneFait(_EnAttente entree) {
    final t = entree.tache;
    return _ligne(
      emoji: (t['emoji'] as String?) ?? _emojiParDefaut,
      titre: t['nom'] as String,
      sousTitre: null,
      bordureCase: Palette.trait,
      bouton: OutlinedButton(
        onPressed: entree.annuler,
        style: OutlinedButton.styleFrom(foregroundColor: Palette.encre, side: const BorderSide(color: Palette.encre, width: 1.5), shape: const RoundedRectangleBorder()),
        child: const Text('ANNULER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _ligneTache(Map<String, dynamic> t, String section) {
    final echeance = t['prochaineEcheance'] as String?;
    final bordureEpaisse = section == 'retard' || section == 'aujourdhui';
    return _ligne(
      emoji: (t['emoji'] as String?) ?? _emojiParDefaut,
      titre: t['nom'] as String,
      sousTitre: echeance != null ? 'échéance $echeance' : 'pas encore faite',
      bordureCase: bordureEpaisse ? Palette.encre : Palette.trait,
      epaisseurBordure: bordureEpaisse ? 2.5 : 1,
      bouton: OutlinedButton(
        onPressed: () => _cocher(t),
        style: OutlinedButton.styleFrom(foregroundColor: Palette.encre, side: const BorderSide(color: Palette.encre, width: 1.5), shape: const RoundedRectangleBorder()),
        child: const Text('FAIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _ligne({
    required String emoji,
    required String titre,
    required String? sousTitre,
    required Color bordureCase,
    required Widget bouton,
    double epaisseurBordure = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Palette.papierClair,
              border: Border.all(color: bordureCase, width: epaisseurBordure),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.encre)),
                if (sousTitre != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(sousTitre, style: const TextStyle(fontSize: 11, color: Palette.encreFaible)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          bouton,
        ],
      ),
    );
  }
}
