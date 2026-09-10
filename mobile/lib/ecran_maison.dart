import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'donnees.dart';
import 'ecran_accueil.dart';
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
  bool _enCours = false;

  @override
  void dispose() {
    _controleurNom.dispose();
    _controleurCode.dispose();
    super.dispose();
  }

  Future<void> _allerVersAccueil(String maisonId) async {
    final prefs = await SharedPreferences.getInstance();
    await enregistrerMaisonIdLocal(prefs, maisonId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => EcranAccueil(profil: widget.profil, maisonId: maisonId)),
    );
  }

  /// Sans ce garde-fou, un échec réseau ou un refus des règles Firestore
  /// laissait l'écran tourner indéfiniment, sans message (retour de Kinder
  /// du 2026-09-10 : maison "créée" mais absente de la base).
  Future<void> _executer(Future<void> Function() action) async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Échec, rien n\'a été enregistré correctement. Vérifiez la connexion et réessayez.\n($e)';
        _enCours = false;
      });
    }
  }

  Future<void> _creerVide() async {
    final nom = _controleurNom.text.trim();
    if (nom.isEmpty) {
      setState(() => _erreur = 'Donnez un nom à votre maison.');
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
      setState(() => _erreur = "Entrez un code d'invitation.");
      return;
    }
    await _executer(() async {
      final maison = await rejoindreMaison(code, widget.profil);
      if (maison == null) {
        if (!mounted) return;
        setState(() {
          _erreur = 'Aucune maison ne correspond à ce code.';
          _enCours = false;
        });
        return;
      }
      await _allerVersAccueil(maison['id'] as String);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              if (_erreur != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFF6E4E0),
                  child: Text(_erreur!, style: const TextStyle(color: Palette.rouge)),
                ),
                const SizedBox(height: 16),
              ],
              const Text('Créer une maison', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
              const SizedBox(height: 6),
              TextField(controller: _controleurNom, decoration: decorationChamp('Chez nous')),
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
                decoration: decorationChamp('AB12CD'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _enCours ? null : _rejoindre,
                style: boutonSecondaire(),
                child: const Text('REJOINDRE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
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
}
