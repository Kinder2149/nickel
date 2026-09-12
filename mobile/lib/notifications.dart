import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'donnees.dart';
import 'firebase_options.dart';
import 'stockage_local.dart';

/// Rappel quotidien des tâches du jour (§ 20 PROJET_CONTEXTE.md).
///
/// Un seul rappel par jour, à l'heure choisie sur CE téléphone, jamais une
/// notification par tâche. Rien à faire = pas de notification. Pour que le
/// compte soit juste (un autre membre a pu cocher entre-temps), le téléphone
/// relit la base au moment du rappel : le travail est donc programmé en
/// arrière-plan (WorkManager), pas figé à l'avance. Conséquence assumée :
/// Android décale ces réveils pour économiser la batterie, le rappel peut
/// arriver avec quelques minutes de retard.

const _tacheRappel = 'nickel-rappel-quotidien';
const _canalId = 'nickel-rappel';
const _canalNom = 'Rappel quotidien';

final _notifications = FlutterLocalNotificationsPlugin();

Future<void> initialiserNotifications() async {
  await _notifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await Workmanager().initialize(pointEntreeRappel);
}

/// Demande l'autorisation d'afficher des notifications (Android 13+).
/// Retourne false si l'utilisateur refuse.
Future<bool> demanderAutorisationNotifications() async {
  final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return true;
  return await android.requestNotificationsPermission() ?? false;
}

/// (Ré)installe ou supprime le rappel quotidien selon le réglage local.
Future<void> appliquerReglageRappel() async {
  final prefs = await SharedPreferences.getInstance();
  await Workmanager().cancelByUniqueName(_tacheRappel);
  if (!rappelActif(prefs)) return;

  await Workmanager().registerPeriodicTask(
    _tacheRappel,
    _tacheRappel,
    frequency: const Duration(days: 1),
    initialDelay: _delaiJusqua(rappelHeure(prefs)),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

Duration _delaiJusqua(String heureHHmm) {
  final parties = heureHHmm.split(':').map(int.parse).toList();
  final maintenant = DateTime.now();
  var prochain = DateTime(maintenant.year, maintenant.month, maintenant.day, parties[0], parties[1]);
  if (!prochain.isAfter(maintenant)) prochain = prochain.add(const Duration(days: 1));
  return prochain.difference(maintenant);
}

/// Point d'entrée appelé par Android à l'heure du rappel, dans un isolat
/// séparé : rien de l'application en cours d'exécution n'est disponible ici,
/// tout doit être réinitialisé (Firebase compris).
@pragma('vm:entry-point')
void pointEntreeRappel() {
  Workmanager().executeTask((tache, donneesEntree) async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final compte = await compterTachesDuJour();
      if (compte != null && compte.aFaire > 0) {
        await afficherRappel(compte.aFaire, compte.enRetard);
      }
    } catch (_) {
      // Un rappel manqué ne doit jamais faire remonter d'erreur à
      // l'utilisateur : on réessaiera demain.
    }
    return true;
  });
}

/// Compte les tâches à faire de la maison affichée sur cet appareil.
/// Retourne null si aucune maison, ou si la base n'est pas lisible (session
/// expirée en arrière-plan) : dans ce cas, pas de rappel plutôt qu'un
/// rappel faux.
Future<({int aFaire, int enRetard})?> compterTachesDuJour() async {
  final prefs = await SharedPreferences.getInstance();
  final maisonId = chargerMaisonIdLocal(prefs);
  if (maisonId == null) return null;

  final utilisateur = FirebaseAuth.instance.currentUser ??
      await FirebaseAuth.instance.authStateChanges().first.timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
  if (utilisateur == null) return null;

  final taches = await lireTaches(maisonId);
  var aFaire = 0, enRetard = 0;
  for (final t in taches) {
    final statut = statutTache(t);
    if (statut == 'avenir') continue;
    aFaire++;
    if (statut == 'retard') enRetard++;
  }
  return (aFaire: aFaire, enRetard: enRetard);
}

Future<void> afficherRappel(int aFaire, int enRetard) async {
  final corps = enRetard > 0
      ? '$aFaire à faire, dont $enRetard en retard'
      : '$aFaire à faire';

  await _notifications.show(
    1,
    'Tâches du jour',
    corps,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _canalId,
        _canalNom,
        channelDescription: 'Le rappel quotidien des tâches à faire',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    ),
  );
}
