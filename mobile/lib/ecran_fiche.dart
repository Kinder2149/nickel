import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalogue.dart';
import 'catalogue_distant.dart';
import 'donnees.dart';
import 'ecran_boutique.dart';
import 'ecran_guide.dart';
import 'jeu.dart';
import 'palette.dart';
import 'stockage_local.dart';

/// Pastille d'un membre : son avatar si il en a choisi un, sinon son
/// initiale sur sa couleur.
class PastilleMembre extends StatelessWidget {
  const PastilleMembre({super.key, required this.membre, this.taille = 36});

  final Map<String, dynamic>? membre;
  final double taille;

  @override
  Widget build(BuildContext context) {
    // Se redessine quand le catalogue distant arrive (un avatar à image).
    return ValueListenableBuilder<List<Objet>>(
      valueListenable: objetsDistants,
      builder: (context, objets, enfant) {
        final avatar = avatarPourId(membre?['avatar'] as String?);
        final couleur = membre != null ? hexVersCouleur(membre!['couleur'] as String) : Palette.encreFaible;
        final prenom = (membre?['prenom'] as String?) ?? '?';
        final initiale = Text(prenom.substring(0, 1).toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: taille * 0.4));
        return Container(
          width: taille,
          height: taille,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
          child: avatar.image != null
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatar.image!,
                    width: taille,
                    height: taille,
                    fit: BoxFit.cover,
                    errorWidget: (contexte, url, erreur) => initiale,
                    placeholder: (contexte, url) => initiale,
                  ),
                )
              : avatar.icone != null
                  ? Icon(avatar.icone, color: Colors.white, size: taille * 0.55)
                  : initiale,
        );
      },
    );
  }
}

/// Barre d'XP vers le niveau suivant.
class BarreXp extends StatelessWidget {
  const BarreXp({super.key, required this.xp, this.echelle = 50, this.couleur = Palette.vert});

  final int xp;
  final int echelle;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final p = progressionNiveau(xp, echelle: echelle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: p.pourSuivant == 0 ? 0 : p.dansNiveau / p.pourSuivant,
          minHeight: 10,
          color: couleur,
          backgroundColor: Palette.trait,
        ),
        const SizedBox(height: 4),
        Text('${p.dansNiveau} / ${p.pourSuivant} XP vers le niveau suivant',
            style: const TextStyle(fontSize: 11, color: Palette.encreDouce)),
      ],
    );
  }
}

/// Fiche personnage d'un membre, visible par toute la maison. Le sien est
/// modifiable (nom, avatar, couverture, trois badges).
class EcranFiche extends StatefulWidget {
  const EcranFiche({super.key, required this.maisonId, required this.profil, required this.membreId});

  final String maisonId;
  final Profil profil;
  final String membreId;

  @override
  State<EcranFiche> createState() => _EcranFicheState();
}

class _EcranFicheState extends State<EcranFiche> {
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

  bool get _estMoi => widget.membreId == widget.profil.id;

  @override
  Widget build(BuildContext context) {
    final membre = _membres.where((m) => m['id'] == widget.membreId).firstOrNull;
    if (membre == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Palette.papier, foregroundColor: Palette.encre, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: Palette.encre)),
      );
    }

    final stats = calculerStats(widget.membreId, _realisations, _taches);
    final contexte = contexteMaison(_membres, _realisations, _taches);
    final debloques = succesDebloques(stats, contexte);
    final couverture = couverturePourId(membre['couverture'] as String?);
    final badges = badgesAffiches(membre['badges'] as List?, debloques);
    final solde = soldeBulles(bullesGagnees(stats, debloques), membre['achats'] as List?, bonus: (membre['bullesBonus'] as int?) ?? 0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.papier,
        foregroundColor: Palette.encre,
        elevation: 0,
        title: Text(_estMoi ? 'Mon profil' : membre['prenom'] as String, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Comment ça marche ?',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EcranGuide())),
          ),
          if (_estMoi)
            IconButton(
              tooltip: 'Marché',
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EcranBoutique(maisonId: widget.maisonId, profil: widget.profil)),
              ),
            ),
          if (_estMoi)
            TextButton(
              onPressed: () => _modifier(membre, stats, debloques),
              child: const Text('MODIFIER', style: TextStyle(fontWeight: FontWeight.bold, color: Palette.encre)),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 130,
                decoration: decorationCouverture(couverture),
              ),
              Positioned(
                left: 22,
                bottom: -36,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Palette.papier, shape: BoxShape.circle),
                  child: PastilleMembre(membre: membre, taille: 80),
                ),
              ),
            ],
          ),
          const SizedBox(height: 46),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(membre['prenom'] as String,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Palette.encre)),
                Text('Niveau ${stats.niveau} · ${titreNiveau(stats.niveau)} · ${stats.xp} XP',
                    style: const TextStyle(color: Palette.encreDouce, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                BarreXp(xp: stats.xp),
                if (_estMoi) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.bubble_chart, size: 18, color: Palette.encreDouce),
                      const SizedBox(width: 6),
                      Text('$solde Bulles', style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.encre)),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: _emplacementBadge(i < badges.length ? succes.firstWhere((s) => s.id == badges[i]) : null)),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _stat('${stats.taches}', 'Tâches faites'),
                    _stat('${stats.semaine}', 'Cette semaine'),
                    _stat('${stats.serie} j', 'Série en cours'),
                    _stat('${stats.meilleureSerie} j', 'Meilleure série'),
                  ],
                ),
                const SizedBox(height: 24),
                ..._sectionSucces(stats, contexte, debloques),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emplacementBadge(Succes? s) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: Palette.papierClair,
        border: Border.all(color: s != null ? s.rarete.couleur : Palette.trait, width: s != null ? 2.5 : 1.5),
      ),
      alignment: Alignment.center,
      child: s == null
          ? const Text('—', style: TextStyle(fontSize: 22, color: Palette.encreFaible))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s.icone, size: 30, color: s.rarete.couleur),
                const SizedBox(height: 4),
                Text(s.nom, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Palette.encre)),
              ],
            ),
    );
  }

  Widget _stat(String valeur, String libelle) {
    return Expanded(
      child: Column(
        children: [
          Text(valeur, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.encre)),
          const SizedBox(height: 2),
          Text(libelle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Palette.encreDouce)),
        ],
      ),
    );
  }

  /// « Prochains objectifs » (les plus proches), puis les succès débloqués,
  /// puis le reste à découvrir.
  List<Widget> _sectionSucces(StatsMembre stats, ContexteMaison contexte, Set<String> debloques) {
    double avancement(Succes s) => (s.valeur(stats, contexte) / s.objectif).clamp(0, 1).toDouble();
    final aDebloquer = succes.where((s) => !debloques.contains(s.id)).toList()
      ..sort((a, b) => avancement(b).compareTo(avancement(a)));
    final prochains = aDebloquer.take(3).toList();
    final reste = aDebloquer.skip(3).toList();
    final obtenus = succes.where((s) => debloques.contains(s.id)).toList();

    Widget titre(String t) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Palette.encreFaible)),
        );

    return [
      titre('SUCCÈS · ${debloques.length} / ${succes.length}'),
      if (prochains.isNotEmpty) ...[
        titre('PROCHAINS OBJECTIFS'),
        for (final s in prochains) _ligneSucces(s, stats, contexte, false),
      ],
      if (obtenus.isNotEmpty) ...[
        titre('DÉBLOQUÉS'),
        for (final s in obtenus) _ligneSucces(s, stats, contexte, true),
      ],
      if (reste.isNotEmpty) ...[
        titre('À DÉCOUVRIR'),
        for (final s in reste) _ligneSucces(s, stats, contexte, false),
      ],
    ];
  }

  Widget _ligneSucces(Succes s, StatsMembre stats, ContexteMaison contexte, bool debloque) {
    final valeur = s.valeur(stats, contexte).clamp(0, s.objectif);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Palette.papierClair,
              border: Border.all(color: debloque ? s.rarete.couleur : Palette.trait, width: debloque ? 2.5 : 1.5),
            ),
            child: Icon(debloque ? s.icone : Icons.lock_outline, size: 24, color: debloque ? s.rarete.couleur : Palette.encreFaible),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(s.nom, style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.encre))),
                    const SizedBox(width: 8),
                    Text(s.rarete.libelle.toUpperCase(),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, color: s.rarete.couleur)),
                  ],
                ),
                Text(s.description, style: const TextStyle(fontSize: 12, color: Palette.encreDouce)),
                if (!debloque && s.objectif > 1) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: valeur / s.objectif,
                          minHeight: 6,
                          color: s.rarete.couleur,
                          backgroundColor: Palette.trait,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$valeur / ${s.objectif}', style: const TextStyle(fontSize: 11, color: Palette.encreDouce)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _modifier(Map<String, dynamic> membre, StatsMembre stats, Set<String> debloques) async {
    final enregistre = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.papier,
      builder: (_) => _EditeurProfil(
        maisonId: widget.maisonId,
        profil: widget.profil,
        membre: membre,
        debloques: debloques,
      ),
    );
    if (enregistre == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil enregistré. Le nouveau nom s\'affichera partout au prochain démarrage.')),
      );
    }
  }
}

class _EditeurProfil extends StatefulWidget {
  const _EditeurProfil({
    required this.maisonId,
    required this.profil,
    required this.membre,
    required this.debloques,
  });

  final String maisonId;
  final Profil profil;
  final Map<String, dynamic> membre;
  final Set<String> debloques;

  @override
  State<_EditeurProfil> createState() => _EditeurProfilState();
}

class _EditeurProfilState extends State<_EditeurProfil> {
  late final _nom = TextEditingController(text: widget.membre['prenom'] as String);
  late String _avatar = avatarPourId(widget.membre['avatar'] as String?).id;
  late String _couverture = couverturePourId(widget.membre['couverture'] as String?).id;
  late List<String> _badges = badgesAffiches(widget.membre['badges'] as List?, widget.debloques);
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final nom = _nom.text.trim();
    if (nom.isEmpty) {
      setState(() => _erreur = 'Le nom ne peut pas être vide.');
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await modifierProfil(widget.maisonId, widget.profil.id,
          prenom: nom, avatar: _avatar, couverture: _couverture, badges: _badges);
      final prefs = await SharedPreferences.getInstance();
      await enregistrerProfilLocal(prefs, Profil(id: widget.profil.id, prenom: nom, couleur: widget.profil.couleur));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur = 'Enregistrement impossible : $e';
      });
    }
  }

  void _basculerBadge(String id) {
    setState(() {
      if (_badges.contains(id)) {
        _badges = [..._badges]..remove(id);
      } else if (_badges.length < 3) {
        _badges = [..._badges, id];
      }
    });
  }

  Widget _titre(String texte) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(texte, style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Mon profil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.encre)),
            if (_erreur != null) ...[
              const SizedBox(height: 10),
              Text(_erreur!, style: const TextStyle(color: Palette.rouge)),
            ],
            _titre('Nom'),
            TextField(controller: _nom, maxLength: 20, decoration: decorationChamp('Votre prénom')),
            _titre('Avatar'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in objetsPossedes(TypeObjet.avatar, widget.membre['achats'] as List?, widget.debloques))
                  _case(
                    choisi: a.id == _avatar,
                    onTap: () => setState(() => _avatar = a.id),
                    enfant: PastilleMembre(membre: {...widget.membre, 'avatar': a.id}, taille: 34),
                  ),
              ],
            ),
            _titre('Couverture'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in objetsPossedes(TypeObjet.couverture, widget.membre['achats'] as List?, widget.debloques))
                  _case(
                    choisi: c.id == _couverture,
                    largeur: 72,
                    onTap: () => setState(() => _couverture = c.id),
                    enfant: Container(decoration: decorationCouverture(c)),
                  ),
              ],
            ),
            _titre('Trois badges (${_badges.length} / 3) — à choisir parmi vos succès'),
            if (widget.debloques.isEmpty)
              const Text('Aucun succès débloqué pour l\'instant : cochez une tâche !',
                  style: TextStyle(color: Palette.encreFaible, fontSize: 12))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in succes.where((s) => widget.debloques.contains(s.id)))
                    _case(
                      choisi: _badges.contains(s.id),
                      onTap: () => _basculerBadge(s.id),
                      enfant: Icon(s.icone, size: 24, color: s.rarete.couleur),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _enCours ? null : _enregistrer,
              style: boutonPrincipal(),
              child: const Text('ENREGISTRER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _case({
    required bool choisi,
    required VoidCallback onTap,
    required Widget enfant,
    double largeur = 46,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: largeur,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Palette.papierClair,
          border: Border.all(color: choisi ? Palette.encre : Palette.trait, width: choisi ? 2.5 : 1.5),
        ),
        child: SizedBox.expand(child: Center(child: enfant)),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
