import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'donnees.dart';
import 'ecran_fiche.dart';
import 'ecran_gestion.dart';
import 'ecran_historique.dart';
import 'ecran_maison.dart';
import 'navigation.dart';
import 'notifications.dart';
import 'palette.dart';
import 'stockage_local.dart';

/// Écran "Paramètres" : code d'invitation (déplacé ici depuis l'accueil,
/// § 19), "Historique", "Pièces et tâches", membres (avec "Retirer") et
/// "Quitter cette maison". Toutes les tâches sont désormais sur l'accueil,
/// il n'y a plus de bouton "Voir toutes les tâches".
class EcranParametres extends StatefulWidget {
  const EcranParametres({
    super.key,
    required this.profil,
    required this.maisonId,
    required this.maisonNom,
    required this.codeInvitation,
  });

  final Profil profil;
  final String maisonId;
  final String maisonNom;
  final String codeInvitation;

  @override
  State<EcranParametres> createState() => _EcranParametresState();
}

class _EcranParametresState extends State<EcranParametres> {
  List<Map<String, dynamic>> _membres = [];
  List<Map<String, dynamic>>? _mesMaisons;
  StreamSubscription? _subMembres;
  bool _rappelActif = false;
  String _rappelHeure = '19:00';

  @override
  void initState() {
    super.initState();
    _chargerRappel();
    _subMembres = ecouterMembres(widget.maisonId).listen((m) {
      if (mounted) setState(() => _membres = m);
    });
    _chargerMesMaisons();
  }

  Future<void> _chargerRappel() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _rappelActif = rappelActif(prefs);
      _rappelHeure = rappelHeure(prefs);
    });
  }

  Future<void> _changerRappel({bool? actif, String? heure}) async {
    final nouvelActif = actif ?? _rappelActif;
    final nouvelleHeure = heure ?? _rappelHeure;

    if (nouvelActif && !_rappelActif) {
      final autorise = await demanderAutorisationNotifications();
      if (!autorise) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications refusées. Autorisez-les dans les réglages Android pour recevoir le rappel.'),
            backgroundColor: Palette.rouge,
          ),
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await enregistrerRappel(prefs, actif: nouvelActif, heure: nouvelleHeure);
    await appliquerReglageRappel();
    if (!mounted) return;
    setState(() {
      _rappelActif = nouvelActif;
      _rappelHeure = nouvelleHeure;
    });
  }

  Future<void> _choisirHeure() async {
    final parties = _rappelHeure.split(':').map(int.parse).toList();
    final choisie = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: parties[0], minute: parties[1]),
    );
    if (choisie == null) return;
    final heure = '${choisie.hour.toString().padLeft(2, '0')}:${choisie.minute.toString().padLeft(2, '0')}';
    await _changerRappel(heure: heure);
  }

  /// Affiche tout de suite le rappel tel qu'il serait envoyé ce soir —
  /// sans attendre l'heure choisie, et sans rien programmer.
  Future<void> _testerRappel() async {
    final autorise = await demanderAutorisationNotifications();
    if (!autorise) return;
    final compte = await compterTachesDuJour();
    if (!mounted) return;
    if (compte == null || compte.aFaire == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rien à faire aujourd\'hui : aucun rappel ne serait envoyé.')),
      );
      return;
    }
    await afficherRappel(compte.aFaire, compte.enRetard);
  }

  Future<void> _chargerMesMaisons() async {
    final prefs = await SharedPreferences.getInstance();
    final maisons = await chargerMesMaisons(chargerMaisonsLocales(prefs), widget.profil.id);
    if (mounted) setState(() => _mesMaisons = maisons);
  }

  Future<void> _basculer(String maisonId) async {
    final prefs = await SharedPreferences.getInstance();
    await choisirMaisonLocale(prefs, maisonId);
    if (!mounted) return;
    await ouvrirMaisonCourante(context, widget.profil);
  }

  Future<void> _supprimerMaison() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text('Supprimer « ${widget.maisonNom} » ?'),
        content: const Text(
          'Tout sera effacé définitivement, pour tous les membres : pièces, tâches et historique. '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexte, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(contexte, true),
            child: const Text('Supprimer définitivement', style: TextStyle(color: Palette.rouge)),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    await _effacerMaison();
  }

  Future<void> _effacerMaison() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Palette.papier)),
    );
    try {
      await supprimerMaison(widget.maisonId, widget.profil.id);
      final prefs = await SharedPreferences.getInstance();
      await retirerMaisonLocale(prefs, widget.maisonId);
      if (!mounted) return;
      await ouvrirMaisonCourante(context, widget.profil);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression interrompue : $e'), backgroundColor: Palette.rouge),
      );
    }
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
    // Dernier membre : quitter laisserait une maison vide en base pour
    // toujours (c'est ainsi que des doublons "Chez nous" s'étaient
    // accumulés, § 19). Dans ce cas, quitter = supprimer, dit clairement.
    final seulMembre = _membres.length <= 1;
    if (seulMembre) {
      final confirme = await showDialog<bool>(
        context: context,
        builder: (contexte) => AlertDialog(
          title: Text('Quitter « ${widget.maisonNom} » ?'),
          content: const Text(
            'Vous êtes le seul membre : en la quittant, la maison sera supprimée définitivement, '
            'avec ses pièces, tâches et historique.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(contexte, false), child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(contexte, true),
              child: const Text('Quitter et supprimer', style: TextStyle(color: Palette.rouge)),
            ),
          ],
        ),
      );
      if (confirme != true || !mounted) return;
      await _effacerMaison();
      return;
    }

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
    await retirerMaisonLocale(prefs, widget.maisonId);

    if (!mounted) return;
    await ouvrirMaisonCourante(context, widget.profil);
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
          Container(
            padding: const EdgeInsets.all(16),
            color: Palette.encre,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("CODE D'INVITATION", style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Color(0xFFA29B85))),
                      const SizedBox(height: 4),
                      Text(
                        widget.codeInvitation,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 3, color: Palette.papier),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.codeInvitation));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copié')));
                  },
                  child: const Text('Copier', style: TextStyle(color: Palette.papier)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EcranFiche(maisonId: widget.maisonId, profil: widget.profil, membreId: widget.profil.id),
              ),
            ),
            style: boutonSecondaire(),
            child: const Text('MON PROFIL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          const SizedBox(height: 24),
          const Text('Mes maisons', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
          const SizedBox(height: 4),
          if (_mesMaisons == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(color: Palette.encre, backgroundColor: Palette.trait),
            )
          else
            for (final maison in _mesMaisons!) _ligneMaison(maison),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EcranMaison(profil: widget.profil)),
            ),
            style: boutonSecondaire(),
            child: const Text('+ AJOUTER OU REJOINDRE UNE MAISON', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          const SizedBox(height: 28),
          const Text('Rappel quotidien', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: Palette.papier,
            activeTrackColor: Palette.encre,
            value: _rappelActif,
            onChanged: (v) => _changerRappel(actif: v),
            title: const Text('Me rappeler les tâches du jour', style: TextStyle(color: Palette.encre)),
            subtitle: const Text(
              'Une seule notification par jour. Aucune si rien n\'est à faire.',
              style: TextStyle(fontSize: 12, color: Palette.encreFaible),
            ),
          ),
          if (_rappelActif) ...[
            InkWell(
              onTap: _choisirHeure,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 20, color: Palette.encreDouce),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Heure du rappel', style: TextStyle(color: Palette.encre))),
                    Text(_rappelHeure, style: const TextStyle(fontWeight: FontWeight.bold, color: Palette.encre)),
                    const SizedBox(width: 6),
                    const Text('modifier ›', style: TextStyle(fontSize: 12, color: Palette.encreDouce)),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: _testerRappel,
              child: const Text('Voir ce que ça donne maintenant', style: TextStyle(color: Palette.encreDouce)),
            ),
          ],
          const SizedBox(height: 28),
          const Text('Cette maison', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.encreDouce)),
          const SizedBox(height: 8),
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
          Center(
            child: TextButton(
              onPressed: _supprimerMaison,
              child: const Text('Supprimer cette maison', style: TextStyle(color: Palette.rouge, decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligneMaison(Map<String, dynamic> maison) {
    final estAffichee = maison['id'] == widget.maisonId;
    return InkWell(
      onTap: estAffichee ? null : () => _basculer(maison['id'] as String),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(estAffichee ? Icons.home : Icons.home_outlined, color: estAffichee ? Palette.encre : Palette.encreFaible, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                maison['nom'] as String,
                style: TextStyle(fontWeight: estAffichee ? FontWeight.bold : FontWeight.w500, color: Palette.encre),
              ),
            ),
            Text(
              estAffichee ? 'affichée' : 'ouvrir ›',
              style: TextStyle(fontSize: 12, color: estAffichee ? Palette.encreFaible : Palette.encreDouce),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligneMembre(Map<String, dynamic> membre) {
    final estMoi = membre['id'] == widget.profil.id;
    final prenom = membre['prenom'] as String;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EcranFiche(maisonId: widget.maisonId, profil: widget.profil, membreId: membre['id'] as String)),
      ),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          PastilleMembre(membre: membre),
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
      ),
    );
  }
}
