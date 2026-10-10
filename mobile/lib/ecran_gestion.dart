import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'donnees.dart';
import 'palette.dart';

/// Écran "Pièces et tâches" — équivalent Flutter de `afficherEcranGestion`
/// (public/v2/js/app.js) : créer/renommer/supprimer une pièce, créer/
/// modifier/supprimer une tâche (avec sélecteur d'emoji). L'export de
/// structure en .json (fonctionnalité secondaire de la V2) n'est pas repris
/// ici, laissé pour les finitions (étape 7) si besoin.
class EcranGestion extends StatefulWidget {
  const EcranGestion({super.key, required this.maisonId});

  final String maisonId;

  @override
  State<EcranGestion> createState() => _EcranGestionState();
}

class _EcranGestionState extends State<EcranGestion> {
  List<Map<String, dynamic>> _pieces = [];
  List<Map<String, dynamic>> _taches = [];
  StreamSubscription? _subPieces;
  StreamSubscription? _subTaches;
  final _controleurNomPiece = TextEditingController();
  String? _erreurPiece;
  // Pièces et tâches dont les boutons d'actions sont déroulés.
  final Set<String> _deroules = {};

  void _basculer(String id) => setState(() => _deroules.contains(id) ? _deroules.remove(id) : _deroules.add(id));

  /// Boutons d'actions déroulés sous une entrée : larges et espacés, pour ne
  /// pas confondre « Modifier » et « Supprimer ».
  Widget _actions({required String libelleModifier, required VoidCallback onModifier, required VoidCallback onSupprimer}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onModifier,
              style: boutonSecondaire().copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44))),
              child: Text(libelleModifier, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: OutlinedButton(
              onPressed: onSupprimer,
              style: boutonSecondaire().copyWith(
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
                foregroundColor: const WidgetStatePropertyAll(Palette.rouge),
              ),
              child: const Text('SUPPRIMER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _subPieces = ecouterPieces(widget.maisonId).listen((p) {
      if (mounted) setState(() => _pieces = p);
    });
    _subTaches = ecouterTaches(widget.maisonId).listen((t) {
      if (mounted) setState(() => _taches = t);
    });
  }

  @override
  void dispose() {
    _subPieces?.cancel();
    _subTaches?.cancel();
    _controleurNomPiece.dispose();
    super.dispose();
  }

  Future<void> _ajouterPiece() async {
    final nom = _controleurNomPiece.text.trim();
    if (nom.isEmpty) {
      setState(() => _erreurPiece = "Écrivez le nom de la pièce avant d'appuyer sur + (ex. : Cuisine, Salle de bain).");
      return;
    }
    setState(() => _erreurPiece = null);
    try {
      await ecrire(creerPiece(widget.maisonId, nom));
      _controleurNomPiece.clear();
      if (mounted) signalerSucces(context, 'Pièce « $nom » ajoutée. Ajoutez-y des tâches avec « + AJOUTER UNE TÂCHE ».');
    } on TimeoutException catch (e) {
      _controleurNomPiece.clear();
      if (mounted) signalerErreur(context, e);
    } catch (e) {
      if (mounted) signalerErreur(context, e);
    }
  }

  Future<void> _renommerPiece(Map<String, dynamic> piece) async {
    final controleur = TextEditingController(text: piece['nom'] as String);
    String? erreur;
    final nouveauNom = await showDialog<String>(
      context: context,
      builder: (contexte) => StatefulBuilder(
        builder: (contexte, setStateDialogue) => AlertDialog(
          title: const Text('Renommer la pièce'),
          content: TextField(
            controller: controleur,
            autofocus: true,
            onChanged: (_) {
              if (erreur != null) setStateDialogue(() => erreur = null);
            },
            decoration: decorationChamp('ex. : Cuisine', erreur: erreur),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(contexte), child: const Text('Annuler')),
            TextButton(
              onPressed: () {
                final nom = controleur.text.trim();
                if (nom.isEmpty) {
                  setStateDialogue(() => erreur = 'Le nom ne peut pas être vide.');
                  return;
                }
                Navigator.pop(contexte, nom);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (nouveauNom == null || nouveauNom == piece['nom']) return;
    try {
      await ecrire(modifierPiece(widget.maisonId, piece['id'] as String, nouveauNom));
      if (mounted) signalerSucces(context, 'Pièce renommée en « $nouveauNom ».');
    } catch (e) {
      if (mounted) signalerErreur(context, e);
    }
  }

  Future<void> _supprimerPiece(Map<String, dynamic> piece) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Supprimer cette pièce ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexte, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(contexte, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await ecrire(supprimerPiece(widget.maisonId, piece['id'] as String));
      if (mounted) signalerSucces(context, 'Pièce « ${piece['nom']} » supprimée.');
    } catch (e) {
      if (mounted) signalerErreur(context, e);
    }
  }

  Future<void> _supprimerTache(Map<String, dynamic> tache) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Supprimer cette tâche ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexte, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(contexte, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await ecrire(supprimerTache(widget.maisonId, tache['id'] as String));
      if (mounted) signalerSucces(context, 'Tâche « ${tache['nom']} » supprimée. Son historique est conservé.');
    } catch (e) {
      if (mounted) signalerErreur(context, e);
    }
  }

  Future<void> _ouvrirFormulaireTache(String pieceId, {Map<String, dynamic>? tacheExistante}) async {
    // La feuille renvoie le message à afficher une fois fermée (succès ou
    // « hors connexion »), null si l'utilisateur l'a refermée sans enregistrer.
    final resultat = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.papier,
      builder: (contexte) => _FormulaireTache(
        maisonId: widget.maisonId,
        pieceId: pieceId,
        tacheExistante: tacheExistante,
      ),
    );
    if (resultat != null && mounted) signalerSucces(context, resultat);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.papier,
        foregroundColor: Palette.encre,
        elevation: 0,
        title: const Text('Pièces et tâches', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
        children: [
          libelleChamp('Nouvelle pièce', obligatoire: true),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _controleurNomPiece,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) {
                    if (_erreurPiece != null) setState(() => _erreurPiece = null);
                  },
                  onSubmitted: (_) => _ajouterPiece(),
                  decoration: decorationChamp('ex. : Cuisine', aide: 'Écrivez le nom, puis appuyez sur +.', erreur: _erreurPiece),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _ajouterPiece,
                tooltip: 'Ajouter la pièce',
                style: IconButton.styleFrom(backgroundColor: Palette.encre, shape: const RoundedRectangleBorder(), minimumSize: const Size(52, 52)),
                icon: const Icon(Icons.add, color: Palette.papier),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_pieces.isEmpty)
            const Text(
              "Aucune pièce pour l'instant. Commencez par créer une pièce : les tâches se rangent ensuite dedans.",
              style: TextStyle(color: Palette.encreDouce),
            ),
          for (final piece in _pieces) _cartePiece(piece),
        ],
      ),
    );
  }

  Widget _cartePiece(Map<String, dynamic> piece) {
    final tachesPiece = _taches.where((t) => t['pieceId'] == piece['id']).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _basculer(piece['id'] as String),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(piece['nom'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Palette.encre)),
                  ),
                  Icon(_deroules.contains(piece['id']) ? Icons.expand_less : Icons.expand_more, color: Palette.encreDouce),
                ],
              ),
            ),
          ),
          if (_deroules.contains(piece['id']))
            _actions(
              libelleModifier: 'RENOMMER',
              onModifier: () => _renommerPiece(piece),
              onSupprimer: () => _supprimerPiece(piece),
            ),
          if (tachesPiece.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Aucune tâche.', style: TextStyle(color: Palette.encreFaible, fontSize: 13)),
            )
          else
            for (final tache in tachesPiece) _ligneTache(tache),
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: () => _ouvrirFormulaireTache(piece['id'] as String),
            style: boutonSecondaire().copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44))),
            child: const Text('+ AJOUTER UNE TÂCHE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
          ),
          const Divider(color: Palette.encre, thickness: 2, height: 32),
        ],
      ),
    );
  }

  Widget _ligneTache(Map<String, dynamic> tache) {
    final sousTitre = [
      'Tous les ${tache['frequenceJours']} j',
      if ((tache['produit'] as String?)?.isNotEmpty ?? false) tache['produit'] as String,
    ].join(' · ');
    final astuce = tache['astuce'] as String?;

    final ouvert = _deroules.contains(tache['id']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _basculer(tache['id'] as String),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Palette.papierClair, border: Border.all(color: Palette.trait)),
                  child: Text((tache['emoji'] as String?) ?? emojiParDefaut, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tache['nom'] as String, style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.encre)),
                      Text(sousTitre, style: const TextStyle(fontSize: 11, color: Palette.encreDouce)),
                      if (astuce != null && astuce.isNotEmpty)
                        Text(astuce, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Palette.encreFaible)),
                    ],
                  ),
                ),
                Icon(ouvert ? Icons.expand_less : Icons.expand_more, color: Palette.encreDouce),
              ],
            ),
          ),
          if (ouvert)
            _actions(
              libelleModifier: 'MODIFIER',
              onModifier: () => _ouvrirFormulaireTache(tache['pieceId'] as String, tacheExistante: tache),
              onSupprimer: () => _supprimerTache(tache),
            ),
        ],
      ),
    );
  }
}

/// Formulaire (dans une feuille modale) pour créer ou modifier une tâche :
/// nom, fréquence, produit, astuce, sélecteur d'emoji.
class _FormulaireTache extends StatefulWidget {
  const _FormulaireTache({required this.maisonId, required this.pieceId, this.tacheExistante});

  final String maisonId;
  final String pieceId;
  final Map<String, dynamic>? tacheExistante;

  @override
  State<_FormulaireTache> createState() => _FormulaireTacheState();
}

class _FormulaireTacheState extends State<_FormulaireTache> {
  late final _nom = TextEditingController(text: widget.tacheExistante?['nom'] as String? ?? '');
  late final _frequence = TextEditingController(
    text: widget.tacheExistante != null ? '${widget.tacheExistante!['frequenceJours']}' : '',
  );
  late final _produit = TextEditingController(text: widget.tacheExistante?['produit'] as String? ?? '');
  late final _astuce = TextEditingController(text: widget.tacheExistante?['astuce'] as String? ?? '');
  late final _ustensile = TextEditingController(text: widget.tacheExistante?['ustensile'] as String? ?? '');
  late final _aEviter = TextEditingController(text: widget.tacheExistante?['aEviter'] as String? ?? '');
  late String _emoji = widget.tacheExistante?['emoji'] as String? ?? emojiParDefaut;
  String? _erreurNom;
  String? _erreurFrequence;
  // Message au-dessus du bouton : champs à corriger ou échec d'enregistrement.
  String? _erreurGlobale;
  bool _enCours = false;

  @override
  void dispose() {
    _nom.dispose();
    _frequence.dispose();
    _produit.dispose();
    _astuce.dispose();
    _ustensile.dispose();
    _aEviter.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final nom = _nom.text.trim();
    final texteFrequence = _frequence.text.trim();
    final frequence = int.tryParse(texteFrequence);
    final erreurNom = nom.isEmpty ? "Donnez un nom à la tâche (ex. : Nettoyer l'évier)." : null;
    final String? erreurFrequence;
    if (texteFrequence.isEmpty) {
      erreurFrequence = 'Indiquez tous les combien de jours revient la tâche (ex. : 7 pour chaque semaine).';
    } else if (frequence == null) {
      erreurFrequence = 'Entrez un nombre de jours, en chiffres uniquement (ex. : 7).';
    } else if (frequence < 1) {
      erreurFrequence = 'Au minimum 1 jour (1 = tous les jours).';
    } else if (frequence > 365) {
      erreurFrequence = 'Au maximum 365 jours (une fois par an).';
    } else {
      erreurFrequence = null;
    }
    if (erreurNom != null || erreurFrequence != null) {
      final aVerifier = [if (erreurNom != null) 'le nom', if (erreurFrequence != null) 'la fréquence'];
      setState(() {
        _erreurNom = erreurNom;
        _erreurFrequence = erreurFrequence;
        _erreurGlobale = "Impossible d'enregistrer : vérifiez ${aVerifier.join(' et ')} (en rouge plus haut).";
      });
      return;
    }

    setState(() {
      _enCours = true;
      _erreurGlobale = null;
    });
    final creation = widget.tacheExistante == null;
    try {
      await ecrire(_ecrireTache(nom, frequence!));
    } on TimeoutException {
      if (mounted) Navigator.pop(context, messageHorsConnexion);
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _enCours = false;
          _erreurGlobale = 'Enregistrement impossible. ${texteErreur(e)}';
        });
      }
      return;
    }
    if (mounted) Navigator.pop(context, creation ? 'Tâche « $nom » ajoutée.' : 'Tâche « $nom » modifiée.');
  }

  Future<void> _ecrireTache(String nom, int frequence) async {
    if (widget.tacheExistante == null) {
      await creerTache(
        widget.maisonId,
        nom: nom,
        pieceId: widget.pieceId,
        frequenceJours: frequence,
        produit: _produit.text.trim(),
        astuce: _astuce.text.trim(),
        emoji: _emoji,
        ustensile: _ustensile.text.trim(),
        aEviter: _aEviter.text.trim(),
      );
    } else {
      await modifierTache(
        widget.maisonId,
        widget.tacheExistante!['id'] as String,
        nom: nom,
        frequenceJours: frequence,
        produit: _produit.text.trim(),
        astuce: _astuce.text.trim(),
        emoji: _emoji,
        ustensile: _ustensile.text.trim(),
        aEviter: _aEviter.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.tacheExistante == null ? 'Ajouter une tâche' : 'Modifier la tâche',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.encre),
            ),
            const SizedBox(height: 4),
            const Text(
              'Seuls le nom et la fréquence sont obligatoires. Le reste aide les autres membres à bien faire la tâche.',
              style: TextStyle(fontSize: 12, color: Palette.encreFaible),
            ),
            const SizedBox(height: 16),
            libelleChamp('Nom', obligatoire: true),
            const SizedBox(height: 4),
            TextField(
              controller: _nom,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_erreurNom != null) setState(() => _erreurNom = null);
              },
              decoration: decorationChamp("ex. : Nettoyer l'évier", erreur: _erreurNom),
            ),
            const SizedBox(height: 12),
            libelleChamp('Fréquence (en jours)', obligatoire: true),
            const SizedBox(height: 4),
            TextField(
              controller: _frequence,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                if (_erreurFrequence != null) setState(() => _erreurFrequence = null);
              },
              decoration: decorationChamp(
                'ex. : 7',
                aide: 'Tous les combien de jours ? 1 = chaque jour, 7 = chaque semaine, 30 = chaque mois.',
                erreur: _erreurFrequence,
              ),
            ),
            const SizedBox(height: 12),
            libelleChamp('Produit'),
            const SizedBox(height: 4),
            TextField(controller: _produit, decoration: decorationChamp('ex. : Liquide vaisselle')),
            const SizedBox(height: 12),
            libelleChamp('Ustensile'),
            const SizedBox(height: 4),
            TextField(controller: _ustensile, decoration: decorationChamp('ex. : Microfibre')),
            const SizedBox(height: 12),
            libelleChamp('Astuce'),
            const SizedBox(height: 4),
            TextField(controller: _astuce, minLines: 1, maxLines: 6, decoration: decorationChamp('ex. : Rincer et sécher')),
            const SizedBox(height: 12),
            libelleChamp('À éviter'),
            const SizedBox(height: 4),
            TextField(controller: _aEviter, minLines: 1, maxLines: 3, decoration: decorationChamp('ex. : Javel')),
            const SizedBox(height: 12),
            const Text('Pictogramme', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: emojiTaches.map((e) {
                final choisi = e == _emoji;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Palette.papierClair,
                      border: Border.all(color: choisi ? Palette.encre : Palette.trait, width: choisi ? 2.5 : 1.5),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 18)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            if (_erreurGlobale != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: Palette.rouge, width: 2)),
                child: Text(_erreurGlobale!, style: const TextStyle(color: Palette.rouge, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
            ],
            ElevatedButton(
              onPressed: _enCours ? null : _enregistrer,
              style: boutonPrincipal(),
              child: _enCours
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Palette.papier))
                  : const Text('ENREGISTRER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }
}
