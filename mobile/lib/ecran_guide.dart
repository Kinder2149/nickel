import 'package:flutter/material.dart';

import 'jeu.dart';
import 'palette.dart';

/// « Comment ça marche ? » — le système expliqué en clair : XP, niveaux,
/// séries, succès, déblocages. Les chiffres viennent des mêmes listes que
/// le jeu (jamais recopiés à la main : ils ne peuvent pas dériver).
class EcranGuide extends StatelessWidget {
  const EcranGuide({super.key});

  Widget _titre(String texte) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 8),
        child: Text(texte, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Palette.encre)),
      );

  Widget _texte(String texte) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texte, style: const TextStyle(color: Palette.encreDouce, height: 1.4)),
      );

  Widget _encart(List<Widget> enfants) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Palette.papierClair, border: Border.all(color: Palette.trait, width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: enfants),
      );

  @override
  Widget build(BuildContext context) {
    final parRarete = {for (final r in Rarete.values) r: succes.where((s) => s.rarete == r).length};

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.papier,
        foregroundColor: Palette.encre,
        elevation: 0,
        title: const Text('Comment ça marche ?', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 40),
        children: [
          _texte('Chaque tâche cochée fait gagner de l\'XP. L\'XP fait monter de niveau et débloque des succès. Ici, on joue ensemble : la maison a aussi son niveau.'),
          _titre('L\'XP'),
          _texte('Une tâche rapporte autant d\'XP que sa durée en minutes (entre 5 et 60). Plus c\'est long ou pénible, plus ça rapporte.'),
          _encart(const [
            Text('Vider le verre → 5 XP', style: TextStyle(color: Palette.encre)),
            Text('Nettoyer le four → 15 XP', style: TextStyle(color: Palette.encre)),
            Text('Laver les sols carrelés → 30 XP', style: TextStyle(color: Palette.encre)),
            Text('Nettoyer le frigo à fond → 45 XP', style: TextStyle(color: Palette.encre)),
          ]),
          _texte(''),
          _texte('Cocher par erreur puis annuler retire l\'XP. Cocher en avance compte aussi.'),
          _titre('Les niveaux'),
          _encart([
            for (var n = 1; n <= 10; n++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text('Niveau $n', style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.encre))),
                    Expanded(child: Text(titreNiveau(n), style: const TextStyle(color: Palette.encre))),
                    Text('${xpPourNiveau(n)} XP', style: const TextStyle(color: Palette.encreDouce)),
                  ],
                ),
              ),
          ]),
          _titre('Les séries'),
          _texte('Faire au moins une tâche chaque jour allonge ta série. Elle ne se casse qu\'à minuit : si tu n\'as encore rien fait aujourd\'hui, hier compte encore. Les séries débloquent des succès de plus en plus rares.'),
          _titre('Les succès'),
          _texte('${succes.length} succès à débloquer, répartis en quatre raretés :'),
          _encart([
            for (final r in Rarete.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, color: r.couleur),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r.libelle, style: TextStyle(fontWeight: FontWeight.w700, color: r.couleur))),
                    Text('${parRarete[r]} succès', style: const TextStyle(color: Palette.encreDouce)),
                  ],
                ),
              ),
          ]),
          _texte(''),
          _texte('Sur ta fiche, « Prochains objectifs » montre les 3 succès les plus proches, avec ta progression. Certains sont collectifs : ils ne se débloquent que si toute la maison joue le jeu.'),
          _titre('Les badges'),
          _texte('Tu choisis 3 de tes succès débloqués pour les afficher sur ta fiche. Les autres membres les voient dans l\'onglet Équipe.'),
          _titre('Les Bulles et la boutique'),
          _texte('Les Bulles sont la monnaie du jeu. On en gagne en montant de niveau et en débloquant des succès. On les dépense à la boutique (icône magasin sur ta fiche) contre des avatars et des couvertures.'),
          _encart([
            Text('Chaque niveau : ${bullesNiveau(2)} Bulles au niveau 2, ${bullesNiveau(10)} au niveau 10', style: const TextStyle(color: Palette.encre)),
            for (final r in Rarete.values)
              Text('Succès ${r.libelle.toLowerCase()} : ${bullesSucces(r)} Bulles', style: TextStyle(color: r.couleur, fontWeight: FontWeight.w600)),
          ]),
          _texte(''),
          _texte('On ne peut pas tout acheter : à toi de choisir. Certains objets sont exclusifs, ils ne s\'achètent pas et se gagnent avec un succès précis. Un kit de départ est gratuit pour tout le monde.'),
          _titre('La maison'),
          _texte('Tout l\'XP de tous les habitants fait monter le niveau de la maison. Personne n\'est classé : on progresse ensemble. Le succès « Tous ensemble » se débloque quand chacun a fait au moins une tâche dans la semaine.'),
        ],
      ),
    );
  }
}
