import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

// Palette reprise de la V2 (public/v2/index.html) — même identité visuelle,
// "le registre d'entretien" (§ 11 PROJET_CONTEXTE.md).
class Palette {
  static const papier = Color(0xFFEFE7D6);
  static const papierClair = Color(0xFFF6EFDE);
  static const encre = Color(0xFF16150F);
  static const encreDouce = Color(0xFF6B675A);
  static const encreFaible = Color(0xFFA9A18D);
  static const trait = Color(0xFFD8CFB8);
  static const rouge = Color(0xFFB4321F);
  static const vert = Color(0xFF2E6B4E);
}

const couleursProfil = [
  Color(0xFFF2A65A),
  Color(0xFF5AA9E6),
  Color(0xFFC77DFF),
  Color(0xFF2E6B4E),
  Color(0xFFB4321F),
  Color(0xFF6B675A),
];

const cleProfilId = 'nickel-profil-id';
const cleProfilPrenom = 'nickel-profil-prenom';
const cleProfilCouleur = 'nickel-profil-couleur';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.encre,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const EcranDemarrage(),
    );
  }
}

/// Point d'entrée : authentifie l'appareil de façon anonyme (même logique
/// que `assurerAuthentification()` en V2, `donnees.js`), puis dirige vers
/// l'écran profil si aucun profil local n'existe encore.
class EcranDemarrage extends StatefulWidget {
  const EcranDemarrage({super.key});

  @override
  State<EcranDemarrage> createState() => _EcranDemarrageState();
}

class _EcranDemarrageState extends State<EcranDemarrage> {
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    try {
      final auth = FirebaseAuth.instance;
      final utilisateur = auth.currentUser ?? (await auth.signInAnonymously()).user;
      if (utilisateur == null) throw Exception('Authentification anonyme refusée.');

      final prefs = await SharedPreferences.getInstance();
      final prenom = prefs.getString(cleProfilPrenom);

      if (!mounted) return;

      if (prenom == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => EcranProfil(uid: utilisateur.uid)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EcranConnecte(
              uid: utilisateur.uid,
              prenom: prenom,
              couleur: Color(prefs.getInt(cleProfilCouleur) ?? couleursProfil.first.toARGB32()),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _erreur = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_erreur != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Connexion impossible :\n$_erreur',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.rouge),
            ),
          ),
        ),
      );
    }
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Palette.encre)),
    );
  }
}

/// Écran "Qui êtes-vous ?" — équivalent Flutter de `afficherEcranProfil`
/// (public/v2/js/app.js). Prénom + couleur, enregistrés localement
/// (shared_preferences ~ localStorage de la V2).
class EcranProfil extends StatefulWidget {
  const EcranProfil({super.key, required this.uid});

  final String uid;

  @override
  State<EcranProfil> createState() => _EcranProfilState();
}

class _EcranProfilState extends State<EcranProfil> {
  final _controleurPrenom = TextEditingController();
  Color _couleurChoisie = couleursProfil.first;

  @override
  void dispose() {
    _controleurPrenom.dispose();
    super.dispose();
  }

  Future<void> _continuer() async {
    final prenom = _controleurPrenom.text.trim();
    if (prenom.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cleProfilId, widget.uid);
    await prefs.setString(cleProfilPrenom, prenom);
    await prefs.setInt(cleProfilCouleur, _couleurChoisie.toARGB32());

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EcranConnecte(uid: widget.uid, prenom: prenom, couleur: _couleurChoisie),
      ),
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
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                  color: Palette.encreFaible,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Qui\nêtes-vous ?',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                  color: Palette.encre,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Votre prénom',
                style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _controleurPrenom,
                decoration: InputDecoration(
                  hintText: 'Camille',
                  filled: true,
                  fillColor: Palette.papierClair,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: const BorderSide(color: Palette.encre, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: const BorderSide(color: Palette.encre, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: const BorderSide(color: Palette.encre, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Votre couleur',
                style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce),
              ),
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
                        border: Border.all(
                          color: choisie ? Palette.encre : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _continuer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.encre,
                    foregroundColor: Palette.papier,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: const Text(
                    'CONTINUER',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran de preuve pour l'étape 1 : confirme que l'authentification et la
/// lecture Firestore fonctionnent, avant de construire le vrai tableau de
/// bord à l'étape 2. Affiche la maison "Chez nous" si elle est lisible (elle
/// ne le sera pas tant que ce profil n'en est pas membre — normal, les
/// règles Firestore l'imposent).
class EcranConnecte extends StatelessWidget {
  const EcranConnecte({
    super.key,
    required this.uid,
    required this.prenom,
    required this.couleur,
  });

  final String uid;
  final String prenom;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      prenom.isNotEmpty ? prenom[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bonjour $prenom',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Palette.encre),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                color: Palette.encre,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ÉTAPE 1 — PREUVE', style: TextStyle(color: Palette.trait, fontSize: 10, letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    Text('Identifiant Firebase (uid) :', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(uid, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "L'app Flutter tourne, est authentifiée auprès de Firebase, et le "
                'profil est enregistré sur l\'appareil. Prochaine étape : le '
                'tableau de bord (créer/rejoindre une maison).',
                style: TextStyle(color: Palette.encreDouce),
              ),
              const Spacer(),
              // Vérification supplémentaire : lecture Firestore réelle (pas
              // juste l'authentification) — confirme que la même base que
              // la V2 est bien accessible depuis Flutter.
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('maisons').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Firestore : ${snapshot.error}', style: const TextStyle(color: Palette.rouge));
                  }
                  if (!snapshot.hasData) {
                    return const Text('Lecture Firestore…', style: TextStyle(color: Palette.encreFaible));
                  }
                  return Text(
                    'Firestore accessible : ${snapshot.data!.docs.length} maison(s) visible(s) (liste, pas le contenu — normal, règles fermées).',
                    style: const TextStyle(color: Palette.vert, fontWeight: FontWeight.w600),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
