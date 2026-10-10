import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'donnees.dart';
import 'navigation.dart';
import 'palette.dart';
import 'stockage_local.dart';

/// Écran "Votre maison" — équivalent Flutter de `afficherEcranMaison`
/// (public/v2/js/app.js) : créer une maison (vide ou depuis un modèle) ou
/// en rejoindre une avec un code. L'import depuis un fichier .json externe
/// (fonctionnalité secondaire de la V2) n'est pas repris ici — les deux
/// modèles embarqués suffisent pour tester.
class EcranMaison extends StatefulWidget {
  const EcranMaison({super.key, required this.profil});

  final Profil profil;

  @override
  State<EcranMaison> createState() => _EcranMaisonState();
}

class _EcranMaisonState extends State<EcranMaison> {
  final _controleurNom = TextEditingController();
  final _controleurCode = TextEditingController();
  String? _erreur;
  // L'erreur s'affiche sous le bouton qui l'a provoquée, pour rester en vue
  // (avec le clavier ouvert, un message en haut de l'écran passait inaperçu).
  bool _erreurSurRejoindre = false;
  bool _enCours = false;

  @override
  void dispose() {
    _controleurNom.dispose();
    _controleurCode.dispose();
    super.dispose();
  }

  Future<void> _allerVersAccueil(String maisonId) async {
    final prefs = await SharedPreferences.getInstance();
    await ajouterMaisonLocale(prefs, maisonId);
    if (!mounted) return;
    await ouvrirMaisonCourante(context, widget.profil);
  }

  /// Sans ce garde-fou, un échec réseau ou un refus des règles Firestore
  /// laissait l'écran tourner indéfiniment, sans message (retour de Kinder
  /// du 2026-09-10 : maison "créée" mais absente de la base).
  Future<void> _executer(Future<void> Function() action, {bool rejoindre = false}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _enCours = true;
      _erreur = null;
      _erreurSurRejoindre = rejoindre;
    });
    try {
      await verifierConnexion();
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Rien n\'a été enregistré. ${texteErreur(e)}';
        _enCours = false;
      });
    }
  }

  Future<void> _creerVide() async {
    final nom = _controleurNom.text.trim();
    if (nom.isEmpty) {
      setState(() {
        _erreur = 'Donnez un nom à votre maison avant d\'appuyer sur « Créer la maison vide » (ex. : Chez nous).';
        _erreurSurRejoindre = false;
      });
      return;
    }
    await _executer(() async {
      final maison = await creerMaison(nom, widget.profil);
      await _allerVersAccueil(maison.id);
    });
  }

  Future<void> _creerDepuisModele(String fichierAsset, String nomParDefaut) async {
    final nom = _controleurNom.text.trim().isEmpty ? nomParDefaut : _controleurNom.text.trim();
    await _executer(() async {
      final texte = await rootBundle.loadString('assets/modeles/$fichierAsset');
      final structure = jsonDecode(texte) as Map<String, dynamic>;
      final maison = await importerStructure(nom, structure, widget.profil);
      await _allerVersAccueil(maison.id);
    });
  }

  Future<void> _rejoindre() async {
    final code = _controleurCode.text.trim();
    if (code.isEmpty) {
      setState(() {
        _erreur = "Entrez le code d'invitation à 6 caractères (un membre de la maison le trouve dans Paramètres).";
        _erreurSurRejoindre = true;
      });
      return;
    }
    await _executer(() async {
      final maison = await rejoindreMaison(code, widget.profil);
      if (maison == null) {
        if (!mounted) return;
        setState(() {
          _erreur = 'Aucune maison ne correspond à ce code. Vérifiez-le auprès d\'un membre de la maison (Paramètres → Code d\'invitation).';
          _enCours = false;
        });
        return;
      }
      await _allerVersAccueil(maison['id'] as String);
    }, rejoindre: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ouvert depuis Paramètres ("ajouter une maison") : flèche retour pour
      // revenir à sa maison sans rien créer.
      appBar: Navigator.of(context).canPop()
          ? AppBar(backgroundColor: Palette.papier, foregroundColor: Palette.encre, elevation: 0)
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Bonjour ${widget.profil.prenom}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.5, color: Palette.encreFaible)),
              const SizedBox(height: 8),
              const Text('Votre\nmaison',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 0.9, color: Palette.encre)),
              const SizedBox(height: 24),
              const Text('Créer une maison', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
              const SizedBox(height: 6),
              TextField(controller: _controleurNom, decoration: decorationChamp('ex. : Chez nous')),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _enCours ? null : _creerVide,
                style: boutonPrincipal(),
                child: const Text('CRÉER LA MAISON VIDE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _enCours ? null : () => _creerDepuisModele('generique.json', 'Chez nous'),
                style: boutonSecondaire(),
                child: const Text('MODÈLE GÉNÉRIQUE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
              const SizedBox(height: 4),
              const Text('Pièces et tâches courantes déjà remplies — à ajuster ensuite.',
                  style: TextStyle(color: Palette.encreDouce, fontSize: 12)),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _enCours ? null : () => _creerDepuisModele('foyer-pilote.json', 'Chez nous (test)'),
                style: boutonSecondaire(),
                child: const Text('MODÈLE SPÉCIAL CHEZ NOUS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
              const SizedBox(height: 4),
              const Text('Les 35 tâches réelles de "Chez nous" — pratique pour tester.',
                  style: TextStyle(color: Palette.encreDouce, fontSize: 12)),
              if (_erreur != null && !_erreurSurRejoindre) _bandeauErreur(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(children: const [
                  Expanded(child: Divider(color: Palette.trait)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('ou', style: TextStyle(color: Palette.encreFaible))),
                  Expanded(child: Divider(color: Palette.trait)),
                ]),
              ),
              const Text('Rejoindre avec un code', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
              const SizedBox(height: 6),
              TextField(
                controller: _controleurCode,
                textCapitalization: TextCapitalization.characters,
                decoration: decorationChamp('ex. : AB12CD'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _enCours ? null : _rejoindre,
                style: boutonSecondaire(),
                child: const Text('REJOINDRE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
              if (_erreur != null && _erreurSurRejoindre) _bandeauErreur(),
              if (_enCours) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator(color: Palette.encre)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bandeauErreur() => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF6E4E0), border: Border.all(color: Palette.rouge, width: 2)),
        child: Text(_erreur!, style: const TextStyle(color: Palette.rouge, fontWeight: FontWeight.w600)),
      );
}
