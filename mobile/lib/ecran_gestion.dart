import 'dart:async';

import 'package:flutter/material.dart';

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
    if (nom.isEmpty) return;
    _controleurNomPiece.clear();
    await creerPiece(widget.maisonId, nom);
  }

  Future<void> _renommerPiece(Map<String, dynamic> piece) async {
    final controleur = TextEditingController(text: piece['nom'] as String);
    final nouveauNom = await showDialog<String>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Renommer la pièce'),
        content: TextField(controller: controleur, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexte), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(contexte, controleur.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (nouveauNom == null || nouveauNom.isEmpty) return;
    await modifierPiece(widget.maisonId, piece['id'] as String, nouveauNom);
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
      await supprimerPiece(widget.maisonId, piece['id'] as String);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Palette.rouge),
      );
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
    await supprimerTache(widget.maisonId, tache['id'] as String);
  }

  Future<void> _ouvrirFormulaireTache(String pieceId, {Map<String, dynamic>? tacheExistante}) async {
    final resultat = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.papier,
      builder: (contexte) => _FormulaireTache(
        maisonId: widget.maisonId,
        pieceId: pieceId,
        tacheExistante: tacheExistante,
      ),
    );
    if (resultat == true && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
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
          Row(
            children: [
              Expanded(child: TextField(controller: _controleurNomPiece, decoration: decorationChamp('Cuisine'))),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _ajouterPiece,
                style: IconButton.styleFrom(backgroundColor: Palette.encre, shape: const RoundedRectangleBorder()),
                icon: const Icon(Icons.add, color: Palette.papier),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_pieces.isEmpty) const Text('Aucune pièce pour l\'instant.', style: TextStyle(color: Palette.encreDouce)),
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
    final frequence = int.tryParse(_frequence.text.trim());
    if (nom.isEmpty || frequence == null || frequence < 1) return;

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
    if (mounted) Navigator.pop(context, true);
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
            const SizedBox(height: 16),
            const Text('Nom', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
            const SizedBox(height: 4),
            TextField(controller: _nom, decoration: decorationChamp("Nettoyer l'évier")),
            const SizedBox(height: 12),
            const Text('Fréquence (jours)', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
            const SizedBox(height: 4),
            TextField(controller: _frequence, keyboardType: TextInputType.number, decoration: decorationChamp('7')),
            const SizedBox(height: 12),
            const Text('Produit', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
            const SizedBox(height: 4),
            TextField(controller: _produit, decoration: decorationChamp('Liquide vaisselle')),
            const SizedBox(height: 12),
            const Text('Ustensile', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
            const SizedBox(height: 4),
            TextField(controller: _ustensile, decoration: decorationChamp('Microfibre')),
            const SizedBox(height: 12),
            const Text('Astuce', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
            const SizedBox(height: 4),
            TextField(controller: _astuce, minLines: 1, maxLines: 6, decoration: decorationChamp('Rincer et sécher')),
            const SizedBox(height: 12),
            const Text('À éviter', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
            const SizedBox(height: 4),
            TextField(controller: _aEviter, minLines: 1, maxLines: 3, decoration: decorationChamp('Javel')),
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
            ElevatedButton(
              onPressed: _enregistrer,
              style: boutonPrincipal(),
              child: const Text('ENREGISTRER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }
}
