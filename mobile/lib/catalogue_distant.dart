// NICKEL — catalogue distant (§ 27, étape 3).
//
// Les nouveaux objets (saisons, exclusivités) vivent dans `catalogue.json`
// sur l'hébergement Firebase, avec leurs images : ils arrivent sur les
// téléphones sans réinstaller l'application. Le catalogue est gardé en cache
// sur l'appareil ; hors connexion, on affiche le dernier catalogue connu,
// et à défaut le kit gratuit et la boutique de lancement embarqués.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalogue.dart';
import 'donnees.dart';

/// Dossier du pack « Chez nous » sur l'hébergement. Supprimer ce dossier
/// (puis redéployer) retire tout le contenu distant.
const urlCatalogue = 'https://nickel-menage-57692.web.app/catalogue/chez-nous/';

const _cleCache = 'nickel-catalogue-cache';

/// Objets distants actuellement connus (déjà filtrés sur leur date de sortie).
final ValueNotifier<List<Objet>> objetsDistants = ValueNotifier(const []);

/// Lit un catalogue JSON : ne garde que les objets dont la saison est déjà
/// sortie à la date `aujourdhui` (« AAAA-MM-JJ »). Un objet illisible est
/// ignoré, il ne casse pas les autres.
List<Objet> lireCatalogue(String json, {required String aujourdhui, String base = ''}) {
  final data = jsonDecode(json) as Map<String, dynamic>;
  final debuts = {
    for (final s in (data['saisons'] as List? ?? const []).whereType<Map<String, dynamic>>())
      s['id'] as String: (s['debut'] as String?) ?? '0000-00-00',
  };
  final objets = <Objet>[];
  for (final j in (data['objets'] as List? ?? const []).whereType<Map<String, dynamic>>()) {
    try {
      final o = Objet.depuisJson(j, base: base);
      final debut = debuts[o.saison] ?? '0000-00-00';
      if (debut.compareTo(aujourdhui) <= 0) objets.add(o);
    } catch (_) {
      // objet mal formé : ignoré
    }
  }
  return objets;
}

/// Charge le cache local (instantané), puis tente de rafraîchir depuis
/// l'hébergement. Ne lève jamais : un échec réseau laisse le cache en place.
Future<void> chargerCatalogue() async {
  final prefs = await SharedPreferences.getInstance();
  final cache = prefs.getString(_cleCache);
  if (cache != null) {
    try {
      objetsDistants.value = lireCatalogue(cache, aujourdhui: dateAujourdhui(), base: urlCatalogue);
    } catch (_) {}
  }

  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final requete = await client.getUrl(Uri.parse('${urlCatalogue}catalogue.json'));
      final reponse = await requete.close().timeout(const Duration(seconds: 10));
      if (reponse.statusCode != 200) return;
      final corps = await reponse.transform(utf8.decoder).join();
      final objets = lireCatalogue(corps, aujourdhui: dateAujourdhui(), base: urlCatalogue); // valide avant de garder
      await prefs.setString(_cleCache, corps);
      objetsDistants.value = objets;
    } finally {
      client.close();
    }
  } catch (_) {
    // hors connexion : on garde ce qu'on a
  }
}
