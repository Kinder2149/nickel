"""Chaîne de production d'une saison de la boutique (§ 27).

  python scripts/saison.py prompts  scripts/saison-1-hiver.json
      -> écrit arrivage/<saison>/PROMPTS.txt : un prompt complet par image, à
         coller un par un dans le générateur d'images.

  python scripts/saison.py ranger   scripts/saison-1-hiver.json
      -> prend les images déposées dans arrivage/<saison>/ (dans l'ordre où
         elles ont été téléchargées), les renomme `<type>_<rareté>_<id>.webp`,
         les redimensionne, les range dans public/catalogue/chez-nous/<saison>/,
         met à jour catalogue.json et régénère la galerie.

Options de `ranger` : --arrivage DIR  --dest DIR  --force
"""
import argparse
import json
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
    if len(fichiers) != len(objets):
        print(f"ATTENTION : {len(fichiers)} image(s) pour {len(objets)} prompt(s) — rangement dans l'ordre, jusqu'à épuisement.")

    catalogue_chemin = dest / "catalogue.json"
    catalogue = json.loads(catalogue_chemin.read_text(encoding="utf-8"))
    if not any(s["id"] == saison["id"] for s in catalogue["saisons"]):
        catalogue["saisons"].append(saison)

    print(f'{"n":>3}  {"fichier déposé":<40} -> nom rangé')
    for f, o in zip(fichiers, objets):
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
    r = sub.add_parser("ranger")
    r.add_argument("fichier")
    r.add_argument("--arrivage")
    r.add_argument("--dest")
    r.add_argument("--force", action="store_true")
    args = p.parse_args()
    {"prompts": commande_prompts, "ranger": commande_ranger}[args.cmd](args)


if __name__ == "__main__":
    main()
