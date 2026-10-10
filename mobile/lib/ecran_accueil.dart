import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'donnees.dart';
import 'jeu.dart';
import 'ecran_parametres.dart';
import 'navigation.dart';
import 'palette.dart';
import 'stockage_local.dart';

/// Accueil = la seule page des tâches (retour de Kinder du 2026-09-10,
/// § 19) : trois blocs repliables À faire / Fait / À venir, "Fait" en un
/// geste depuis ici, fiche détail au toucher. L'ancien écran "À faire"
/// séparé faisait doublon et a été supprimé. Une tâche jamais faite est
/// simplement "à faire" : il n'y a plus de statut "jamais renseignée"
/// affiché.
class EcranAccueil extends StatefulWidget {
  const EcranAccueil({super.key, required this.profil, required this.maisonId});

  final Profil profil;
  final String maisonId;

  @override
  State<EcranAccueil> createState() => _EcranAccueilState();
}

class _EnAttente {
  _EnAttente({required this.tache, required this.forcerEnregistrement, required this.annuler});
  final Map<String, dynamic> tache;
  final VoidCallback forcerEnregistrement;
  final VoidCallback annuler;
}

class _EcranAccueilState extends State<EcranAccueil> {
  static const _delaiAnnulation = Duration(seconds: 5);

  Map<String, dynamic>? _maison;
  Object? _erreur;

  List<Map<String, dynamic>>? _taches;
  List<Map<String, dynamic>> _pieces = [];
  List<Map<String, dynamic>> _membres = [];
  List<Map<String, dynamic>> _realisations = [];
  final List<StreamSubscription> _abonnements = [];

  // Le "Fait" est différé de quelques secondes pour permettre l'annulation
  // sans jamais écrire puis effacer (décision du 2026-09-08, § 15 point 4).
  final Map<String, _EnAttente> _enAttente = {};
  bool _enFermeture = false;

  bool _ouvertAFaire = true;
  bool _ouvertFait = true;
  bool _ouvertAVenir = false;

  @override
  void initState() {
    super.initState();
    _chargerOuSignaler();
  }

  /// `_charger` sans jamais laisser l'écran tourner sans fin : un échec de
  /// lecture s'affiche avec un bouton « Réessayer ».
  void _chargerOuSignaler() {
    _charger().catchError((Object e) {
      if (mounted) setState(() => _erreur = e);
    });
  }

  Future<void> _charger() async {
    final maison = await chargerMaison(widget.maisonId);
    final mesMaisons = maison == null ? const [] : await chargerMesMaisons([widget.maisonId], widget.profil.id);
    if (!mounted) return;
    if (maison == null || mesMaisons.isEmpty) {
      // Maison supprimée par un autre membre, ou on en a été retiré : on
      // l'oublie et on passe à la maison suivante de l'appareil, s'il y en a.
      final prefs = await SharedPreferences.getInstance();
      await retirerMaisonLocale(prefs, widget.maisonId);
      if (!mounted) return;
      await ouvrirMaisonCourante(context, widget.profil);
      return;
    }
    setState(() => _maison = maison);

    void surErreur(Object e) {
      if (mounted) setState(() => _erreur = e);
    }

    _abonnements.addAll([
      ecouterTaches(widget.maisonId).listen((t) {
        if (mounted) setState(() => _taches = t);
      }, onError: surErreur),
      ecouterPieces(widget.maisonId).listen((p) {
        if (mounted) setState(() => _pieces = p);
      }, onError: surErreur),
      ecouterMembres(widget.maisonId).listen((m) {
        if (mounted) setState(() => _membres = m);
      }, onError: surErreur),
      ecouterRealisations(widget.maisonId).listen((r) {
        if (mounted) setState(() => _realisations = r);
      }, onError: surErreur),
    ]);
  }

  @override
  void dispose() {
    // Un "Fait" en attente doit tout de même s'enregistrer si on quitte
    // l'écran avant la fin du délai — sinon un geste réel se perdrait.
    // Copie de la liste : enregistrer() retire l'entrée pendant le parcours.
    _enFermeture = true;
    for (final entree in _enAttente.values.toList()) {
      entree.forcerEnregistrement();
    }
    for (final a in _abonnements) {
      a.cancel();
    }
    super.dispose();
  }

  void _signaler(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Palette.rouge),
    );
  }

  void _cocher(Map<String, dynamic> tache) {
    final tacheId = tache['id'] as String;
    if (_enAttente.containsKey(tacheId)) return;

    final aujourdhui = dateAujourdhui();
    final prochaineEcheance = ajouterJours(aujourdhui, tache['frequenceJours'] as int);

    var enregistre = false;
    late final Timer minuteur;

    void enregistrer() {
      if (enregistre) return;
      enregistre = true;
      _enAttente.remove(tacheId);
      if (mounted && !_enFermeture) setState(() {});
      enregistrerRealisation(widget.maisonId, tacheId, widget.profil.id, aujourdhui, prochaineEcheance, xp: xpPourTache(tache)).catchError((Object e) {
        if (mounted && !_enFermeture) _signaler('« ${tache['nom']} » n\'a pas pu être enregistrée comme faite. ${texteErreur(e)}');
      });
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

    // Le bloc "Fait" peut être loin en bas quand la liste "À faire" est
    // longue : l'annulation doit rester à portée de pouce, où qu'on soit.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('« ${tache['nom']} » faite'),
        duration: _delaiAnnulation,
        persist: false,
        action: SnackBarAction(label: 'ANNULER', onPressed: () => _enAttente[tacheId]?.annuler()),
      ));
  }

  void _ouvrirParametres() {
    final maison = _maison!;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EcranParametres(
          profil: widget.profil,
          maisonId: widget.maisonId,
          maisonNom: maison['nom'] as String,
          codeInvitation: maison['codeInvitation'] as String,
        ),
      ),
    );
  }

  // ------------------------------------------------------------ calculs

  String _nomPiece(Map<String, dynamic> t) {
    for (final p in _pieces) {
      if (p['id'] == t['pieceId']) return p['nom'] as String;
    }
    return '';
  }

  String? _prenomMembre(String? id) {
    for (final m in _membres) {
      if (m['id'] == id) return m['prenom'] as String;
    }
    return null;
  }

  /// Dernière réalisation connue d'une tâche (les 100 plus récentes de la
  /// maison sont écoutées, triées de la plus récente à la plus ancienne).
  Map<String, dynamic>? _derniereRealisation(String tacheId) {
    for (final r in _realisations) {
      if (r['tacheId'] == tacheId) return r;
    }
    return null;
  }

  int _joursEntre(String de, String a) {
    DateTime lire(String s) {
      final x = s.split('-').map(int.parse).toList();
      // UTC : un passage à l'heure d'été ne doit pas fausser le décompte.
      return DateTime.utc(x[0], x[1], x[2]);
    }

    return lire(a).difference(lire(de)).inDays;
  }

  String _dateCourte(String iso) {
    final x = iso.split('-');
    final annee = DateTime.now().year.toString() == x[0] ? '' : '/${x[0]}';
    return '${x[2]}/${x[1]}$annee';
  }

  // -------------------------------------------------------------- écran

  @override
  Widget build(BuildContext context) {
    if (_maison == null) {
      if (_erreur != null) return Scaffold(body: SafeArea(child: _contenu()));
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Palette.encre)));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bonjour ${widget.profil.prenom}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.5, color: Palette.encreFaible),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _ouvrirParametres,
                    icon: const Icon(Icons.settings_outlined, size: 16, color: Palette.encreDouce),
                    label: const Text('Paramètres', style: TextStyle(color: Palette.encreDouce)),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(22, 4, 22, 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: Palette.encre,
              child: Text(
                _maison!['nom'] as String,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Palette.papier),
              ),
            ),
            Expanded(child: _contenu()),
          ],
        ),
      ),
    );
  }

  Widget _contenu() {
    if (_erreur != null) {
      return Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Impossible d\'afficher les tâches', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Palette.encre)),
            const SizedBox(height: 8),
            Text(texteErreur(_erreur!), style: const TextStyle(color: Palette.rouge)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                for (final a in _abonnements) {
                  a.cancel();
                }
                _abonnements.clear();
                setState(() => _erreur = null);
                _chargerOuSignaler();
              },
              style: boutonSecondaire(),
              child: const Text('RÉESSAYER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ],
        ),
      );
    }
    final taches = _taches;
    if (taches == null) {
      return const Center(child: CircularProgressIndicator(color: Palette.encre));
    }
    if (taches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(22),
        child: Text(
          'Aucune tâche pour l\'instant. Ajoutez-en depuis Paramètres → Pièces et tâches.',
          style: TextStyle(color: Palette.encreDouce),
        ),
      );
    }

    final aujourdhui = dateAujourdhui();
    final faitesAujourdhui = <String, Map<String, dynamic>>{};
    for (final r in _realisations) {
      if (r['dateRealisation'] == aujourdhui) {
        faitesAujourdhui.putIfAbsent(r['tacheId'] as String, () => r);
      }
    }

    final aFaire = <Map<String, dynamic>>[];
    final fait = <Map<String, dynamic>>[];
    final aVenir = <Map<String, dynamic>>[];

    for (final t in taches) {
      final id = t['id'] as String;
      if (_enAttente.containsKey(id) || faitesAujourdhui.containsKey(id)) {
        fait.add(t);
      } else if (statutTache(t) == 'avenir') {
        aVenir.add(t);
      } else {
        aFaire.add(t);
      }
    }

    int rangAFaire(Map<String, dynamic> t) => switch (statutTache(t)) {
          'retard' => 0,
          'aujourdhui' => 1,
          _ => 2,
        };

    // Départage final par pièce puis par nom : le tri de Dart n'est pas
    // stable, sans ça les lignes changent d'ordre à chaque mise à jour et
    // "sautent" sous le doigt au moment de cocher.
    int parPieceEtNom(Map<String, dynamic> a, Map<String, dynamic> b) {
      final p = _nomPiece(a).compareTo(_nomPiece(b));
      if (p != 0) return p;
      return (a['nom'] as String).compareTo(b['nom'] as String);
    }

    aFaire.sort((a, b) {
      final r = rangAFaire(a).compareTo(rangAFaire(b));
      if (r != 0) return r;
      final ea = a['prochaineEcheance'] as String? ?? '';
      final eb = b['prochaineEcheance'] as String? ?? '';
      final e = ea.compareTo(eb);
      if (e != 0) return e;
      return parPieceEtNom(a, b);
    });
    aVenir.sort((a, b) {
      final e = (a['prochaineEcheance'] as String).compareTo(b['prochaineEcheance'] as String);
      return e != 0 ? e : parPieceEtNom(a, b);
    });
    fait.sort(parPieceEtNom);

    final enRetard = aFaire.where((t) => statutTache(t) == 'retard').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      children: [
        _bloc(
          titre: enRetard > 0 ? 'À faire · $enRetard en retard' : 'À faire',
          nombre: aFaire.length,
          couleur: enRetard > 0 ? Palette.rouge : Palette.encre,
          ouvert: _ouvertAFaire,
          basculer: () => setState(() => _ouvertAFaire = !_ouvertAFaire),
          vide: 'Rien à faire pour l\'instant. 🎉',
          lignes: aFaire.map(_ligneAFaire).toList(),
        ),
        _bloc(
          titre: 'Fait aujourd\'hui',
          nombre: fait.length,
          couleur: Palette.vert,
          ouvert: _ouvertFait,
          basculer: () => setState(() => _ouvertFait = !_ouvertFait),
          vide: 'Rien de coché aujourd\'hui.',
          lignes: fait.map((t) => _ligneFait(t, faitesAujourdhui[t['id']])).toList(),
        ),
        _bloc(
          titre: 'À venir',
          nombre: aVenir.length,
          couleur: Palette.encreDouce,
          ouvert: _ouvertAVenir,
          basculer: () => setState(() => _ouvertAVenir = !_ouvertAVenir),
          vide: 'Rien de prévu.',
          lignes: aVenir.map(_ligneAVenir).toList(),
        ),
      ],
    );
  }

  Widget _bloc({
    required String titre,
    required int nombre,
    required Color couleur,
    required bool ouvert,
    required VoidCallback basculer,
    required String vide,
    required List<Widget> lignes,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: basculer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: couleur,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${titre.toUpperCase()}  ($nombre)',
                      style: const TextStyle(color: Palette.papier, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                    ),
                  ),
                  Icon(ouvert ? Icons.expand_less : Icons.expand_more, color: Palette.papier, size: 20),
                ],
              ),
            ),
          ),
          if (ouvert)
            if (lignes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(vide, style: const TextStyle(color: Palette.encreDouce)),
              )
            else
              ...lignes,
        ],
      ),
    );
  }

  Widget _ligne(
    Map<String, dynamic> t, {
    required String sousTitre,
    Color couleurSousTitre = Palette.encreDouce,
    required Widget action,
    bool caseAppuyee = false,
  }) {
    return InkWell(
      onTap: () => _ouvrirFiche(t),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Palette.papierClair,
                border: Border.all(color: caseAppuyee ? Palette.encre : Palette.trait, width: caseAppuyee ? 2.5 : 1),
              ),
              child: Text((t['emoji'] as String?) ?? emojiParDefaut, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['nom'] as String, style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.encre)),
                  if (sousTitre.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(sousTitre, style: TextStyle(fontSize: 12, color: couleurSousTitre)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            action,
          ],
        ),
      ),
    );
  }

  Widget _bouton(String texte, VoidCallback surAppui) {
    return OutlinedButton(
      onPressed: surAppui,
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.encre,
        side: const BorderSide(color: Palette.encre, width: 1.5),
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(texte, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _ligneAFaire(Map<String, dynamic> t) {
    final piece = _nomPiece(t);
    final statut = statutTache(t);
    var sousTitre = piece;
    var couleur = Palette.encreDouce;
    if (statut == 'retard') {
      final jours = _joursEntre(t['prochaineEcheance'] as String, dateAujourdhui());
      sousTitre = 'En retard de $jours j · $piece';
      couleur = Palette.rouge;
    } else if (statut == 'aujourdhui') {
      sousTitre = 'Aujourd\'hui · $piece';
    }
    return _ligne(t, sousTitre: sousTitre, couleurSousTitre: couleur, caseAppuyee: true, action: _bouton('FAIT', () => _cocher(t)));
  }

  Widget _ligneFait(Map<String, dynamic> t, Map<String, dynamic>? realisation) {
    final enAttente = _enAttente[t['id']];
    if (enAttente != null) {
      return _ligne(t, sousTitre: 'Fait · +${xpPourTache(t)} XP · annulable quelques secondes', action: _bouton('ANNULER', enAttente.annuler));
    }
    final par = _prenomMembre(realisation?['realiseParId'] as String?);
    final piece = _nomPiece(t);
    return _ligne(
      t,
      sousTitre: par != null ? 'Fait par $par · $piece' : piece,
      couleurSousTitre: Palette.vert,
      action: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Icon(Icons.check, color: Palette.vert),
      ),
    );
  }

  Widget _ligneAVenir(Map<String, dynamic> t) {
    final echeance = t['prochaineEcheance'] as String;
    final jours = _joursEntre(dateAujourdhui(), echeance);
    final quand = jours == 1 ? 'Demain' : 'Dans $jours j';
    // Toujours cochable, même en avance (D7, règle héritée de la V1).
    return _ligne(t, sousTitre: '$quand · ${_nomPiece(t)}', action: _bouton('FAIT', () => _cocher(t)));
  }

  // -------------------------------------------------------- fiche tâche

  void _ouvrirFiche(Map<String, dynamic> t) {
    final id = t['id'] as String;
    final frequence = t['frequenceJours'] as int;
    final echeance = t['prochaineEcheance'] as String?;
    final produit = (t['produit'] as String?) ?? '';
    final astuce = (t['astuce'] as String?) ?? '';
    final ustensile = (t['ustensile'] as String?) ?? '';
    final aEviter = (t['aEviter'] as String?) ?? '';
    final duree = t['dureeMinutes'] as int?;
    final reserves = t['fiabilite'] == 'limites';
    final derniere = _derniereRealisation(id);
    final dateDerniere = (derniere?['dateRealisation'] as String?) ?? (echeance != null ? ajouterJours(echeance, -frequence) : null);
    final parDerniere = _prenomMembre(derniere?['realiseParId'] as String?);
    final dejaFaite = _enAttente.containsKey(id) || derniere?['dateRealisation'] == dateAujourdhui();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.papier,
      builder: (contexte) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Palette.papierClair, border: Border.all(color: Palette.encre, width: 2)),
                    child: Text((t['emoji'] as String?) ?? emojiParDefaut, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['nom'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.encre)),
                        const SizedBox(height: 2),
                        Text(_nomPiece(t), style: const TextStyle(color: Palette.encreDouce)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _info('Fréquence', 'Tous les $frequence j'),
              _info(
                'Dernière fois',
                dateDerniere == null ? 'Jamais' : '${_dateCourte(dateDerniere)}${parDerniere != null ? ' par $parDerniere' : ''}',
              ),
              _info('Prochaine fois', echeance == null ? 'Dès que possible' : _dateCourte(echeance)),
              if (duree != null) _info('Durée', '$duree min'),
              if (produit.isNotEmpty) _encart('Produit', produit),
              if (ustensile.isNotEmpty) _encart('Ustensile', ustensile),
              if (astuce.isNotEmpty) _encart('Astuce', astuce),
              if (aEviter.isNotEmpty) _encart('À éviter', aEviter),
              if (reserves)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Méthode à nuancer : son efficacité dépend de votre matériel.',
                      style: TextStyle(color: Palette.encreFaible, fontSize: 12)),
                ),
              if (produit.isEmpty && astuce.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Pas de produit ni d\'astuce renseignés. Modifiables dans Paramètres → Pièces et tâches.',
                    style: TextStyle(color: Palette.encreFaible, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 20),
              if (!dejaFaite)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(contexte);
                    _cocher(t);
                  },
                  style: boutonPrincipal(),
                  child: const Text('C\'EST FAIT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                )
              else ...[
                const Text('✓ Déjà faite aujourd\'hui', textAlign: TextAlign.center, style: TextStyle(color: Palette.vert, fontWeight: FontWeight.w600)),
                // Revenir sur une tâche cochée par erreur, sans passer par
                // l'Historique (retour de Kinder du 2026-09-10, § 19).
                if (derniere != null && !_enAttente.containsKey(id))
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(contexte);
                      try {
                        await supprimerRealisation(widget.maisonId, derniere['id'] as String, id);
                      } catch (e) {
                        if (mounted) _signaler('La tâche n\'a pas pu être remise à faire. ${texteErreur(e)}');
                      }
                    },
                    child: const Text('Finalement pas faite — annuler', style: TextStyle(color: Palette.encreDouce)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(String libelle, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(libelle, style: const TextStyle(color: Palette.encreDouce))),
          Expanded(child: Text(valeur, style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.encre))),
        ],
      ),
    );
  }

  Widget _encart(String libelle, String texte) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Palette.papierClair, border: Border.all(color: Palette.trait)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(libelle.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Palette.encreFaible)),
          const SizedBox(height: 4),
          Text(texte, style: const TextStyle(color: Palette.encre)),
        ],
      ),
    );
  }
}
