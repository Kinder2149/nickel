import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'donnees.dart';
import 'ecran_maison.dart';
import 'ecran_profil.dart';
import 'ecran_racine.dart';
import 'firebase_options.dart';
import 'notifications.dart';
import 'palette.dart';
import 'stockage_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initialiserNotifications();
  // Le rappel est réinstallé à chaque démarrage : ça le remet en place après
  // une réinstallation, une mise à jour ou un redémarrage du téléphone.
  await appliquerReglageRappel();
  runApp(const NickelApp());
}

class NickelApp extends StatelessWidget {
  const NickelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nickel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Palette.papier,
        colorScheme: ColorScheme.fromSeed(seedColor: Palette.encre, brightness: Brightness.light),
        useMaterial3: true,
      ),
      home: const EcranDemarrage(),
    );
  }
}

/// Point d'entrée : authentifie l'appareil de façon anonyme (même logique
/// que `assurerAuthentification()` en V2), puis dirige vers l'écran profil,
/// l'écran "votre maison" ou directement l'accueil selon ce qui est déjà
/// enregistré localement.
class EcranDemarrage extends StatefulWidget {
  const EcranDemarrage({super.key});

  @override
  State<EcranDemarrage> createState() => _EcranDemarrageState();
}

class _EcranDemarrageState extends State<EcranDemarrage> {
  Object? _erreur;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    if (_erreur != null) setState(() => _erreur = null);
    try {
      final auth = FirebaseAuth.instance;
      final utilisateur = auth.currentUser ?? (await auth.signInAnonymously()).user;
      if (utilisateur == null) throw Exception('Authentification anonyme refusée.');

      final prefs = await SharedPreferences.getInstance();
      var profil = chargerProfilLocal(prefs);

      // Après une réinstallation, Android peut restaurer le profil local
      // (sauvegarde automatique) alors que Firebase attribue un nouvel
      // identifiant à l'appareil. L'ancien identifiant n'est plus accepté
      // par les règles Firestore : toute création de maison échouait. On
      // recale donc le profil sur l'identifiant réel, et on réinscrit
      // l'appareil dans sa maison s'il en avait une.
      if (profil != null && profil.id != utilisateur.uid) {
        final ancienId = profil.id;
        profil = Profil(id: utilisateur.uid, prenom: profil.prenom, couleur: profil.couleur);
        await enregistrerProfilLocal(prefs, profil);
        for (final maisonId in chargerMaisonsLocales(prefs)) {
          await reprendreMaison(maisonId, profil, ancienId);
        }
      }

      if (!mounted) return;

      if (profil == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => EcranProfil(uid: utilisateur.uid)),
        );
        return;
      }
      final profilActuel = profil;

      final maisonId = chargerMaisonIdLocal(prefs);
      if (maisonId == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => EcranMaison(profil: profilActuel)),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => EcranRacine(profil: profilActuel, maisonId: maisonId)),
      );
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_erreur != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Nickel n\'a pas pu démarrer', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.encre)),
                const SizedBox(height: 12),
                Text(
                  texteErreur(_erreur!),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Palette.rouge),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _demarrer,
                  style: boutonPrincipal(),
                  child: const Text('RÉESSAYER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator(color: Palette.encre)));
  }
}
