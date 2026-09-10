import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'donnees.dart';
import 'ecran_afaire.dart';
import 'ecran_maison.dart';
import 'ecran_parametres.dart';
import 'palette.dart';
import 'stockage_local.dart';

/// Écran d'accueil / tableau de bord — équivalent Flutter de
/// `afficherEcranAccueil` (public/v2/js/app.js), déjà revu au peaufinage
/// (§ 16 point 2, § 17 points A et B) : la carte de la maison + directement
/// les tâches urgentes (en retard, jamais faites, du jour). "Voir toutes
/// les tâches", "Historique", "Pièces et tâches" et les membres vivent
/// dans l'écran Paramètres (⚙), pas ici — sinon ils se retrouvent poussés
/// hors de vue par une vraie liste de tâches (retour de Kinder, § 17).
class EcranAccueil extends StatefulWidget {
  const EcranAccueil({super.key, required this.profil, required this.maisonId});

  final Profil profil;
  final String maisonId;

  @override
  State<EcranAccueil> createState() => _EcranAccueilState();
}

class _EcranAccueilState extends State<EcranAccueil> {
  Map<String, dynamic>? _maison;
  bool _maisonIntrouvable = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final maison = await chargerMaison(widget.maisonId);
    if (!mounted) return;
    if (maison == null) {
      // Code d'invitation périmé ou maison supprimée : on repart de zéro.
      final prefs = await SharedPreferences.getInstance();
      await effacerMaisonIdLocal(prefs);
      setState(() => _maisonIntrouvable = true);
      return;
    }
    setState(() => _maison = maison);
  }

  void _ouvrirAFaire(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EcranAFaire(profil: widget.profil, maisonId: widget.maisonId)),
    );
  }

  void _ouvrirParametres(BuildContext context, String nomMaison) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EcranParametres(profil: widget.profil, maisonId: widget.maisonId, maisonNom: nomMaison),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_maisonIntrouvable) {
      return EcranMaison(profil: widget.profil);
    }
    if (_maison == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Palette.encre)));
    }

    final maison = _maison!;
    final nomMaison = maison['nom'] as String;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text('Bonjour ${widget.profil.prenom}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.5, color: Palette.encreFaible)),
                  ),
                  TextButton.icon(
                    onPressed: () => _ouvrirParametres(context, nomMaison),
                    icon: const Icon(Icons.settings_outlined, size: 16, color: Palette.encreDouce),
                    label: const Text('Paramètres', style: TextStyle(color: Palette.encreDouce)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                color: Palette.encre,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nomMaison, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Palette.papier)),
                    const SizedBox(height: 10),
                    const Text("CODE D'INVITATION",
                        style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Color(0xFFA29B85))),
                    const SizedBox(height: 4),
                    Text(maison['codeInvitation'] as String,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 3, color: Palette.papier)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _TableauDeBord(
                  maisonId: widget.maisonId,
                  onTapTache: () => _ouvrirAFaire(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableauDeBord extends StatelessWidget {
  const _TableauDeBord({required this.maisonId, required this.onTapTache});

  final String maisonId;
  final VoidCallback onTapTache;

  static const _emojiParDefaut = '🧹';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ecouterTaches(maisonId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Erreur : ${snapshot.error}', style: const TextStyle(color: Palette.rouge));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Palette.encre));
        }

        final taches = snapshot.data!;
        final enRetard = taches.where((t) => statutTache(t) == 'retard').toList();
        final jamaisFaites = taches.where((t) => statutTache(t) == 'jamais').toList();
        final duJour = taches.where((t) => statutTache(t) == 'aujourdhui').toList();
        final urgentes = [...enRetard, ...jamaisFaites, ...duJour];

        if (urgentes.isEmpty) {
          return const Text("Rien à faire pour l'instant. 🎉", style: TextStyle(color: Palette.encreDouce, fontSize: 15));
        }

        final libelle = [
          if (enRetard.isNotEmpty) '${enRetard.length} en retard',
          if (jamaisFaites.isNotEmpty) '${jamaisFaites.length} jamais faites',
          if (duJour.isNotEmpty) "${duJour.length} aujourd'hui",
        ].join(' · ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: enRetard.isNotEmpty ? Palette.rouge : Palette.encre,
              child: Text(libelle.toUpperCase(),
                  style: const TextStyle(color: Palette.papier, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: urgentes.length,
                separatorBuilder: (context, index) => const Divider(color: Palette.trait, height: 1),
                itemBuilder: (context, index) {
                  final t = urgentes[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: onTapTache,
                    leading: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Palette.papierClair, border: Border.all(color: Palette.encre, width: 2)),
                      child: Text((t['emoji'] as String?) ?? _emojiParDefaut, style: const TextStyle(fontSize: 20)),
                    ),
                    title: Text(t['nom'] as String, style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.encre)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
