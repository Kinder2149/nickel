// NICKEL — chargement des 35 tâches réelles dans Firestore.
//
// Source : PROJET_CONTEXTE.md § 6 (données réelles du pilote).
//
// RÉEXÉCUTABLE sans dommage : chaque tâche a un identifiant fixe, donc
// relancer le script réécrit les mêmes documents au lieu d'en créer d'autres.
//
// ATTENTION : relancer ce script REMET À ZÉRO la prochaine échéance des
// tâches (elles repassent en « jamais faite »). Les réalisations déjà
// enregistrées, elles, ne sont pas touchées.
//
// Lancement :  node scripts/seed-taches.mjs

const PROJET = 'nickel-menage-57692';
const CLE = 'AIzaSyBGgYQLGKDTAw65TUhHDFjySCMg9oBvEcE';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJET}/databases/(default)/documents`;

// [ id, nom, fréquence en jours, comment faire ]
const TACHES = [
  // --- Sols et surfaces communes
  ['sol-salon', 'Laver le sol du salon (parquet)', 7, 'Savon noir dilué 1-2 c.à.s./L d\'eau chaude, lavette bien essorée.'],
  ['sols-carreles', 'Laver les sols carrelés', 7, 'Cuisine, entrée, WC, salle de bain. Savon noir, même dilution.'],
  ['meubles-bois-salon', 'Dépoussiérer les meubles bois du salon', 7, 'Microfibre sèche, dans le sens du bois.'],
  ['bureau-verre', 'Nettoyer le bureau en verre', 14, 'Produit à vitre, vaporiser puis microfibre.'],
  ['baie-vitree', 'Nettoyer la baie vitrée', 30, 'Produit à vitre, raclette si possible.'],
  ['meuble-entree', 'Essuyer le meuble d\'entrée et la porte du placard', 14, 'Microfibre.'],
  ['traitement-parquet', 'Traiter le parquet', 365, 'Produit protecteur parquet : huile ou cire, après lavage.'],

  // --- Canapés et textiles
  ['aspirer-canape-tissu', 'Aspirer le canapé tissu', 7, 'Aspirateur : coussins et interstices.'],
  ['canape-tissu-fond', 'Nettoyer le canapé tissu en profondeur', 180, 'Bicarbonate 2 h puis aspirer. Ensuite savon noir dilué, tamponné.'],
  ['depoussierer-canape-cuir', 'Dépoussiérer le canapé cuir', 7, 'Microfibre sèche, geste doux.'],
  ['nourrir-canape-cuir', 'Nettoyer et nourrir le canapé cuir', 90, 'Savon de Marseille dilué, tamponner en petits cercles.'],
  ['nappe', 'Laver la nappe', 14, 'Pastille de lessive, machine normale.'],
  ['torchons', 'Laver les torchons', 3, 'Pastille de lessive, 60 °C.'],
  ['lavettes', 'Laver la lavette et les microfibres', 3, 'Pastille de lessive, sans adoucissant (il bouche les fibres).'],

  // --- Cuisine
  ['plan-travail', 'Nettoyer le plan de travail et l\'évier', 1, 'Liquide vaisselle, rinçage puis séchage.'],
  ['plaque-cuisson', 'Nettoyer la plaque de cuisson', 1, 'Savon noir pur, 30 min de pose, puis frotter.'],
  ['four', 'Nettoyer l\'intérieur du four', 30, 'Savon noir la nuit sur four tiède, puis frotter au bicarbonate.'],
  ['micro-ondes', 'Nettoyer l\'intérieur du micro-ondes', 7, 'Bol d\'eau chaude 2 min avant, puis liquide vaisselle.'],
  ['frigo-exterieur', 'Essuyer l\'extérieur du frigo', 7, 'Microfibre et liquide vaisselle.'],
  ['frigo-interieur', 'Nettoyer l\'intérieur du frigo', 30, 'Savon de Marseille. Vider, puis bien sécher avant de ranger.'],
  ['frigo-joint', 'Nettoyer le joint du frigo', 30, 'Savon de Marseille, chiffon imbibé. Moisissure invisible dans les plis.'],
  ['meubles-cuisine', 'Essuyer les meubles de cuisine', 7, 'Dégraissant et microfibre. Insister sur les poignées.'],
  ['purger-canalisations', 'Purger les canalisations de l\'évier', 7, 'Verser une bouilloire d\'eau bouillante. Prévient les bouchons.'],
  ['bouilloire', 'Détartrer la bouilloire', 30, 'Anti-calcaire ou vinaigre blanc : faire bouillir, puis rincer 2 à 3 fois.'],
  ['poubelle-tri', 'Vider la poubelle de tri', 3, ''],
  ['poubelle-verre', 'Vider la poubelle de verre', 14, ''],

  // --- Salle de bain et WC
  ['parois-douche', 'Nettoyer les parois de douche', 7, 'Savon noir sur le PVC, puis rinçage à l\'eau claire.'],
  ['joints-douche', 'Détartrer les joints de la douche', 30, 'Anti-calcaire, brosse à dents dédiée.'],
  ['evier-sdb', 'Nettoyer l\'évier et la robinetterie de la salle de bain', 7, 'Anti-calcaire, 15 min de pose.'],
  ['miroir-sdb', 'Nettoyer le miroir de la salle de bain', 7, 'Produit à vitre.'],
  ['wc', 'Nettoyer la cuvette et l\'abattant des WC', 4, 'Javel. Éponge dédiée pour l\'abattant.'],
  ['vmc', 'Entretenir la VMC', 180, 'Salle de bain et WC. Dépoussiérer la grille à l\'aspirateur.'],

  // --- Électroménager et intendance
  ['lave-linge-tambour', 'Nettoyer le tambour du lave-linge à vide', 30, '1 L de vinaigre blanc, cycle à 90 °C.'],
  ['lave-linge-joint', 'Nettoyer le joint du hublot du lave-linge', 30, 'Eau chaude et vinaigre blanc, insister dans les plis.'],
  ['stock', 'Vérifier les stocks', 7, 'Papier toilette, liquide vaisselle, savon pour les mains.'],
];

function versDocument([, nom, frequence, comment]) {
  return {
    fields: {
      nom: { stringValue: nom },
      frequenceJours: { integerValue: String(frequence) },
      commentFaire: { stringValue: comment },
      // D11 : l'attribut existe, mais toutes les tâches réelles sont
      // des tâches du foyer. Vide = n'importe qui peut la faire.
      responsablePrevu: { nullValue: null },
      // D10 : renseignée à l'étape 4. Null = jamais faite.
      prochaineEcheance: { nullValue: null },
    },
  };
}

async function ecrire(tache) {
  const url = `${BASE}/taches/${tache[0]}?key=${CLE}`;
  const reponse = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(versDocument(tache)),
  });

  if (!reponse.ok) {
    throw new Error(`${tache[1]} : ${reponse.status} ${await reponse.text()}`);
  }
}

// Garde-fou : les identifiants doivent être uniques, sinon une tâche en
// écraserait silencieusement une autre et il en manquerait à l'écran.
const ids = new Set(TACHES.map((t) => t[0]));
if (ids.size !== TACHES.length) {
  throw new Error('Identifiants de tâches en double — corriger le script.');
}

console.log(`Chargement de ${TACHES.length} tâches...`);
for (const tache of TACHES) {
  await ecrire(tache);
  console.log(`  OK  ${tache[1]}`);
}
console.log(`Terminé — ${TACHES.length} tâches dans Firestore.`);
