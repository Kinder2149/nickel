import 'dart:async';

import 'package:flutter/material.dart';

import 'catalogue.dart';
import 'donnees.dart';
import 'jeu.dart';
import 'palette.dart';

/// La boutique : on y échange ses Bulles contre des avatars et des
/// couvertures. On ne peut pas tout acheter ; certains objets ne s'achètent
/// pas du tout, ils se gagnent avec un succès.
class EcranBoutique extends StatefulWidget {
  const EcranBoutique({super.key, required this.maisonId, required this.profil});

  final String maisonId;
  final Profil profil;

  @override
  State<EcranBoutique> createState() => _EcranBoutiqueState();
}

class _EcranBoutiqueState extends State<EcranBoutique> {
  List<Map<String, dynamic>> _membres = [];
  List<Map<String, dynamic>> _taches = [];
  List<Map<String, dynamic>> _realisations = [];
  final _abonnements = <StreamSubscription>[];
  bool _achatEnCours = false;

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

  Map<String, dynamic>? get _moi => _membres.where((m) => m['id'] == widget.profil.id).firstOrNull;

  Future<void> _acheter(Objet o, int solde) async {
    if (_achatEnCours) return;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        backgroundColor: Palette.papier,
        shape: const RoundedRectangleBorder(),
        title: Text('Acheter « ${o.nom} » ?', style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.encre)),
        content: Text('${o.prix} Bulles. Il vous en restera ${solde - o.prix}.', style: const TextStyle(color: Palette.encreDouce)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexte, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(contexte, true),
            child: const Text('Acheter', style: TextStyle(color: Palette.encre, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _achatEnCours = true);
    try {
      await acheterObjet(widget.maisonId, widget.profil.id, o.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${o.nom} » est à vous. Équipez-le depuis Mon profil.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Achat impossible : $e'), backgroundColor: Palette.rouge),
      );
    } finally {
      if (mounted) setState(() => _achatEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moi = _moi;
    final stats = calculerStats(widget.profil.id, _realisations, _taches);
    final contexte = contexteMaison(_membres, _realisations, _taches);
    final debloques = succesDebloques(stats, contexte);
    final achats = moi?['achats'] as List?;
    final solde = soldeBulles(bullesGagnees(stats, debloques), achats);
    final possedes = {
      for (final o in [...objetsPossedes(TypeObjet.avatar, achats, debloques), ...objetsPossedes(TypeObjet.couverture, achats, debloques)])
        o.id,
    };

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Palette.papier,
          foregroundColor: Palette.encre,
          elevation: 0,
          title: const Text('Boutique', style: TextStyle(fontWeight: FontWeight.w900)),
          bottom: const TabBar(
            labelColor: Palette.encre,
            indicatorColor: Palette.encre,
            unselectedLabelColor: Palette.encreDouce,
            tabs: [Tab(text: 'AVATARS'), Tab(text: 'COUVERTURES')],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Palette.encre,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.bubble_chart, color: Palette.papier),
                  const SizedBox(width: 10),
                  Text('$solde Bulles', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.papier)),
                  const Spacer(),
                  const Text('on ne peut pas tout acheter', style: TextStyle(fontSize: 11, color: Color(0xFFA29B85))),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _grille(TypeObjet.avatar, possedes, solde, debloques),
                  _grille(TypeObjet.couverture, possedes, solde, debloques),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grille(TypeObjet type, Set<String> possedes, int solde, Set<String> debloques) {
    // Les gratuits n'ont pas leur place en boutique (ils sont déjà à tout le monde).
    final objets = tousLesObjets.where((o) => o.type == type && !o.estGratuit).toList()
      ..sort((a, b) {
        final possedeA = possedes.contains(a.id) ? 1 : 0;
        final possedeB = possedes.contains(b.id) ? 1 : 0;
        if (possedeA != possedeB) return possedeA - possedeB; // à acheter d'abord
        return a.rarete.index != b.rarete.index ? a.rarete.index - b.rarete.index : a.prix - b.prix;
      });

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.82,
      children: [for (final o in objets) _carte(o, possedes.contains(o.id), solde)],
    );
  }

  Widget _carte(Objet o, bool possede, int solde) {
    final exclusif = o.succesRequis != null;
    final succes_ = exclusif ? succes.firstWhere((s) => s.id == o.succesRequis) : null;
    final assezDeBulles = solde >= o.prix;

    final String etat;
    final VoidCallback? action;
    if (possede) {
      etat = 'Possédé';
      action = null;
    } else if (exclusif) {
      etat = 'Succès : ${succes_!.nom}';
      action = null;
    } else {
      etat = '${o.prix} Bulles';
      action = assezDeBulles ? () => _acheter(o, solde) : null;
    }

    return Opacity(
      opacity: possede ? 0.55 : 1,
      child: InkWell(
        onTap: action,
        child: Container(
          decoration: BoxDecoration(
            color: Palette.papierClair,
            border: Border.all(color: o.rarete.couleur, width: 2),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(child: Center(child: _apercu(o))),
              const SizedBox(height: 6),
              Text(o.nom, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.encre)),
              Text(o.rarete.libelle.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, color: o.rarete.couleur)),
              const SizedBox(height: 4),
              Text(
                etat,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: possede
                      ? Palette.vert
                      : (exclusif ? Palette.encreDouce : (assezDeBulles ? Palette.encre : Palette.encreFaible)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _apercu(Objet o) {
    if (o.type == TypeObjet.avatar) {
      return Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: widget.profil.couleur, shape: BoxShape.circle),
        child: Icon(o.icone, size: 38, color: Colors.white),
      );
    }
    return Container(height: 64, decoration: decorationCouverture(o));
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
