"""Chaîne de production d'une saison de la boutique (§ 27).

  python scripts/saison.py prompts  scripts/saison-1-hiver.json
      -> écrit arrivage/<saison>/PROMPTS.txt : un prompt complet par image, à
         coller un par un dans le générateur d'images.

  python scripts/saison.py recherche scripts/saison-1-hiver.json
      -> écrit arrivage/<saison>/PROMPT-RECHERCHE.txt : UN grand prompt pour un
         assistant qui cherche les images sur internet, une par une.

  python scripts/saison.py ranger   scripts/saison-1-hiver.json
      -> prend les images déposées dans arrivage/<saison>/ (dans l'ordre où
         elles ont été téléchargées), les renomme `<type>_<rareté>_<id>.webp`,
         les redimensionne, les range dans public/catalogue/chez-nous/<saison>/,
         met à jour catalogue.json et régénère la galerie.

Options de `ranger` : --arrivage DIR  --dest DIR  --force
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image

RACINE = Path(__file__).resolve().parent.parent
PRIX = {"commun": 40, "rare": 100, "epique": 250, "legendaire": 600}
EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
TAILLE_AVATAR = 384
TAILLE_COUVERTURE = (1200, 400)  # 3:1


def lire(chemin):
    return json.loads(Path(chemin).read_text(encoding="utf-8"))


def prompt_complet(d, o):
    fmt = d["formatAvatar"].replace("{fond}", o["fond"]) if o["type"] == "avatar" else d["formatCouverture"]
    return f'{o["sujet"]} {d["style"]} {fmt}'


def nom_fichier(o):
    dossier = "avatars" if o["type"] == "avatar" else "couvertures"
    return dossier, f'{o["type"]}_{o["rarete"]}_{o["id"]}.webp'


def commande_prompts(args):
    d = lire(args.fichier)
    saison = d["saison"]["id"]
    sortie = RACINE / "arrivage" / saison
    sortie.mkdir(parents=True, exist_ok=True)
    lignes = [
        f'PROMPTS — {d["saison"]["nom"]} ({len(d["objets"])} images)',
        "",
        "MODE D'EMPLOI",
        "1. Ouvre une nouvelle conversation dans le générateur d'images.",
        "2. Colle le prompt n°1, attends l'image. S'il en propose plusieurs, garde la meilleure.",
        "3. Si le style te plaît, continue DANS LA MÊME conversation avec le n°2, le n°3, etc. (le style reste cohérent).",
        "   S'il ne te plaît pas, redemande le n°1 autrement (« plus simple », « plus coloré »…) avant de continuer.",
        "4. Télécharge chaque image APRÈS l'avoir validée, dans l'ordre des numéros. Ne télécharge rien d'autre.",
        f'5. Quand tu as tout, dépose les fichiers dans : {sortie}',
        "   puis dis-moi « c'est dans l'arrivage » : je renomme, range et publie la galerie pour validation.",
        "",
        "Chaque prompt est complet : on peut le coller seul, même dans une nouvelle conversation.",
        "=" * 70,
    ]
    for o in d["objets"]:
        dossier, fichier = nom_fichier(o)
        lignes += [
            "",
            f'### {o["n"]}/{len(d["objets"])} — {o["nom"]}  [{o["rarete"]}, {o["type"]}]',
            f"Sera rangé sous : {d['saison']['id']}/{dossier}/{fichier}",
            "",
            prompt_complet(d, o),
            "",
            "-" * 70,
        ]
    cible = sortie / "PROMPTS.txt"
    cible.write_text("\n".join(lignes), encoding="utf-8")
    print(f"Prompts écrits : {cible}")


BRIEF_RECHERCHE = """MISSION : trouver sur internet {total} images pour l'application de ménage « Nickel » (usage strictement privé : un foyer de trois personnes). Tu les cherches UNE PAR UNE, comme sur Pinterest, tu en choisis une par fiche et tu la télécharges.

UNIVERS DU FOYER : technologie et IA, sport (ultimate frisbee), musique (Chinese Man, techno, Les Kassos), animés et séries (One Piece, Game of Thrones, House of the Dragon). Thème de cette saison : « {theme} ». Les clins d'œil à ces univers sont bienvenus.

OÙ CHERCHER
- Avatars (illustrations rondes de personnages ou emblèmes) : Pinterest, Google Images (filtre « Illustration »), ArtStation, DeviantArt, Behance, Dribbble, Freepik, Flaticon, itch.io.
- Couvertures (paysages panoramiques) : Wallhaven, Unsplash, Pexels, Pinterest, ArtStation, Google Images (filtre « Grande taille »).

CRITÈRES DE QUALITÉ (très important : l'ensemble doit être beau ET cohérent)
- COHÉRENCE : tous les AVATARS doivent appartenir à la même famille visuelle — illustration stylisée, aplats de couleurs, contours nets, personnage ou emblème centré, façon « mascotte / blason de collection ». Évite de mélanger photo réaliste, pixel art, aquarelle et vectoriel. Avant de retenir une image, compare-la avec celles déjà retenues. Toutes les COUVERTURES : même ambiance (illustration ou concept art, couleurs travaillées), jamais de photo floue.
- AVATARS : sujet unique bien centré qui rentre dans un cercle, bords dégagés, fond simple, au moins 512 × 512 px.
- COUVERTURES : panoramique (16:9 ou plus large), au moins 1600 px de large, sujet principal dans la bande horizontale centrale (le haut et le bas seront recadrés).
- REFUSE : filigrane, logo de site, texte incrusté, signature envahissante, capture d'écran d'une page, image floue ou compressée, visages de personnes réelles, contenu choquant ou sexualisé, image déjà utilisée pour une autre fiche.
- Si une fiche propose plusieurs intentions (ex. « éponge ET seau »), prends l'image qui s'en rapproche le plus ; sinon une version générique du même sujet, mais JAMAIS un sujet différent.

MÉTHODE
1. Commence par les fiches n°1 et n°{premiere_couverture} SEULEMENT, puis ARRÊTE-TOI et montre-moi les deux images choisies avec leur lien source. Ne continue que si je dis « ok ».
2. Pour chaque fiche : essaie les requêtes proposées (et tes propres variantes, en français et en anglais), parcours au moins 15 résultats, retiens 3 candidates, choisis la meilleure selon les critères, puis télécharge-la.
3. Enregistre chaque image en gardant son format d'origine et en commençant son nom de fichier par le numéro de la fiche sur deux chiffres (exemple : « 01_louveteau.jpg », « 13_plaine.jpg »). Si tu ne peux pas choisir le nom, télécharge les images STRICTEMENT dans l'ordre des numéros, une seule image par fiche, rien d'autre.
4. Si tu ne trouves rien de satisfaisant après 3 séries de recherches, ne force pas : écris « À REFAIRE » pour cette fiche, propose 3 alternatives de sujet proches, et passe à la suivante.
5. Ne te connecte jamais à un compte à ma place, ne paie rien, n'accepte aucune condition d'utilisation, ne saisis aucun mot de passe : si un site l'exige, passe au suivant.

À LA FIN, donne-moi un tableau : n° | nom de la fiche | nom du fichier téléchargé | adresse de la page source | pourquoi cette image | « OK » ou « À REFAIRE ».

LES {total} FICHES
{fiches}
"""


def commande_recherche(args):
    d = lire(args.fichier)
    saison = d["saison"]["id"]
    sortie = RACINE / "arrivage" / saison
    sortie.mkdir(parents=True, exist_ok=True)
    premiere_couverture = next(o["n"] for o in d["objets"] if o["type"] == "couverture")
    fiches = []
    for o in d["objets"]:
        r = o["recherche"]
        genre = "AVATAR (rond, 1:1)" if o["type"] == "avatar" else "COUVERTURE (panoramique)"
        fiches.append(
            f'\n--- FICHE {o["n"]:02d}/{len(d["objets"])} — {o["nom"]} — {genre} — rareté {o["rarete"]} ---\n'
            f'Ce qu\'on veut voir : {r["decrit"]}\n'
            f'Requêtes pour commencer : ' + " | ".join(r["requetes"])
        )
    texte = BRIEF_RECHERCHE.format(
        total=len(d["objets"]), theme=d["saison"]["theme"], premiere_couverture=premiere_couverture, fiches="\n".join(fiches)
    )
    cible = sortie / "PROMPT-RECHERCHE.txt"
    cible.write_text(texte, encoding="utf-8")
    print(f"Prompt de recherche écrit : {cible} ({len(texte)} caractères)")


def recadrer(img, ratio_l, ratio_h, taille):
    img = img.convert("RGB")
    w, h = img.size
    cible_ratio = ratio_l / ratio_h
    if w / h > cible_ratio:
        nw = int(h * cible_ratio)
        img = img.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w / cible_ratio)
        img = img.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    return img.resize(taille, Image.LANCZOS)


def commande_ranger(args):
    d = lire(args.fichier)
    saison = d["saison"]
    arrivage = Path(args.arrivage) if args.arrivage else RACINE / "arrivage" / saison["id"]
    dest = Path(args.dest) if args.dest else RACINE / "public" / "catalogue" / "chez-nous"
    fichiers = sorted(
        [f for f in arrivage.iterdir() if f.suffix.lower() in EXTENSIONS],
        key=lambda f: (f.stat().st_mtime, f.name),
    )
    objets = d["objets"]
    if not fichiers:
        sys.exit(f"Aucune image dans {arrivage}")

    # Fichiers numérotés (« 01_louveteau.jpg ») : le numéro fait foi, pas l'ordre
    # de téléchargement. Sinon : ordre de téléchargement.
    numerotes = {}
    for f in fichiers:
        m = re.match(r"^(\d{1,2})[\s_.\-]", f.name)
        if m:
            numerotes.setdefault(int(m.group(1)), f)
    if len(numerotes) == len(fichiers):
        par_n = {o["n"]: o for o in objets}
        paires = [(numerotes[n], par_n[n]) for n in sorted(numerotes) if n in par_n]
        manquantes = [o["n"] for o in objets if o["n"] not in numerotes]
        print(f"Fichiers numérotés détectés. Fiches sans image : {manquantes or 'aucune'}")
    else:
        if len(fichiers) != len(objets):
            print(f"ATTENTION : {len(fichiers)} image(s) pour {len(objets)} fiche(s) — rangement dans l'ordre de téléchargement, jusqu'à épuisement.")
        paires = list(zip(fichiers, objets))

    catalogue_chemin = dest / "catalogue.json"
    catalogue = json.loads(catalogue_chemin.read_text(encoding="utf-8"))
    if not any(s["id"] == saison["id"] for s in catalogue["saisons"]):
        catalogue["saisons"].append(saison)

    print(f'{"n":>3}  {"fichier déposé":<40} -> nom rangé')
    for f, o in paires:
        sous, nom = nom_fichier(o)
        cible = dest / saison["id"] / sous / nom
        if cible.exists() and not args.force:
            print(f'{o["n"]:>3}  {f.name:<40} -> DÉJÀ PRÉSENT (ignoré, --force pour remplacer)')
            continue
        cible.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(f) as img:
            if o["type"] == "avatar":
                out = recadrer(img, 1, 1, (TAILLE_AVATAR, TAILLE_AVATAR))
            else:
                out = recadrer(img, 3, 1, TAILLE_COUVERTURE)
            out.save(cible, "WEBP", quality=85, method=6)
        entree = {
            "id": o["id"], "type": o["type"], "nom": o["nom"], "rarete": o["rarete"],
            "prix": PRIX[o["rarete"]], "image": f'{saison["id"]}/{sous}/{nom}', "saison": saison["id"],
        }
        catalogue["objets"] = [x for x in catalogue["objets"] if x["id"] != o["id"]] + [entree]
        print(f'{o["n"]:>3}  {f.name:<40} -> {sous}/{nom}  ({cible.stat().st_size // 1024} Ko)')

    catalogue_chemin.write_text(json.dumps(catalogue, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if not args.dest:
        subprocess.run(["node", str(RACINE / "scripts" / "generer-galerie.mjs")], check=True)


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("prompts")
    a.add_argument("fichier")
    b = sub.add_parser("recherche")
    b.add_argument("fichier")
    r = sub.add_parser("ranger")
    r.add_argument("fichier")
    r.add_argument("--arrivage")
    r.add_argument("--dest")
    r.add_argument("--force", action="store_true")
    args = p.parse_args()
    {"prompts": commande_prompts, "recherche": commande_recherche, "ranger": commande_ranger}[args.cmd](args)


if __name__ == "__main__":
    main()
