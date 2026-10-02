import json, re, collections
from pathlib import Path

R = Path(r'V:\DEV\PROJETS\applications_mobile\Nickel')
cat = json.loads((R / 'public/catalogue/chez-nous/catalogue.json').read_text(encoding='utf-8'))
dart = (R / 'mobile/lib/catalogue.dart').read_text(encoding='utf-8')
emb = re.findall(r"Objet\(id: '([^']+)', type: TypeObjet\.(avatar|couverture)([^\n]*)", dart)
emb_ids = collections.defaultdict(list)
for i, t, reste in emb:
    emb_ids[i].append(t)
kit = [i for i, t, r in emb if 'prix:' not in r and 'succesRequis' not in r]
print('embarqués:', len(emb), '| kit gratuit:', len(kit), '| boutique de lancement + exclusifs:', len(emb) - len(kit))
remote = cat['objets']
print('distants:', len(remote), dict(collections.Counter(o['saison'] for o in remote)))
print('COLLISIONS id embarqué/distant:', [(o['id'], o['saison'], o['type']) for o in remote if o['id'] in emb_ids])
c = collections.Counter(o['id'] for o in remote)
print('doublons entre distants:', [k for k, v in c.items() if v > 1])
base = R / 'public/catalogue/chez-nous'
refs = {o['image'] for o in remote if o.get('image')}
fichiers = {p.relative_to(base).as_posix() for p in base.rglob('*') if p.is_file() and p.suffix in ('.webp', '.png', '.jpg')}
print('images référencées absentes du disque:', sorted(refs - fichiers))
print('fichiers images non référencés:', sorted(fichiers - refs))
print('objets sans visuel:', [o['id'] for o in remote if not o.get('image') and not o.get('couleurs')])
ss = {s['id'] for s in cat['saisons']}
print('saisons:', [(s['id'], s['debut']) for s in cat['saisons']])
print('objets à saison inconnue:', [o['id'] for o in remote if o['saison'] not in ss])
print('saisons vides:', [s for s in ss if s not in {o['saison'] for o in remote}])
# prix : cohérence rareté/prix
prix = {'commun': 40, 'rare': 100, 'epique': 250, 'legendaire': 600}
print('prix incohérents:', [(o['id'], o['rarete'], o['prix']) for o in remote if o['prix'] != prix[o['rarete']]])
# nombre par rareté
print('raretés distantes:', dict(collections.Counter(o['rarete'] for o in remote)))
