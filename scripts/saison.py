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
import io
import json
import re
import subprocess
import sys
import time
import urllib.request
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


BRIEF_RECHERCHE = """MISSION : trouver sur internet {total} images pour l'application de ménage « Nickel » (usage strictement privé : un foyer de trois personnes). Tu les cherches UNE PAR UNE, comme sur Pinterest, tu en choisis une par fiche et tu me donnes ses LIENS. TU NE TÉLÉCHARGES RIEN : c'est moi qui récupérerai les fichiers à partir de tes liens.

UNIVERS DU FOYER : technologie et IA, sport (ultimate frisbee), musique (Chinese Man, techno, Les Kassos), animés et séries (One Piece, Game of Thrones, House of the Dragon). Thème de cette saison : « {theme} ». Les personnages, objets et lieux RÉELS de ces œuvres ou de ces univers sont attendus et bienvenus (usage privé) : cherche directement leurs illustrations, fan arts, logos et fonds d'écran.

OÙ CHERCHER
- Avatars (illustrations rondes de personnages ou emblèmes) : Pinterest, Google Images (filtre « Illustration »), ArtStation, DeviantArt, Behance, Dribbble, Freepik, Flaticon, itch.io.
- Couvertures (paysages panoramiques) : Wallhaven, Unsplash, Pexels, Pinterest, ArtStation, Google Images (filtre « Grande taille »).

CRITÈRES DE QUALITÉ (très important : l'ensemble doit être beau ET cohérent)
- COHÉRENCE : tous les AVATARS doivent appartenir à la même famille visuelle — illustration stylisée, aplats de couleurs, contours nets, sujet centré, façon « mascotte / sticker / blason de collection ». Évite de mélanger photo réaliste, pixel art, aquarelle et vectoriel. Avant de retenir une image, compare-la avec celles déjà retenues. Toutes les COUVERTURES : même ambiance (illustration ou concept art, couleurs travaillées), jamais de photo floue.
- AVATARS : sujet unique bien centré qui rentre dans un cercle, bords dégagés, fond simple, au moins 512 × 512 px.
- COUVERTURES : panoramique (16:9 ou plus large), au moins 1600 px de large, sujet principal dans la bande horizontale centrale (le haut et le bas seront recadrés).
- REFUSE : filigrane, logo de site, texte incrusté, signature envahissante, capture d'écran d'une page, image floue ou compressée, visages de personnes réelles, contenu choquant ou sexualisé, image déjà retenue pour une autre fiche.
- Si une fiche propose plusieurs intentions, prends l'image qui s'en rapproche le plus ; sinon une version générique du même sujet, mais JAMAIS un sujet différent. Vérifie bien que le sujet est celui demandé (ne confonds pas les œuvres).

MÉTHODE
1. Commence par les fiches n°1 et n°{premiere_couverture} SEULEMENT, puis ARRÊTE-TOI : montre-moi les deux images choisies avec leurs liens et ATTENDS ma réponse « ok ». Ne passe JAMAIS aux fiches suivantes de ta propre initiative, même si tout se passe bien. Fais ensuite les fiches par paquets de 5, en t'arrêtant à chaque fin de paquet.
2. Pour chaque fiche : essaie les requêtes proposées (et tes propres variantes, en français et en anglais), parcours au moins 15 résultats, retiens 3 candidates, choisis la meilleure selon les critères.
3. UNE SEULE image retenue par fiche : la version FINALE (pas de variantes). Pour elle, donne : l'adresse de la page source (forme « pinterest.com/pin/NUMÉRO » ou « wallhaven.cc/w/CODE ») et, si tu la connais, l'adresse directe de l'image.
4. Si tu ne trouves rien de satisfaisant après 3 séries de recherches, ne force pas : écris « À REFAIRE » pour cette fiche, propose 3 alternatives de sujet proches, et passe à la suivante.
5. Ne te connecte jamais à un compte à ma place, ne paie rien, n'accepte aucune condition d'utilisation, ne saisis aucun mot de passe : si un site l'exige, passe au suivant.

FORMAT DE RÉPONSE : un tableau, UNE LIGNE PAR FICHE, qui commence par le numéro de la fiche sur deux chiffres, puis : nom de la fiche | adresse de la page source | dimensions de l'image | pourquoi cette image | « OK » ou « À REFAIRE ». Exemple : « 01 | Chapeau de paille | https://fr.pinterest.com/pin/123456789/ | 750×1000 | trait net, centré | OK ».

LES {total} FICHES
{fiches}
"""


def commande_recherche(args):
    d = lire(args.fichier)
    saison = d["saison"]["id"]
    sortie = RACINE / "arrivage" / saison
    sortie.mkdir(parents=True, exist_ok=True)
    premiere_couverture = next(o["n"] for o in d["objets"] if o["type"] == "couverture")
    voulues = {int(x) for x in args.seulement.split(",")} if getattr(args, "seulement", None) else None
    fiches = []
    for o in d["objets"]:
        if voulues is not None and o["n"] not in voulues:
            continue
        r = o["recherche"]
        genre = "AVATAR (rond, 1:1)" if o["type"] == "avatar" else "COUVERTURE (panoramique)"
        fiches.append(
            f'\n--- FICHE {o["n"]:02d}/{len(d["objets"])} — {o["nom"]} — {genre} — rareté {o["rarete"]} ---\n'
            f'Ce qu\'on veut voir : {r["decrit"]}\n'
            f'Requêtes pour commencer : ' + " | ".join(r["requetes"])
        )
    texte = BRIEF_RECHERCHE.format(
        total=len(fiches), theme=d["saison"]["theme"], premiere_couverture=premiere_couverture, fiches="\n".join(fiches)
    )
    if voulues is not None:
        # Reprise de quelques fiches : pas de contrôle « fiche 1 + première couverture ».
        debut = texte.index("1. Commence par les fiches")
        fin = texte.index("2. Pour chaque fiche")
        texte = texte[:debut] + "1. Traite uniquement les fiches ci-dessous, puis ARRÊTE-TOI et attends ma réponse avant toute autre action." + chr(10) + texte[fin:]
    nom_sortie = "PROMPT-RECHERCHE.txt" if voulues is None else "PROMPT-RECHERCHE-" + "-".join(str(x) for x in sorted(voulues)) + ".txt"
    cible = sortie / nom_sortie
    cible.write_text(texte, encoding="utf-8")
    print(f"Prompt de recherche écrit : {cible} ({len(texte)} caractères)")


UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"


def http_get(url, referer=None, timeout=60):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "fr,en;q=0.8", **({"Referer": referer} if referer else {})})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read(), r.headers.get("Content-Type", "")


def adresses_image(lien):
    """Adresses directes possibles de l'image pour une page Pinterest ou Wallhaven."""
    m = re.search(r"pinterest\.[a-z.]+/pin/(\d+)", lien)
    if m:
        html = http_get(f"https://fr.pinterest.com/pin/{m.group(1)}/")[0].decode("utf-8", "replace")
        og = re.search(r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"', html) or re.search(r'content="([^"]+)"[^>]+property="og:image"', html)
        cands = ([og.group(1)] if og else []) + re.findall(r"https://i\.pinimg\.com/(?:originals|736x|564x|474x)/[0-9a-f/]+\.(?:jpg|png|webp)", html)
        essais = []
        for c in cands:
            base = re.sub(r"/(?:\d+x|originals)/", "/originals/", c)
            essais += [base, re.sub(r"\.(jpg|png|webp)$", lambda x: ".png" if x.group(1) != "png" else ".jpg", base), c]
        return list(dict.fromkeys(essais)), "https://fr.pinterest.com/"
    m = re.search(r"wallhaven\.cc/w/([0-9a-z]+)", lien)
    if m:
        html = http_get(f"https://wallhaven.cc/w/{m.group(1)}")[0].decode("utf-8", "replace")
        src = re.search(r'id="wallpaper"[^>]+src="([^"]+)"', html)
        return ([src.group(1)] if src else []), "https://wallhaven.cc/"
    if re.search(r"https?://\S+\.(?:jpg|jpeg|png|webp)", lien):
        return [re.search(r"https?://\S+\.(?:jpg|jpeg|png|webp)", lien).group(0)], None
    return [], None


def commande_telecharger(args):
    """Télécharge les images listées dans le tableau de l'assistant. Seuls des
    FICHIERS IMAGE valides (vérifiés avec Pillow) sont enregistrés ; rien
    d'autre n'est écrit ni exécuté."""
    d = lire(args.fichier)
    saison = d["saison"]["id"]
    arrivage = Path(args.arrivage) if args.arrivage else RACINE / "arrivage" / saison
    arrivage.mkdir(parents=True, exist_ok=True)
    par_n = {o["n"]: o for o in d["objets"]}
    for ligne in Path(args.liens).read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\W*(\d{1,2})\b", ligne)
        if not m or int(m.group(1)) not in par_n:
            continue
        n = int(m.group(1))
        o = par_n[n]
        liens = re.findall(r"https?://[^\s|)\]>]+", ligne)
        etat = "ECHEC : aucun lien exploitable"
        for lien in liens:
            try:
                essais, referer = adresses_image(lien)
            except Exception as e:  # noqa: BLE001
                essais, referer = [], None
            for url in essais:
                try:
                    data, ctype = http_get(url, referer=referer, timeout=120)
                    if not ctype.startswith("image/") or len(data) < 5000:
                        continue
                    im = Image.open(io.BytesIO(data))
                    im.load()
                    ext = {"JPEG": "jpg", "PNG": "png", "WEBP": "webp"}.get(im.format)
                    if not ext:
                        continue
                    cible = arrivage / f"{n:02d}_{o['id']}.{ext}"
                    cible.write_bytes(data)
                    etat = f"OK  {cible.name}  {im.size[0]}x{im.size[1]}  {len(data) // 1024} Ko  <- {url}"
                    break
                except Exception:  # noqa: BLE001
                    continue
            if etat.startswith("OK"):
                break
            etat = "ECHEC : téléchargement refusé ou fichier invalide"
        print(f"{n:>2} {o['nom'][:32]:<32} {etat[:190]}")
        time.sleep(0.5)


def recadrer(img, ratio_l, ratio_h, taille, focus=(0.5, 0.5)):
    """Recadre au ratio voulu. `focus` = (x, y) entre 0 et 1 : où se trouve le
    sujet dans l'image (0.5, 0.5 = centre ; un visage en haut à droite = (0.7, 0.3))."""
    img = img.convert("RGB")
    w, h = img.size
    cible_ratio = ratio_l / ratio_h
    if w / h > cible_ratio:
        nw = int(h * cible_ratio)
        x0 = int((w - nw) * focus[0])
        img = img.crop((x0, 0, x0 + nw, h))
    else:
        nh = int(w / cible_ratio)
        y0 = int((h - nh) * focus[1])
        img = img.crop((0, y0, w, y0 + nh))
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
    # La fiche de saison du JSON fait foi (nom, thème, date de sortie) : on met à jour.
    catalogue["saisons"] = [s for s in catalogue["saisons"] if s["id"] != saison["id"]] + [saison]

    print(f'{"n":>3}  {"fichier déposé":<40} -> nom rangé')
    for f, o in paires:
        sous, nom = nom_fichier(o)
        cible = dest / saison["id"] / sous / nom
        if cible.exists() and not args.force:
            print(f'{o["n"]:>3}  {f.name:<40} -> DÉJÀ PRÉSENT (ignoré, --force pour remplacer)')
            continue
        cible.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(f) as img:
            if o.get("zone"):  # zone utile (fractions x0, y0, x1, y1) avant recadrage : cadrer serré sur le sujet
                w, h = img.size
                z = o["zone"]
                img = img.crop((int(z[0] * w), int(z[1] * h), int(z[2] * w), int(z[3] * h)))
            if o["type"] == "avatar":
                out = recadrer(img, 1, 1, (TAILLE_AVATAR, TAILLE_AVATAR), tuple(o.get("focus", (0.5, 0.5))))
            else:
                out = recadrer(img, 3, 1, TAILLE_COUVERTURE, tuple(o.get("focus", (0.5, 0.5))))
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
    b.add_argument("--seulement", help="numéros de fiches séparés par des virgules (ex. 14 ou 3,9)")
    t = sub.add_parser("telecharger")
    t.add_argument("fichier")
    t.add_argument("liens", help="fichier texte contenant le tableau de l'assistant (une ligne par fiche)")
    t.add_argument("--arrivage")
    r = sub.add_parser("ranger")
    r.add_argument("fichier")
    r.add_argument("--arrivage")
    r.add_argument("--dest")
    r.add_argument("--force", action="store_true")
    args = p.parse_args()
    {"prompts": commande_prompts, "recherche": commande_recherche, "telecharger": commande_telecharger, "ranger": commande_ranger}[args.cmd](args)


if __name__ == "__main__":
    main()
