// NICKEL — catalogue distant (§ 27).
//
// Les objets des saisons vivent dans `catalogue.json` sur l'hébergement
// Firebase, avec leurs images : ils arrivent sur les téléphones sans
// réinstaller l'application. Le catalogue est gardé en cache sur l'appareil ;
// hors connexion, on affiche le dernier catalogue connu, et à défaut le kit
// gratuit et la boutique de lancement embarqués.
//
// Le catalogue contient TOUS les objets, y compris ceux d'une saison hors
// vente : un objet déjà possédé doit toujours pouvoir s'afficher et
// s'équiper. C'est `estEnVente` (catalogue.dart) qui décide ce qu'on peut
// acheter à une date donnée.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalogue.dart';

/// Dossier du pack « Chez nous » sur l'hébergement. Supprimer ce dossier
/// (puis redéployer) retire tout le contenu distant.
const urlCatalogue = 'https://nickel-menage-57692.web.app/catalogue/chez-nous/';

const _cleCache = 'nickel-catalogue-cache';

/// Objets distants connus (toutes saisons).
final ValueNotifier<List<Objet>> objetsDistants = ValueNotifier(const []);

/// Saisons distantes connues.
final ValueNotifier<List<Saison>> saisonsDistantes = ValueNotifier(const []);

/// Objets retirés de la vente par le catalogue (liste `retires`) : on ne peut
/// plus les acheter, mais ceux qui les possèdent les gardent. Piloté depuis
/// l'hébergement : retirer ou remettre un objet ne demande pas de nouvelle
/// version de l'application.
final ValueNotifier<Set<String>> idsRetires = ValueNotifier(const {});

class CatalogueLu {
  const CatalogueLu(this.saisons, this.objets, [this.retires = const {}]);
  final List<Saison> saisons;
  final List<Objet> objets;
  final Set<String> retires;
}

/// Lit un catalogue JSON. Un objet ou une saison mal formé est ignoré, il ne
/// casse pas les autres.
CatalogueLu lireCatalogue(String json, {String base = ''}) {
  final data = jsonDecode(json) as Map<String, dynamic>;
  final saisons = <Saison>[];
  for (final j in (data['saisons'] as List? ?? const []).whereType<Map<String, dynamic>>()) {
    try {
      saisons.add(Saison.depuisJson(j));
    } catch (_) {}
  }
  final objets = <Objet>[];
  for (final j in (data['objets'] as List? ?? const []).whereType<Map<String, dynamic>>()) {
    try {
      objets.add(Objet.depuisJson(j, base: base));
    } catch (_) {}
  }
  final retires = (data['retires'] as List? ?? const []).whereType<String>().toSet();
  return CatalogueLu(saisons, objets, retires);
}

void _appliquer(CatalogueLu c) {
  saisonsDistantes.value = c.saisons;
  idsRetires.value = c.retires;
  objetsDistants.value = c.objets;
}

/// Charge le cache local (instantané), puis tente de rafraîchir depuis
/// l'hébergement. Ne lève jamais : un échec réseau laisse le cache en place.
Future<void> chargerCatalogue() async {
  final prefs = await SharedPreferences.getInstance();
  final cache = prefs.getString(_cleCache);
  if (cache != null) {
    try {
      _appliquer(lireCatalogue(cache, base: urlCatalogue));
    } catch (_) {}
  }

  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final requete = await client.getUrl(Uri.parse('${urlCatalogue}catalogue.json'));
      final reponse = await requete.close().timeout(const Duration(seconds: 10));
      if (reponse.statusCode != 200) return;
      final corps = await reponse.transform(utf8.decoder).join();
      final lu = lireCatalogue(corps, base: urlCatalogue); // valide avant de garder
      await prefs.setString(_cleCache, corps);
      _appliquer(lu);
    } finally {
      client.close();
    }
  } catch (_) {
    // hors connexion : on garde ce qu'on a
  }
}
