// Génère public/catalogue/chez-nous/galerie.html à partir de catalogue.json.
// Usage : node scripts/generer-galerie.mjs
//
// La galerie montre chaque objet avec son nom, sa rareté, son prix et
// COMMENT L'OBTENIR, pour valider le contenu sans lancer l'application.
// Les noms de succès sont lus dans mobile/lib/jeu.dart (une seule source).

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const racine = join(dirname(fileURLToPath(import.meta.url)), '..');
const dossier = join(racine, 'public', 'catalogue', 'chez-nous');
const catalogue = JSON.parse(readFileSync(join(dossier, 'catalogue.json'), 'utf8'));

const jeu = readFileSync(join(racine, 'mobile', 'lib', 'jeu.dart'), 'utf8');
const succes = {};
for (const m of jeu.matchAll(/Succes\('([^']+)', Icons\.\w+, (['"])(.+?)\2, (['"])(.+?)\4, Rarete\.(\w+)/g)) {
  succes[m[1]] = { nom: m[3], description: m[5], rarete: m[6] };
}

const saisons = Object.fromEntries((catalogue.saisons ?? []).map((s) => [s.id, s]));
const aujourdhui = new Date().toISOString().slice(0, 10);
const RARETES = { commun: 'Commun', rare: 'Rare', epique: 'Épique', legendaire: 'Légendaire' };
const COULEURS = { commun: '#6B675A', rare: '#2F6FB5', epique: '#8A3FC7', legendaire: '#B8860B' };
const echapper = (t) => String(t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

function commentObtenir(o) {
  if (o.succesRequis) {
    const s = succes[o.succesRequis];
    return s
      ? `Se gagne (ne s'achète pas) : succès « ${s.nom} » — ${s.description}`
      : `Se gagne avec le succès « ${o.succesRequis} » (introuvable dans le jeu : à corriger)`;
  }
  return o.prix > 0 ? `S'achète ${o.prix} Bulles à la boutique` : 'Gratuit';
}

function apercu(o) {
  if (o.image) return `<img src="${echapper(o.image)}" alt="${echapper(o.nom)}" class="${o.type}">`;
  if (o.couleurs?.length) {
    const fond = o.couleurs.length === 1 ? o.couleurs[0] : `linear-gradient(135deg, ${o.couleurs.join(', ')})`;
    return `<div class="couleur ${o.type}" style="background:${fond}"></div>`;
  }
  return '<div class="vide">pas d\'image</div>';
}

const objets = catalogue.objets ?? [];
const cartes = objets.map((o) => {
  const saison = saisons[o.saison];
  const sortie = saison?.debut ?? '';
  const pasSortie = sortie > aujourdhui;
  return `
  <article class="carte" data-saison="${echapper(o.saison ?? '')}" data-type="${o.type}" data-rarete="${o.rarete}"
           style="border-color:${COULEURS[o.rarete] ?? '#000'}">
    <div class="visuel">${apercu(o)}</div>
    <h3>${echapper(o.nom)}</h3>
    <p class="rarete" style="color:${COULEURS[o.rarete]}">${RARETES[o.rarete] ?? o.rarete} · ${o.type === 'avatar' ? 'Avatar' : 'Couverture'}</p>
    <p>${echapper(commentObtenir(o))}</p>
    <p class="saison">${echapper(saison?.nom ?? o.saison ?? '—')}${pasSortie ? ` · <strong>pas encore sortie (le ${echapper(sortie)})</strong>` : ''}</p>
    <p class="id">${echapper(o.id)}</p>
  </article>`;
}).join('\n');

const options = (valeurs, libelle) =>
  valeurs.map((v) => `<option value="${echapper(v)}">${echapper(libelle(v))}</option>`).join('');

const html = `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Galerie du pack Chez nous</title>
<style>
  body { font-family: system-ui, sans-serif; background: #EFE7D6; color: #16150F; margin: 0; padding: 24px; }
  h1 { margin: 0 0 4px; } .sous { color: #6B675A; margin: 0 0 16px; }
  .filtres { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 16px; }
  select { padding: 8px; border: 2px solid #16150F; background: #F6EFDE; }
  .grille { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 16px; }
  .carte { background: #F6EFDE; border: 3px solid; padding: 12px; }
  .visuel { height: 150px; display: flex; align-items: center; justify-content: center; margin-bottom: 8px; }
  .visuel img.avatar { width: 130px; height: 130px; border-radius: 50%; object-fit: cover; }
  .visuel img.couverture, .couleur.couverture { width: 100%; height: 90px; object-fit: cover; }
  .couleur.avatar { width: 130px; height: 130px; border-radius: 50%; }
  .vide { color: #A9A18D; }
  h3 { margin: 4px 0; font-size: 16px; } p { margin: 4px 0; font-size: 13px; }
  .rarete { font-weight: 700; text-transform: uppercase; font-size: 11px; letter-spacing: 1px; }
  .saison { color: #6B675A; } .id { color: #A9A18D; font-family: monospace; font-size: 11px; }
  .kit { background: #F6EFDE; border: 2px solid #D8CFB8; padding: 12px; margin-bottom: 16px; font-size: 13px; }
  .compte { font-weight: 700; }
</style>
</head>
<body>
<h1>Galerie du pack Chez nous</h1>
<p class="sous">Générée le ${aujourdhui} depuis catalogue.json — ${objets.length} objet(s). Pour la régénérer : <code>node scripts/generer-galerie.mjs</code></p>
<div class="kit"><strong>Kit gratuit (dans l'application, hors catalogue) :</strong>
  avatars — initiale, balai, savon, goutte, flamme, éclair, étoile, feuille, note, fusée, bouclier ;
  couvertures — 6 fonds unis (encre, orange, bleu, vert, violet, rouge). La boutique de lancement (pictogrammes et dégradés) est aussi dans l'application.</div>
<div class="filtres">
  <select id="f-saison"><option value="">Toutes les saisons</option>${options(Object.keys(saisons), (v) => saisons[v].nom)}</select>
  <select id="f-type"><option value="">Avatars et couvertures</option><option value="avatar">Avatars</option><option value="couverture">Couvertures</option></select>
  <select id="f-rarete"><option value="">Toutes les raretés</option>${options(Object.keys(RARETES), (v) => RARETES[v])}</select>
  <span class="compte" id="compte"></span>
</div>
<div class="grille" id="grille">
${cartes}
</div>
<script>
  const filtres = ['saison', 'type', 'rarete'].map((k) => [k, document.getElementById('f-' + k)]);
  const cartes = [...document.querySelectorAll('.carte')];
  function appliquer() {
    let visibles = 0;
    for (const c of cartes) {
      const ok = filtres.every(([k, el]) => !el.value || c.dataset[k] === el.value);
      c.style.display = ok ? '' : 'none';
      if (ok) visibles++;
    }
    document.getElementById('compte').textContent = visibles + ' affiché(s)';
  }
  filtres.forEach(([, el]) => el.addEventListener('change', appliquer));
  appliquer();
</script>
</body>
</html>
`;

writeFileSync(join(dossier, 'galerie.html'), html);
console.log(`Galerie générée : ${objets.length} objet(s) → public/catalogue/chez-nous/galerie.html`);
