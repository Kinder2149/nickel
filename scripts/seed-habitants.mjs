// NICKEL — création des 3 habitants dans Firestore.
//
// Script à usage unique, mais RÉEXÉCUTABLE sans dommage : chaque habitant a
// un identifiant fixe (val / sam / yo), donc relancer le script réécrit les
// mêmes documents au lieu d'en créer des doublons.
//
// Lancement :  node scripts/seed-habitants.mjs

const PROJET = 'nickel-menage-57692';
const CLE = 'AIzaSyBGgYQLGKDTAw65TUhHDFjySCMg9oBvEcE';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJET}/databases/(default)/documents`;

const HABITANTS = [
  { id: 'val', nom: 'Val', couleur: '#f2a65a' },
  { id: 'sam', nom: 'Sam', couleur: '#5aa9e6' },
  { id: 'yo',  nom: 'Yo',  couleur: '#c77dff' },
];

async function ecrire(habitant) {
  const url = `${BASE}/habitants/${habitant.id}?key=${CLE}`;
  const corps = {
    fields: {
      nom: { stringValue: habitant.nom },
      couleur: { stringValue: habitant.couleur },
    },
  };

  const reponse = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(corps),
  });

  if (!reponse.ok) {
    throw new Error(`${habitant.nom} : ${reponse.status} ${await reponse.text()}`);
  }
  console.log(`  OK  ${habitant.nom}`);
}

console.log('Création des habitants...');
for (const h of HABITANTS) {
  await ecrire(h);
}
console.log(`Terminé — ${HABITANTS.length} habitants dans Firestore.`);
