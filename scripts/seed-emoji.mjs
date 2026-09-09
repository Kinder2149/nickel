// NICKEL — attribution d'un emoji à chaque tâche.
//
// SÛR À RELANCER : ce script n'écrit QUE le champ `emoji`, grâce au
// paramètre updateMask de Firestore. Les échéances saisies par Kinder
// (prochaineEcheance) ne sont jamais touchées — contrairement à
// seed-taches.mjs, qui lui réécrit tout le document.
//
// Lancement :  node scripts/seed-emoji.mjs

const PROJET = 'nickel-menage-57692';
const CLE = 'AIzaSyBGgYQLGKDTAw65TUhHDFjySCMg9oBvEcE';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJET}/databases/(default)/documents`;

// Règles retenues :
//  - un emoji distinct par tâche, pour reconnaître une ligne sans la lire ;
//  - l'emoji désigne l'OBJET, pas le geste (sinon quinze éponges) ;
//  - seule répétition assumée : 🦠 pour les deux joints (frigo et hublot),
//    même problème, même produit, même travail.
const EMOJI = {
  // Sols et surfaces
  'sol-salon': '🪵',
  'sols-carreles': '🧹',
  'meubles-bois-salon': '🪑',
  'bureau-verre': '💻',
  'baie-vitree': '🪟',
  'meuble-entree': '🚪',
  'traitement-parquet': '🛢️',

  // Canapés et textiles
  'aspirer-canape-tissu': '🛋️',
  'canape-tissu-fond': '🫧',
  'depoussierer-canape-cuir': '💺',
  'nourrir-canape-cuir': '🧴',
  'nappe': '🍽️',
  'torchons': '🧺',
  'lavettes': '🧼',

  // Cuisine
  'plan-travail': '🧽',
  'plaque-cuisson': '🍳',
  'four': '🔥',
  'micro-ondes': '🍲',
  'frigo-exterieur': '🧊',
  'frigo-interieur': '🥬',
  'frigo-joint': '🦠',
  'meubles-cuisine': '🗄️',
  'purger-canalisations': '💧',
  'bouilloire': '☕',
  'poubelle-tri': '♻️',
  'poubelle-verre': '🍾',

  // Salle de bain et WC
  'parois-douche': '🚿',
  'joints-douche': '🪥',
  'evier-sdb': '🚰',
  'miroir-sdb': '🪞',
  'wc': '🚽',
  'vmc': '💨',

  // Électroménager et intendance
  'lave-linge-tambour': '🌀',
  'lave-linge-joint': '🦠',
  'stock': '🧻',
};

const entrees = Object.entries(EMOJI);

// Garde-fou : le nombre doit correspondre aux 35 tâches réelles.
if (entrees.length !== 35) {
  throw new Error(`${entrees.length} emoji définis, 35 attendus.`);
}

console.log(`Attribution de ${entrees.length} emoji...`);

for (const [id, emoji] of entrees) {
  // updateMask : SEUL le champ emoji est écrit.
  const url = `${BASE}/taches/${id}?updateMask.fieldPaths=emoji&key=${CLE}`;

  const reponse = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: { emoji: { stringValue: emoji } } }),
  });

  if (!reponse.ok) {
    throw new Error(`${id} : ${reponse.status} ${await reponse.text()}`);
  }
  console.log(`  ${emoji}  ${id}`);
}

console.log('Terminé — les échéances n\'ont pas été touchées.');
