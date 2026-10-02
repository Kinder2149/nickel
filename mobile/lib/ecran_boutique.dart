import 'dart:async';

import 'package:flutter/material.dart';

import 'catalogue.dart';
import 'catalogue_distant.dart';
import 'donnees.dart';
import 'jeu.dart';
import 'palette.dart';
import 'quetes.dart';
import 'widgets_objet.dart';

enum _Filtre { tout, avatars, couvertures }

/// Le marché. Trois parties :
///  - la SAISON EN COURS (objets en vente seulement pendant ses mois, chaque
///    année) ;
///  - le MARCHÉ PERMANENT (toujours en vente) ;
///  - PROCHAINEMENT (les saisons hors vente, avec leur date de retour).
/// Les objets déjà possédés restent à vous pour toujours, saison finie ou non.
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
  bool _occupe = false;
  _Filtre _filtre = _Filtre.tout;

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

  void _message(String texte, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte), backgroundColor: erreur ? Palette.rouge : null));
  }

  Future<void> _acheter(Objet o, int solde) async {
    if (_occupe) return;
    final maintenant = DateTime.now();
    if (!estEnVente(o, maintenant)) {
      _message('« ${o.nom} » n\'est plus en vente.', erreur: true);
      return;
    }
    if (solde < o.prix) {
      _message('Il vous manque ${o.prix - solde} Bulles.', erreur: true);
      return;
    }
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        backgroundColor: Palette.papier,
        shape: const RoundedRectangleBorder(),
        title: Text('Acheter « ${o.nom} » ?', style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.encre)),
        content: Text('${o.prix} Bulles. Il vous en restera ${solde - o.prix}.', style: const TextStyle(color: Palette.encreDouce)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexte, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(contexte, true), child: const Text('Acheter', style: TextStyle(color: Palette.encre, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _occupe = true);
    try {
      await acheterObjet(widget.maisonId, widget.profil.id, o.id);
      _message('« ${o.nom} » est à vous pour toujours. Touchez ÉQUIPER pour le porter.');
    } catch (e) {
      _message('Achat impossible : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _equiper(Objet o) async {
    try {
      await equiperObjet(widget.maisonId, widget.profil.id, o.type == TypeObjet.avatar ? 'avatar' : 'couverture', o.id);
      _message('« ${o.nom} » équipé.');
    } catch (e) {
      _message('Impossible d\'équiper : $e', erreur: true);
    }
  }

  Future<void> _basculerFavori(Objet o) async {
    final estFavori = _moi?['favori'] == o.id;
    try {
      await definirFavori(widget.maisonId, widget.profil.id, estFavori ? null : o.id);
      _message(estFavori ? '« ${o.nom} » n\'est plus votre objectif.' : '« ${o.nom} » est maintenant votre objectif.');
    } catch (e) {
      _message('Impossible de changer l\'objectif : $e', erreur: true);
    }
  }

  Future<void> _recupererCadeau(Saison s) async {
    try {
      final ok = await reclamerDotationSaison(widget.maisonId, widget.profil.id, s.cleDotation(DateTime.now()), dotationSaison);
      _message(ok ? '+$dotationSaison Bulles : cadeau de la saison « ${s.nom} » !' : 'Cadeau déjà récupéré.');
    } catch (e) {
      _message('Impossible de récupérer le cadeau : $e', erreur: true);
    }
  }

  // ------------------------------------------------------------- affichage

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([objetsDistants, saisonsDistantes]),
      builder: (context, enfant) => _page(),
    );
  }

  Widget _page() {
    final maintenant = DateTime.now();
    final moi = _moi;
    final stats = calculerStats(widget.profil.id, _realisations, _taches);
    final contexte = contexteMaison(_membres, _realisations, _taches);
    final debloques = succesDebloques(stats, contexte);
    final achats = moi?['achats'] as List?;
    final solde = soldeBulles(bullesGagnees(stats, debloques), achats, bonus: (moi?['bullesBonus'] as int?) ?? 0);
    final possedes = {
      for (final o in [...objetsPossedes(TypeObjet.avatar, achats, debloques), ...objetsPossedes(TypeObjet.couverture, achats, debloques)]) o.id,
    };
    final equipes = {(moi?['avatar'] as String?) ?? 'initiale', (moi?['couverture'] as String?) ?? 'encre'};

    final saisons = saisonsDistantes.value;
    final enCours = saisons.where((s) => s.enCours(maintenant)).toList();
    final horsVente = saisons.where((s) => !s.enCours(maintenant)).toList()
      ..sort((a, b) => a.prochainRetour(maintenant).compareTo(b.prochainRetour(maintenant)));
    final permanents = tousLesObjets.where((o) => !o.estGratuit && saisonPour(o.saison) == null).toList();

    bool filtre(Objet o) => switch (_filtre) {
          _Filtre.tout => true,
          _Filtre.avatars => o.type == TypeObjet.avatar,
          _Filtre.couvertures => o.type == TypeObjet.couverture,
        };

    List<Objet> trier(Iterable<Objet> os) => os.where(filtre).toList()
      ..sort((a, b) {
        final pa = possedes.contains(a.id) ? 1 : 0, pb = possedes.contains(b.id) ? 1 : 0;
        if (pa != pb) return pa - pb; // à acheter d'abord
        if (a.rarete.index != b.rarete.index) return a.rarete.index - b.rarete.index;
        return a.prix - b.prix;
      });

    Widget carte(Objet o) {
      final etat = etatObjet(o,
          possedes: possedes,
          equipeId: equipes.contains(o.id) ? o.id : null,
          solde: solde,
          maintenant: maintenant);
      final bouton = _bouton(o, etat, solde, maintenant);
      return CarteObjet(
        objet: o,
        couleur: widget.profil.couleur,
        bouton: bouton,
        estompe: etat == EtatObjet.equipe,
        onTap: () => _ouvrirFiche(o, etat, solde, maintenant),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.papier,
        foregroundColor: Palette.encre,
        elevation: 0,
        title: const Text('Marché', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _entete(moi, solde, maintenant),
          if (enCours.isNotEmpty) _cadeau(enCours.first, moi, maintenant),
          const SizedBox(height: 12),
          SegmentedButton<_Filtre>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Filtre.tout, label: Text('Tout')),
              ButtonSegment(value: _Filtre.avatars, label: Text('Avatars')),
              ButtonSegment(value: _Filtre.couvertures, label: Text('Couvertures')),
            ],
            selected: {_filtre},
            onSelectionChanged: (s) => setState(() => _filtre = s.first),
          ),
          for (final s in enCours) ...[
            _titreSection('SAISON EN COURS', '${s.nom} · ${s.theme}',
                'En vente jusqu\'au ${dateLongue(s.fin(maintenant))} (${s.joursRestants(maintenant) + 1} j restants)'),
            _grille(trier(tousLesObjets.where((o) => o.saison == s.id && !o.estGratuit)).map(carte).toList(), 'Rien dans cette catégorie.'),
          ],
          if (enCours.isEmpty) _titreSection('SAISON EN COURS', 'Aucune saison en vente', 'La prochaine est annoncée plus bas.'),
          _titreSection('MARCHÉ PERMANENT', 'Toujours en vente', 'Les classiques, disponibles toute l\'année.'),
          _grille(trier(permanents).map(carte).toList(), 'Rien dans cette catégorie.'),
          if (horsVente.isNotEmpty) ...[
            _titreSection('PROCHAINEMENT', 'Les prochaines saisons', 'Chaque saison revient chaque année, à la même période.'),
            for (final s in horsVente) _carteSaison(s, maintenant),
          ],
        ],
      ),
    );
  }

  Widget _bouton(Objet o, EtatObjet etat, int solde, DateTime maintenant, {bool ferme = false, BuildContext? contexte}) {
    void apres(VoidCallback action) {
      if (ferme && contexte != null) Navigator.pop(contexte);
      action();
    }

    return BoutonObjet(
      objet: o,
      etat: etat,
      solde: solde,
      maintenant: maintenant,
      nomSucces: o.succesRequis == null ? null : succes.where((s) => s.id == o.succesRequis).map((s) => s.nom).firstOrNull,
      onAcheter: () => apres(() => _acheter(o, solde)),
      onEquiper: () => apres(() => _equiper(o)),
    );
  }

  void _ouvrirFiche(Objet o, EtatObjet etat, int solde, DateTime maintenant) {
    final s = saisonPour(o.saison);
    final String comment;
    if (o.succesRequis != null) {
      final nom = succes.where((x) => x.id == o.succesRequis).map((x) => x.nom).firstOrNull ?? o.succesRequis;
      comment = 'Cet objet ne s\'achète pas : il se gagne en débloquant le succès « $nom ».';
    } else if (s != null) {
      comment = 'Collection « ${s.nom} ». En vente de ${plageMois(s.mois)}, chaque année. ${o.prix} Bulles.';
    } else if (o.prix > 0) {
      comment = 'Marché permanent : toujours en vente. ${o.prix} Bulles.';
    } else {
      comment = 'Objet gratuit.';
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.papier,
      builder: (contexte) => FicheObjet(
        objet: o,
        couleur: widget.profil.couleur,
        commentObtenir: comment,
        bouton: _bouton(o, etat, solde, maintenant, ferme: true, contexte: contexte),
        actionSecondaire: (etat == EtatObjet.possede || etat == EtatObjet.equipe)
            ? null
            : TextButton.icon(
                onPressed: () {
                  Navigator.pop(contexte);
                  _basculerFavori(o);
                },
                icon: Icon(_moi?['favori'] == o.id ? Icons.star : Icons.star_border, color: Palette.encre),
                label: Text(_moi?['favori'] == o.id ? 'Retirer de mes objectifs' : 'En faire mon objectif',
                    style: const TextStyle(color: Palette.encre, fontWeight: FontWeight.w700)),
              ),
      ),
    );
  }

  Widget _entete(Map<String, dynamic>? moi, int solde, DateTime maintenant) {
    final lundi = lundiDe(dateAujourdhui());
    final joursSemaine = ((moi?['joursConnexion'] as List?) ?? const []).whereType<String>().where((j) => j.compareTo(lundi) >= 0).toSet().length;
    final favoriId = moi?['favori'] as String?;
    final favori = favoriId == null ? null : tousLesObjets.where((o) => o.id == favoriId).firstOrNull;
    final favoriPossede = favori != null && ((moi?['achats'] as List?) ?? const []).contains(favori.id);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      color: Palette.encre,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bubble_chart, color: Palette.papier),
              const SizedBox(width: 10),
              Text('$solde Bulles', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Palette.papier)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            joursSemaine >= joursPourBonusSemaine
                ? 'Connexions de la semaine : $joursSemaine jours · bonus de la semaine obtenu'
                : 'Connexions de la semaine : $joursSemaine / $joursPourBonusSemaine jours · +$bonusConnexionSemaine Bulles au ${joursPourBonusSemaine}e jour',
            style: const TextStyle(fontSize: 12, color: Color(0xFFD8CFB8)),
          ),
          if (favori != null && !favoriPossede) ...[
            const SizedBox(height: 12),
            BarreObjectif(objet: favori, solde: solde, couleur: widget.profil.couleur, maintenant: maintenant, surMarche: true),
          ],
        ],
      ),
    );
  }

  Widget _cadeau(Saison s, Map<String, dynamic>? moi, DateTime maintenant) {
    final recupere = ((moi?['dotations'] as List?) ?? const []).contains(s.cleDotation(maintenant));
    if (recupere || moi == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Palette.papierClair, border: Border.all(color: Palette.vert, width: 2)),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Palette.vert),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Cadeau de la saison « ${s.nom} » : $dotationSaison Bulles',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.encre)),
          ),
          ElevatedButton(
            onPressed: () => _recupererCadeau(s),
            style: boutonPrincipal().copyWith(minimumSize: const WidgetStatePropertyAll(Size(110, 48))),
            child: const Text('RÉCUPÉRER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _titreSection(String etiquette, String titre, String sousTitre) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiquette, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Palette.encreFaible)),
          const SizedBox(height: 2),
          Text(titre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Palette.encre)),
          Text(sousTitre, style: const TextStyle(fontSize: 12, color: Palette.encreDouce)),
        ],
      ),
    );
  }

  Widget _grille(List<Widget> cartes, String vide) {
    if (cartes.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(vide, style: const TextStyle(color: Palette.encreFaible)));
    }
    return GrilleObjets(enfants: cartes);
  }

  /// Une saison hors vente : son nom, sa date de retour et, si elle a déjà
  /// existé, un aperçu de ses objets.
  Widget _carteSaison(Saison s, DateTime maintenant) {
    final objets = tousLesObjets.where((o) => o.saison == s.id).toList();
    final dejaSortie = !s.pasEncoreSortie(maintenant);
    final retour = s.prochainRetour(maintenant);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Palette.papierClair, border: Border.all(color: Palette.trait, width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.nom, style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.encre))),
              Icon(dejaSortie ? Icons.event_repeat : Icons.hourglass_empty, size: 18, color: Palette.encreDouce),
            ],
          ),
          Text(s.theme, style: const TextStyle(fontSize: 12, color: Palette.encreDouce)),
          const SizedBox(height: 6),
          Text(
            '${dejaSortie ? 'Revient' : 'Sort'} le ${dateLongue(retour)} · en vente de ${plageMois(s.mois)} · ${objets.length} objet${objets.length > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.encre),
          ),
          if (dejaSortie && objets.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final o in objets.where((o) => o.type == TypeObjet.avatar).take(8))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Opacity(opacity: 0.55, child: ApercuObjet(objet: o, couleur: widget.profil.couleur, taille: 44)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
