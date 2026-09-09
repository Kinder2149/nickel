// NICKEL — couche DONNÉES
//
// Seul fichier qui parle à Firestore. Les autres couches passent par lui
// et ne connaissent ni Firebase, ni la forme des documents.
// Voir PROJET_CONTEXTE.md § 5 (les trois couches).

import { initializeApp } from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js';
import {
  initializeFirestore,
  persistentLocalCache,
  persistentMultipleTabManager,
  collection,
  doc,
  addDoc,
  getDocs,
  updateDoc,
  onSnapshot,
  query,
  orderBy,
  limit,
} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-firestore.js';

// Configuration publique par conception : Firebase la destine au code de la
// page. La protection vient des règles d'accès (firestore.rules).
const config = {
  apiKey: 'AIzaSyBGgYQLGKDTAw65TUhHDFjySCMg9oBvEcE',
  authDomain: 'nickel-menage-57692.firebaseapp.com',
  projectId: 'nickel-menage-57692',
  storageBucket: 'nickel-menage-57692.firebasestorage.app',
  messagingSenderId: '888256690555',
  appId: '1:888256690555:web:ae6ce6f0d1688e512665de',
};

// Cache local persistant : c'est lui qui assure le fonctionnement hors
// connexion (D2 / § 5). Les écritures faites sans réseau sont conservées
// et envoyées à la reconnexion, sans code de synchronisation à écrire.
const base = initializeFirestore(initializeApp(config), {
  localCache: persistentLocalCache({
    tabManager: persistentMultipleTabManager(),
  }),
});

/** Transforme un document Firestore en Tâche. */
function versTache(document) {
  const d = document.data();
  return {
    id: document.id,
    nom: d.nom,
    frequenceJours: Number(d.frequenceJours),
    commentFaire: d.commentFaire || '',
    // Pictogramme d'inventaire : sert à reconnaître la ligne sans la lire.
    emoji: d.emoji || '·',
    responsablePrevu: d.responsablePrevu ?? null,
    prochaineEcheance: d.prochaineEcheance ?? null,
  };
}

/** Tri : de la plus fréquente à la plus rare, puis alphabétique. */
function trierTaches(taches) {
  return taches.sort(
    (a, b) =>
      a.frequenceJours - b.frequenceJours || a.nom.localeCompare(b.nom, 'fr')
  );
}

/**
 * Les habitants du foyer, triés par nom.
 * @returns {Promise<Array<{id: string, nom: string, couleur: string}>>}
 */
export async function chargerHabitants() {
  const instantane = await getDocs(collection(base, 'habitants'));

  return instantane.docs
    .map((document) => ({
      id: document.id,
      nom: document.data().nom,
      couleur: document.data().couleur,
    }))
    .sort((a, b) => a.nom.localeCompare(b.nom, 'fr'));
}

/**
 * S'abonne aux tâches EN TEMPS RÉEL.
 *
 * C'est ce qui fait qu'une tâche cochée sur le téléphone de Sam disparaît
 * de celui de Val en quelques secondes, sans rien rafraîchir.
 *
 * @param {(taches: Array<object>) => void} auChangement
 * @returns {() => void} fonction pour se désabonner
 */
export function ecouterTaches(auChangement) {
  return onSnapshot(collection(base, 'taches'), (instantane) => {
    auChangement(trierTaches(instantane.docs.map(versTache)));
  });
}

/**
 * Fixe la prochaine échéance d'une tâche.
 *
 * Les dates sont stockées en texte « AAAA-MM-JJ » : lisible dans la console
 * Firebase, comparable directement, et insensible aux fuseaux horaires —
 * ce qui compte quand trois téléphones écrivent dans la même base.
 *
 * @param {string} tacheId
 * @param {string|null} dateISO  « AAAA-MM-JJ », ou null pour « jamais faite »
 */
export async function definirProchaineEcheance(tacheId, dateISO) {
  await updateDoc(doc(base, 'taches', tacheId), {
    prochaineEcheance: dateISO,
  });
}

/**
 * Enregistre qu'une tâche vient d'être faite.
 *
 * Deux écritures indissociables :
 *   1. une Réalisation — QUI a fait la tâche, et QUAND. Jamais modifiée,
 *      jamais supprimée : c'est l'historique.
 *   2. la nouvelle échéance de la Tâche.
 *
 * `realiseParId` n'est jamais vide, même quand la tâche n'a pas de
 * responsable prévu : c'est toute la distinction du modèle métier (§ 3).
 *
 * @param {string} tacheId
 * @param {string} habitantId       celui qui utilise l'appareil
 * @param {string} dateISO          « AAAA-MM-JJ »
 * @param {string} prochaineEcheance « AAAA-MM-JJ »
 */
export async function enregistrerRealisation(
  tacheId,
  habitantId,
  dateISO,
  prochaineEcheance
) {
  await addDoc(collection(base, 'realisations'), {
    tacheId,
    realiseParId: habitantId,
    dateRealisation: dateISO,
    // Horodatage complet : deux réalisations du même jour doivent pouvoir
    // être classées entre elles dans l'historique.
    enregistreLe: new Date().toISOString(),
  });

  await updateDoc(doc(base, 'taches', tacheId), { prochaineEcheance });
}

/**
 * S'abonne à l'historique EN TEMPS RÉEL : les réalisations les plus
 * récentes en premier.
 *
 * En temps réel comme les tâches, pour qu'une tâche cochée par un habitant
 * apparaisse dans l'historique des deux autres sans rien rafraîchir.
 *
 * @param {(realisations: Array<object>) => void} auChangement
 * @param {number} nombre
 * @returns {() => void} fonction pour se désabonner
 */
export function ecouterRealisations(auChangement, nombre = 100) {
  const demande = query(
    collection(base, 'realisations'),
    orderBy('enregistreLe', 'desc'),
    limit(nombre)
  );

  return onSnapshot(demande, (instantane) => {
    auChangement(
      instantane.docs.map((document) => {
        const d = document.data();
        return {
          id: document.id,
          tacheId: d.tacheId,
          realiseParId: d.realiseParId,
          dateRealisation: d.dateRealisation,
          enregistreLe: d.enregistreLe,
        };
      })
    );
  });
}
