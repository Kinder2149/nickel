import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'donnees.dart';
import 'ecran_afaire.dart';
import 'ecran_gestion.dart';
import 'ecran_historique.dart';
import 'ecran_maison.dart';
import 'palette.dart';
import 'stockage_local.dart';

/// Écran "Paramètres" — équivalent Flutter de `afficherEcranParametres`
/// (public/v2/js/app.js, § 17 point B) : regroupe "Voir toutes les
/// tâches", "Historique", "Pièces et tâches", la liste des membres (avec
/// "Retirer"), le rappel du code d'invitation, et "Quitter cette maison".
/// Ça libère l'accueil, qui ne garde que la carte de la maison et le
/// tableau de bord des tâches urgentes.
class EcranParametres extends StatefulWidget {
  const EcranParametres({super.key, required this.profil, required this.maisonId, required this.maisonNom});

  final Profil profil;
  final String maisonId;
  final String maisonNom;

  @override
  State<EcranParametres> createState() => _EcranParametresState();
}

class _EcranParametresState extends State<EcranParametres> {
  List<Map<String, dynamic>> _membres = [];
  StreamSubscription? _subMembres;

  @override
  void initState() {
    super.initState();
    _subMembres = ecouterMembres(widget.maisonId).listen((m) {
      if (mounted) setState(() => _membres = m);
    });
  }

  @override
  void dispose() {
    _subMembres?.cancel();
    super.dispose();
  }

  Future<void> _retirer(Map<String, dynamic> membre) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text('Retirer ${membre['prenom']} de cette maison ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexte, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(contexte, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (confirme != true) return;
    await retirerMembre(widget.maisonId, membre['id'] as String);
  }

  Future<void> _quitter() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Quitter cette maison ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexte, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(contexte, true), child: const Text('Quitter')),
        ],
      ),
    );
    if (confirme != true) return;

    await quitterMaison(widget.maisonId, widget.profil.id);
    final prefs = await SharedPreferences.getInstance();
    await effacerMaisonIdLocal(prefs);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => EcranMaison(profil: widget.profil)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.papier,
        foregroundColor: Palette.encre,
        elevation: 0,
        title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EcranAFaire(profil: widget.profil, maisonId: widget.maisonId)),
            ),
            style: boutonSecondaire(),
            child: const Text('VOIR TOUTES LES TÂCHES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EcranHistorique(maisonId: widget.maisonId)),
            ),
            style: boutonSecondaire(),
            child: const Text('HISTORIQUE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EcranGestion(maisonId: widget.maisonId)),
            ),
            style: boutonSecondaire(),
            child: const Text('PIÈCES ET TÂCHES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          const SizedBox(height: 28),
          const Text('Membres', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
          const SizedBox(height: 8),
          for (final membre in _membres) _ligneMembre(membre),
          const SizedBox(height: 16),
          Text(
            "Notez le code de « ${widget.maisonNom} » quelque part : c'est lui qui vous permettra de revenir si vous changez de téléphone ou videz les données de l'application.",
            style: const TextStyle(color: Palette.encreDouce, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: _quitter,
              child: const Text('Quitter cette maison', style: TextStyle(color: Palette.encreDouce, decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligneMembre(Map<String, dynamic> membre) {
    final estMoi = membre['id'] == widget.profil.id;
    final couleur = hexVersCouleur(membre['couleur'] as String);
    final prenom = membre['prenom'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            child: Text(prenom.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              estMoi ? '$prenom (vous)' : prenom,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.encre),
            ),
          ),
          if (!estMoi)
            TextButton(
              onPressed: () => _retirer(membre),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Retirer', style: TextStyle(fontSize: 12, color: Palette.encreDouce)),
            ),
        ],
      ),
    );
  }
}
