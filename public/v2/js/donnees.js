// NICKEL V2 — couche DONNÉES
//
// Espace séparé de la V1 : nouvelle collection Firestore `maisons`,
// jamais de contact avec `habitants` / `taches` / `realisations`.

import { initializeApp } from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js';
import {
  initializeFirestore,
  persistentLocalCache,
  persistentMultipleTabManager,
  collection,
  doc,
  getDoc,
  setDoc,
  query,
  where,
  getDocs,
  onSnapshot,
  deleteDoc,
  addDoc,
  updateDoc,
  orderBy,
  limit,
} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-firestore.js';
import {
  getAuth,
  signInAnonymously,
  onAuthStateChanged,
} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-auth.js';

const config = {
  apiKey: 'AIzaSyBGgYQLGKDTAw65TUhHDFjySCMg9oBvEcE',
  authDomain: 'nickel-menage-57692.firebaseapp.com',
  projectId: 'nickel-menage-57692',
  storageBucket: 'nickel-menage-57692.firebasestorage.app',
  messagingSenderId: '888256690555',
  appId: '1:888256690555:web:ae6ce6f0d1688e512665de',
};

const appFirebase = initializeApp(config, 'nickel-v2');

const base = initializeFirestore(appFirebase, {
  localCache: persistentLocalCache({
    tabManager: persistentMultipleTabManager(),
  }),
});

const auth = getAuth(appFirebase);

/**
 * Authentification anonyme Firebase : invisible pour l'utilisateur (pas
 * d'email, pas d'écran de connexion — cohérent avec V2-D2), mais donne à
 * chaque appareil un identifiant vérifiable côté serveur. C'est ce qui
 * permet de fermer les règles Firestore (au lieu de la dette ouverte
 * héritée de la V1) : seul un membre authentifié d'une maison peut lire ou
 * écrire ses données. Persiste automatiquement sur l'appareil, comme le
 * profil local (V2-D2).
 * @returns {Promise<string>} l'identifiant de l'appareil
 */
export function assurerAuthentification() {
  return new Promise((resolve, reject) => {
    const arreter = onAuthStateChanged(
      auth,
      (utilisateur) => {
        if (utilisateur) {
          arreter();
          resolve(utilisateur.uid);
        }
      },
      reject
    );
    if (!auth.currentUser) {
      signInAnonymously(auth).catch(reject);
    }
  });
}

const CARACTERES_CODE = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans 0/O/1/I, ambigus à recopier

function genererCode() {
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += CARACTERES_CODE[Math.floor(Math.random() * CARACTERES_CODE.length)];
  }
  return code;
}

/**
 * Crée une maison, avec un code d'invitation unique, et y ajoute le profil
 * créateur comme premier membre.
 * @returns {Promise<{id: string, codeInvitation: string}>}
 */
export async function creerMaison(nom, profil) {
  const maisonId = crypto.randomUUID();
  const codeInvitation = genererCode();

  await setDoc(doc(base, 'maisons', maisonId), {
    nom,
    codeInvitation,
    creeLe: new Date().toISOString(),
  });

  await setDoc(doc(base, 'maisons', maisonId, 'membres', profil.id), {
    prenom: profil.prenom,
    couleur: profil.couleur,
    rejointLe: new Date().toISOString(),
  });

  return { id: maisonId, codeInvitation };
}

/**
 * Cherche une maison par son code d'invitation et y ajoute le profil.
 * @returns {Promise<{id: string, nom: string, codeInvitation: string} | null>} null si le code n'existe pas
 */
export async function rejoindreMaison(code, profil) {
  const demande = query(
    collection(base, 'maisons'),
    where('codeInvitation', '==', code.toUpperCase().trim())
  );
  const instantane = await getDocs(demande);

  if (instantane.empty) return null;

  const document = instantane.docs[0];
  await setDoc(doc(base, 'maisons', document.id, 'membres', profil.id), {
    prenom: profil.prenom,
    couleur: profil.couleur,
    rejointLe: new Date().toISOString(),
  });

  return { id: document.id, ...document.data() };
}

/** @returns {Promise<{id: string, nom: string, codeInvitation: string} | null>} */
export async function chargerMaison(maisonId) {
  const snap = await getDoc(doc(base, 'maisons', maisonId));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}

/**
 * S'abonne aux membres d'une maison EN TEMPS RÉEL.
 * @param {(membres: Array<object>) => void} auChangement
 * @returns {() => void}
 */
export function ecouterMembres(maisonId, auChangement) {
  return onSnapshot(
    collection(base, 'maisons', maisonId, 'membres'),
    (instantane) => {
      auChangement(
        instantane.docs
          .map((d) => ({ id: d.id, ...d.data() }))
          .sort((a, b) => a.rejointLe.localeCompare(b.rejointLe))
      );
    }
  );
}

/** Retire un profil des membres d'une maison (V2-D6, quitter une maison). */
export async function quitterMaison(maisonId, profilId) {
  await deleteDoc(doc(base, 'maisons', maisonId, 'membres', profilId));
}

/**
 * Retire un AUTRE membre d'une maison (V2-D5 : droits identiques, pas de
 * rôle propriétaire — n'importe quel membre peut retirer n'importe quel
 * autre). Même écriture que quitterMaison, exposée séparément pour que
 * l'appelant ne puisse pas se tromper de profil par accident.
 */
export async function retirerMembre(maisonId, membreId) {
  await deleteDoc(doc(base, 'maisons', maisonId, 'membres', membreId));
}

// ------------------------------------------------- pièces et tâches (V2-2)

/** Crée une Pièce dans une maison. @returns {Promise<string>} son id */
export async function creerPiece(maisonId, nom) {
  const ref = await addDoc(collection(base, 'maisons', maisonId, 'pieces'), {
    nom,
    creeLe: new Date().toISOString(),
  });
  return ref.id;
}

/**
 * S'abonne aux Pièces d'une maison EN TEMPS RÉEL, triées par nom.
 * @param {(pieces: Array<object>) => void} auChangement
 * @returns {() => void}
 */
export function ecouterPieces(maisonId, auChangement) {
  return onSnapshot(
    collection(base, 'maisons', maisonId, 'pieces'),
    (instantane) => {
      auChangement(
        instantane.docs
          .map((d) => ({ id: d.id, ...d.data() }))
          .sort((a, b) => a.nom.localeCompare(b.nom, 'fr'))
      );
    }
  );
}

/** Renomme une Pièce. */
export async function modifierPiece(maisonId, pieceId, nom) {
  await updateDoc(doc(base, 'maisons', maisonId, 'pieces', pieceId), { nom });
}

/**
 * Supprime une Pièce. Refuse si elle contient encore des Tâches (V2-D12 :
 * une Tâche appartient obligatoirement à une Pièce — pas de suppression en
 * cascade silencieuse, il faut d'abord vider la pièce).
 */
export async function supprimerPiece(maisonId, pieceId) {
  const tachesSnap = await getDocs(
    query(collection(base, 'maisons', maisonId, 'taches'), where('pieceId', '==', pieceId))
  );
  if (!tachesSnap.empty) {
    throw new Error('Cette pièce contient encore des tâches. Supprimez-les d’abord.');
  }
  await deleteDoc(doc(base, 'maisons', maisonId, 'pieces', pieceId));
}

/**
 * Crée une Tâche rattachée à une Pièce (V2-D12 : jamais sans pièce).
 * Produit et astuce sont deux champs distincts (V2-D13, V2-D14).
 */
export async function creerTache(maisonId, { nom, pieceId, frequenceJours, produit, astuce, emoji }) {
  await addDoc(collection(base, 'maisons', maisonId, 'taches'), {
    nom,
    pieceId,
    frequenceJours: Number(frequenceJours),
    produit: produit || '',
    astuce: astuce || '',
    emoji: emoji || '🧹',
    responsablePrevu: null,
    prochaineEcheance: null,
  });
}

/**
 * S'abonne aux Tâches d'une maison EN TEMPS RÉEL.
 * @param {(taches: Array<object>) => void} auChangement
 * @returns {() => void}
 */
export function ecouterTaches(maisonId, auChangement) {
  return onSnapshot(
    collection(base, 'maisons', maisonId, 'taches'),
    (instantane) => {
      auChangement(instantane.docs.map((d) => ({ id: d.id, ...d.data() })));
    }
  );
}

/**
 * Modifie une Tâche (nom, fréquence, produit, astuce). Ne touche jamais à
 * `pieceId` : déplacer une tâche d'une pièce à l'autre est hors périmètre
 * du peaufinage (V2-D12 reste géré à la création).
 */
export async function modifierTache(maisonId, tacheId, { nom, frequenceJours, produit, astuce, emoji }) {
  await updateDoc(doc(base, 'maisons', maisonId, 'taches', tacheId), {
    nom,
    frequenceJours: Number(frequenceJours),
    produit: produit || '',
    astuce: astuce || '',
    emoji: emoji || '🧹',
  });
}

/**
 * Supprime une Tâche. L'historique (Réalisations) n'est jamais touché — il
 * reste lisible grâce au repli "Tâche supprimée" déjà géré par l'écran
 * Historique quand `tacheId` ne correspond plus à aucune tâche.
 */
export async function supprimerTache(maisonId, tacheId) {
  await deleteDoc(doc(base, 'maisons', maisonId, 'taches', tacheId));
}

// ----------------------------------------------------- réalisations (V2-3)

/**
 * Enregistre qu'une tâche vient d'être faite (V1 § 3, règle héritée).
 * Deux écritures indissociables : la Réalisation (jamais modifiée, jamais
 * supprimée — c'est l'historique) et la nouvelle échéance de la Tâche.
 * `realiseParId` n'est jamais vide, même quand la tâche n'a pas de
 * responsable prévu.
 */
export async function enregistrerRealisation(maisonId, tacheId, profilId, dateISO, prochaineEcheance) {
  await addDoc(collection(base, 'maisons', maisonId, 'realisations'), {
    tacheId,
    realiseParId: profilId,
    dateRealisation: dateISO,
    enregistreLe: new Date().toISOString(),
  });

  await updateDoc(doc(base, 'maisons', maisonId, 'taches', tacheId), {
    prochaineEcheance,
  });
}

/**
 * S'abonne à l'historique d'une maison EN TEMPS RÉEL, le plus récent en
 * premier — comme en V1 (§ 5, étape 7).
 * @param {(realisations: Array<object>) => void} auChangement
 * @returns {() => void}
 */
export function ecouterRealisations(maisonId, auChangement, nombre = 100) {
  const demande = query(
    collection(base, 'maisons', maisonId, 'realisations'),
    orderBy('enregistreLe', 'desc'),
    limit(nombre)
  );

  return onSnapshot(demande, (instantane) => {
    auChangement(instantane.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
}

// -------------------------------------------------- export / import (V2-5)

/**
 * Exporte la structure d'une maison (V2-D8) : pièces + tâches, sans
 * historique ni membres. Lecture ponctuelle, pas un abonnement.
 */
export async function exporterStructure(maisonId) {
  const [piecesSnap, tachesSnap] = await Promise.all([
    getDocs(collection(base, 'maisons', maisonId, 'pieces')),
    getDocs(collection(base, 'maisons', maisonId, 'taches')),
  ]);

  const pieces = piecesSnap.docs.map((d) => ({ id: d.id, nom: d.data().nom }));
  const taches = tachesSnap.docs.map((d) => d.data());

  return {
    version: 1,
    pieces: pieces.map((piece) => ({
      nom: piece.nom,
      taches: taches
        .filter((t) => t.pieceId === piece.id)
        .map((t) => ({
          nom: t.nom,
          frequenceJours: t.frequenceJours,
          produit: t.produit || '',
          astuce: t.astuce || '',
          emoji: t.emoji || '🧹',
        })),
    })),
  };
}

/**
 * Importe une structure : crée toujours une NOUVELLE maison (V2-D9, jamais
 * de fusion). Le profil qui importe devient le premier membre.
 * @returns {Promise<{id: string, codeInvitation: string}>}
 */
export async function importerStructure(nomMaison, structure, profil) {
  const maison = await creerMaison(nomMaison, profil);

  for (const piece of structure.pieces || []) {
    const pieceId = await creerPiece(maison.id, piece.nom);
    for (const tache of piece.taches || []) {
      await creerTache(maison.id, { ...tache, pieceId });
    }
  }

  return maison;
}
