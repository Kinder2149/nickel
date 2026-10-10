import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'donnees.dart';
import 'ecran_maison.dart';
import 'palette.dart';
import 'stockage_local.dart';

/// Écran "Qui êtes-vous ?" — équivalent Flutter de `afficherEcranProfil`
/// (public/v2/js/app.js). Prénom + couleur, enregistrés localement.
class EcranProfil extends StatefulWidget {
  const EcranProfil({super.key, required this.uid});

  final String uid;

  @override
  State<EcranProfil> createState() => _EcranProfilState();
}

class _EcranProfilState extends State<EcranProfil> {
  final _controleurPrenom = TextEditingController();
  Color _couleurChoisie = couleursProfil.first;
  String? _erreur;

  @override
  void dispose() {
    _controleurPrenom.dispose();
    super.dispose();
  }

  Future<void> _continuer() async {
    final prenom = _controleurPrenom.text.trim();
    if (prenom.isEmpty) {
      setState(() => _erreur = 'Écrivez votre prénom : c\'est lui que les autres membres verront.');
      return;
    }

    final profil = Profil(id: widget.uid, prenom: prenom, couleur: _couleurChoisie);
    final prefs = await SharedPreferences.getInstance();
    await enregistrerProfilLocal(prefs, profil);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => EcranMaison(profil: profil)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'NICKEL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.5, color: Palette.encreFaible),
              ),
              const SizedBox(height: 8),
              const Text(
                'Qui\nêtes-vous ?',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 0.9, color: Palette.encre),
              ),
              const SizedBox(height: 32),
              libelleChamp('Votre prénom', obligatoire: true),
              const SizedBox(height: 6),
              TextField(
                controller: _controleurPrenom,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (_erreur != null) setState(() => _erreur = null);
                },
                decoration: decorationChamp('ex. : Camille', erreur: _erreur),
              ),
              const SizedBox(height: 24),
              const Text('Votre couleur', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: couleursProfil.map((couleur) {
                  final choisie = couleur.toARGB32() == _couleurChoisie.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _couleurChoisie = couleur),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: couleur,
                        border: Border.all(color: choisie ? Palette.encre : Colors.transparent, width: 2),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _continuer,
                style: boutonPrincipal(),
                child: const Text('CONTINUER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
