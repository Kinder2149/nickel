import 'package:flutter/material.dart';

import 'astuces.dart';
import 'palette.dart';

/// Onglet "Astuces" : la deuxième porte de l'app (§ 21). Soit on fait les
/// tâches du jour, soit on cherche comment s'y prendre. Une recherche, des
/// catégories, et les pages de référence (sécurité, produits, recettes).
class EcranAstuces extends StatefulWidget {
  const EcranAstuces({super.key});

  @override
  State<EcranAstuces> createState() => _EcranAstucesState();
}

class _EcranAstucesState extends State<EcranAstuces> {
  final _recherche = TextEditingController();
  Bibliotheque? _bibliotheque;
  String? _categorie;
  String _requete = '';

  @override
  void initState() {
    super.initState();
    chargerBibliotheque().then((b) {
      if (mounted) setState(() => _bibliotheque = b);
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  List<Astuce> get _resultats {
    final b = _bibliotheque!;
    final requete = normaliserRecherche(_requete);
    final retenues = b.astuces.where((a) {
      if (_categorie != null && a.categorie != _categorie) return false;
      return requete.isEmpty || a.pertinence(requete) > 0;
    }).toList();

    if (requete.isNotEmpty) {
      // Tri stable : les correspondances de titre d'abord, l'ordre de la
      // bibliothèque ensuite.
      final indices = {for (final (i, a) in retenues.indexed) a.id: i};
      retenues.sort((x, y) {
        final parPertinence = y.pertinence(requete).compareTo(x.pertinence(requete));
        return parPertinence != 0 ? parPertinence : indices[x.id]!.compareTo(indices[y.id]!);
      });
    }
    return retenues;
  }

  @override
  Widget build(BuildContext context) {
    final b = _bibliotheque;

    return Scaffold(
      body: SafeArea(
        child: b == null
            ? const Center(child: CircularProgressIndicator(color: Palette.encre))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'ASTUCES',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.5, color: Palette.encreFaible),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _recherche,
                          onChanged: (v) => setState(() => _requete = v),
                          decoration: decorationChamp('Chercher : four, vin, calcaire…').copyWith(
                            prefixIcon: const Icon(Icons.search, color: Palette.encreDouce),
                            suffixIcon: _requete.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close, color: Palette.encreDouce),
                                    onPressed: () {
                                      _recherche.clear();
                                      setState(() => _requete = '');
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _ouvrirSecurite(b),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Palette.rouge,
                                  side: const BorderSide(color: Palette.rouge, width: 1.5),
                                  shape: const RoundedRectangleBorder(),
                                ),
                                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                                label: const Text('Sécurité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _ouvrirProduits(b),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Palette.encre,
                                  side: const BorderSide(color: Palette.encre, width: 1.5),
                                  shape: const RoundedRectangleBorder(),
                                ),
                                icon: const Icon(Icons.science_outlined, size: 18),
                                label: const Text('Produits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      children: [
                        _puce('Tout', _categorie == null, () => setState(() => _categorie = null)),
                        for (final c in b.categories)
                          _puce(c, _categorie == c, () => setState(() => _categorie = _categorie == c ? null : c)),
                      ],
                    ),
                  ),
                  Expanded(child: _liste()),
                ],
              ),
      ),
    );
  }

  Widget _puce(String texte, bool choisie, VoidCallback surAppui) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: surAppui,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: choisie ? Palette.encre : Palette.papierClair,
            border: Border.all(color: choisie ? Palette.encre : Palette.trait),
          ),
          alignment: Alignment.center,
          child: Text(
            texte,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: choisie ? Palette.papier : Palette.encreDouce,
            ),
          ),
        ),
      ),
    );
  }

  Widget _liste() {
    final resultats = _resultats;
    if (resultats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(22),
        child: Text('Aucune astuce ne correspond.', style: TextStyle(color: Palette.encreDouce)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      itemCount: resultats.length,
      separatorBuilder: (context, index) => const Divider(color: Palette.trait, height: 1),
      itemBuilder: (context, index) {
        final a = resultats[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => _ouvrirAstuce(a),
          title: Text(a.titre, style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.encre)),
          subtitle: Text(
            '${a.sujet} · ${a.categorie}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Palette.encreFaible),
          ),
          trailing: _marqueur(a.fiabilite),
        );
      },
    );
  }

  Widget _marqueur(Fiabilite f) {
    final (couleur, icone) = switch (f) {
      Fiabilite.solide => (Palette.vert, Icons.check),
      Fiabilite.limites => (Palette.encreDouce, Icons.error_outline),
      Fiabilite.mythe => (Palette.rouge, Icons.block),
    };
    return Icon(icone, color: couleur, size: 20);
  }

  void _ouvrirAstuce(Astuce a) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.papier,
      builder: (contexte) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.titre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.encre)),
              const SizedBox(height: 4),
              Text('${a.sujet} · ${a.categorie}', style: const TextStyle(color: Palette.encreDouce)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _marqueur(a.fiabilite),
                  const SizedBox(width: 8),
                  Text(
                    a.fiabilite.libelle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: switch (a.fiabilite) {
                        Fiabilite.solide => Palette.vert,
                        Fiabilite.limites => Palette.encreDouce,
                        Fiabilite.mythe => Palette.rouge,
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(a.texte, style: const TextStyle(fontSize: 15, height: 1.4, color: Palette.encre)),
              const SizedBox(height: 20),
              const Text(
                'Avant tout mélange de produits, vérifiez la page Sécurité.',
                style: TextStyle(fontSize: 12, color: Palette.encreFaible),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ouvrirSecurite(Bibliotheque b) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          backgroundColor: Palette.papier,
          foregroundColor: Palette.encre,
          elevation: 0,
          title: const Text('Sécurité', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              color: Palette.rouge,
              child: const Text(
                'À lire avant tout le reste. Certains mélanges de produits dégagent des gaz toxiques.',
                style: TextStyle(color: Palette.papier, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            for (final (i, regle) in b.securite.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.bold, color: Palette.rouge)),
                    ),
                    Expanded(child: Text(regle, style: const TextStyle(height: 1.4, color: Palette.encre))),
                  ],
                ),
              ),
          ],
        ),
      ),
    ));
  }

  void _ouvrirProduits(Bibliotheque b) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Palette.papier,
            foregroundColor: Palette.encre,
            elevation: 0,
            title: const Text('Produits et méthode', style: TextStyle(fontWeight: FontWeight.w900)),
            bottom: const TabBar(
              labelColor: Palette.encre,
              unselectedLabelColor: Palette.encreFaible,
              indicatorColor: Palette.encre,
              tabs: [Tab(text: 'Produits'), Tab(text: 'Recettes'), Tab(text: 'Méthode')],
            ),
          ),
          body: TabBarView(
            children: [
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
                itemCount: b.produits.length,
                separatorBuilder: (context, index) => const Divider(color: Palette.trait),
                itemBuilder: (context, index) {
                  final p = b.produits[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nom, style: const TextStyle(fontWeight: FontWeight.bold, color: Palette.encre)),
                      Text(p.famille, style: const TextStyle(fontSize: 12, color: Palette.encreFaible)),
                      const SizedBox(height: 6),
                      Text('Sert à : ${p.sertA}', style: const TextStyle(color: Palette.encre)),
                      if (p.jamaisAvec.isNotEmpty && p.jamaisAvec != '—')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Jamais avec : ${p.jamaisAvec}', style: const TextStyle(color: Palette.rouge)),
                        ),
                    ],
                  );
                },
              ),
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
                itemCount: b.recettes.length,
                separatorBuilder: (context, index) => const Divider(color: Palette.trait),
                itemBuilder: (context, index) {
                  final r = b.recettes[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.nom, style: const TextStyle(fontWeight: FontWeight.bold, color: Palette.encre)),
                      const SizedBox(height: 4),
                      Text(r.methode, style: const TextStyle(color: Palette.encre)),
                    ],
                  );
                },
              ),
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
                itemCount: b.methode.length,
                separatorBuilder: (context, index) => const Divider(color: Palette.trait),
                itemBuilder: (context, index) {
                  final m = b.methode[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.titre, style: const TextStyle(fontWeight: FontWeight.bold, color: Palette.encre)),
                      const SizedBox(height: 4),
                      Text(m.texte, style: const TextStyle(color: Palette.encre)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
