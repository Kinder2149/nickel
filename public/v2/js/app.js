// NICKEL V2 — étape V2-1 : profil, créer une maison, rejoindre par code.
// Voir PROJET_CONTEXTE.md § 13-14.

import {
  creerMaison,
  rejoindreMaison,
  chargerMaison,
  ecouterMembres,
  quitterMaison,
  retirerMembre,
  creerPiece,
  ecouterPieces,
  modifierPiece,
  supprimerPiece,
  creerTache,
  ecouterTaches,
  modifierTache,
  supprimerTache,
  enregistrerRealisation,
  ecouterRealisations,
  exporterStructure,
  importerStructure,
  assurerAuthentification,
} from './donnees.js';

const ecran = document.getElementById('ecran');

const COULEURS = ['#f2a65a', '#5aa9e6', '#c77dff', '#2E6B4E', '#B4321F', '#6B675A'];

// Liste restreinte, pas un clavier emoji libre (§ 11 refonte visuelle,
// peaufinage V2 point 7) : l'utilisateur choisit à la création de la
// tâche, plutôt qu'une attribution automatique impossible à deviner pour
// une tâche inventée par lui (contrairement aux 35 tâches figées de la V1,
// voir scripts/seed-emoji.mjs).
const EMOJI_TACHES = [
  '🧹', '🧽', '🧴', '🪣', '🧺', '🚿', '🚽', '🪟',
  '🪑', '🛋️', '🛏️', '🍽️', '🧊', '🔥', '🍳', '💧',
  '🗑️', '♻️', '🧼', '🪥', '🚪', '💻', '🌿', '🐾',
  '📦', '🚰', '🪞', '🧯', '🔌', '🛁',
];
const EMOJI_PAR_DEFAUT = EMOJI_TACHES[0];

const CLE_PROFIL = 'nickel-v2-profil';
const CLE_MAISON = 'nickel-v2-maison';

function chargerProfil() {
  const brut = localStorage.getItem(CLE_PROFIL);
  return brut ? JSON.parse(brut) : null;
}

function enregistrerProfil(profil) {
  localStorage.setItem(CLE_PROFIL, JSON.stringify(profil));
}

function chargerMaisonId() {
  return localStorage.getItem(CLE_MAISON);
}

function enregistrerMaisonId(id) {
  localStorage.setItem(CLE_MAISON, id);
}

function effacerMaisonId() {
  localStorage.removeItem(CLE_MAISON);
}

function initiale(prenom) {
  return prenom.trim().slice(0, 1).toUpperCase();
}

/** Aujourd'hui en « AAAA-MM-JJ », dans le fuseau du téléphone (comme en V1, § 5). */
function dateAujourdhui() {
  const d = new Date();
  const mois = String(d.getMonth() + 1).padStart(2, '0');
  const jour = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${mois}-${jour}`;
}

/**
 * « AAAA-MM-JJ » + n jours → « AAAA-MM-JJ », en heure locale : évite le
 * décalage d'un jour que provoquerait toISOString(), interprété en UTC
 * (piège déjà documenté et évité en V1, § 5).
 */
function ajouterJours(dateISO, jours) {
  const [a, m, j] = dateISO.split('-').map(Number);
  const d = new Date(a, m - 1, j + Number(jours));
  const mois = String(d.getMonth() + 1).padStart(2, '0');
  const jour = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${mois}-${jour}`;
}

function grilleEmoji(valeurChoisie) {
  return `
    <div class="champ">
      <label>Pictogramme</label>
      <div class="selecteur-emoji" data-valeur="${valeurChoisie}">
        ${EMOJI_TACHES.map(
          (e) => `<button type="button" class="emoji-option${e === valeurChoisie ? ' emoji-option--choisie' : ''}" data-emoji="${e}">${e}</button>`
        ).join('')}
      </div>
    </div>
  `;
}

function initSelecteurEmoji(racine) {
  const selecteur = racine.querySelector('.selecteur-emoji');
  selecteur.querySelectorAll('.emoji-option').forEach((bouton) => {
    bouton.addEventListener('click', () => {
      selecteur.dataset.valeur = bouton.dataset.emoji;
      selecteur.querySelectorAll('.emoji-option').forEach((b) => {
        b.classList.toggle('emoji-option--choisie', b === bouton);
      });
    });
  });
}

function valeurEmoji(racine) {
  return racine.querySelector('.selecteur-emoji').dataset.valeur;
}

function statutTache(tache) {
  if (!tache.prochaineEcheance) return 'jamais';
  const aujourdhui = dateAujourdhui();
  if (tache.prochaineEcheance < aujourdhui) return 'retard';
  if (tache.prochaineEcheance === aujourdhui) return 'aujourdhui';
  return 'avenir';
}

// ------------------------------------------------------- écran profil

function afficherEcranProfil(uid) {
  let couleurChoisie = COULEURS[0];

  ecran.innerHTML = `
    <div class="page">
      <p class="tag">Nickel · V2</p>
      <h1 class="titre anton">Qui<br>êtes-vous ?</h1>
      <div class="champ">
        <label for="prenom">Votre prénom</label>
        <input id="prenom" type="text" autocomplete="given-name" placeholder="Camille">
      </div>
      <div class="champ">
        <label>Votre couleur</label>
        <div class="couleurs" id="couleurs"></div>
      </div>
      <button class="bouton" id="valider">Continuer</button>
    </div>
  `;

  const conteneurCouleurs = document.getElementById('couleurs');
  COULEURS.forEach((couleur, index) => {
    const bouton = document.createElement('button');
    bouton.className = 'couleur' + (index === 0 ? ' couleur--choisie' : '');
    bouton.style.background = couleur;
    bouton.addEventListener('click', () => {
      couleurChoisie = couleur;
      conteneurCouleurs
        .querySelectorAll('.couleur')
        .forEach((el) => el.classList.remove('couleur--choisie'));
      bouton.classList.add('couleur--choisie');
    });
    conteneurCouleurs.appendChild(bouton);
  });

  document.getElementById('valider').addEventListener('click', () => {
    const prenom = document.getElementById('prenom').value.trim();
    if (!prenom) {
      document.getElementById('prenom').focus();
      return;
    }
    const profil = { id: uid, prenom, couleur: couleurChoisie };
    enregistrerProfil(profil);
    naviguer('maison', { profil }, { remplacer: true });
  });
}

// -------------------------------------------------- écran créer/rejoindre

function afficherEcranMaison(profil) {
  ecran.innerHTML = `
    <div class="page">
      <p class="tag">Bonjour ${profil.prenom}</p>
      <h1 class="titre anton">Votre<br>maison</h1>
      <div id="erreur"></div>

      <div class="champ">
        <label for="nomMaison">Créer une maison</label>
        <input id="nomMaison" type="text" placeholder="Chez nous">
      </div>
      <button class="bouton" id="creer">Créer la maison vide</button>
      <button class="bouton bouton--secondaire" id="creerModeleGenerique">Commencer avec le modèle générique</button>
      <p class="tag" style="margin-top:0.5rem; text-transform:none; letter-spacing:normal; font-weight:400">Pièces et tâches courantes déjà remplies — à ajuster ensuite.</p>
      <button class="bouton bouton--secondaire" id="creerModeleFoyerPilote" style="margin-top:0.75rem">Commencer avec le modèle du foyer pilote</button>
      <p class="tag" style="margin-top:0.5rem; text-transform:none; letter-spacing:normal; font-weight:400">Les 35 tâches réelles de "Chez nous", réparties sur 7 pièces — pratique pour tester.</p>

      <div class="separation">ou</div>

      <div class="champ">
        <label for="codeMaison">Rejoindre avec un code</label>
        <input id="codeMaison" type="text" placeholder="AB12CD" style="text-transform:uppercase; letter-spacing:0.15em;">
      </div>
      <button class="bouton bouton--secondaire" id="rejoindre">Rejoindre</button>

      <div class="separation">ou</div>

      <div class="champ">
        <label for="nomImport">Importer un modèle — nom de la maison</label>
        <input id="nomImport" type="text" placeholder="Chez nous">
      </div>
      <div class="champ">
        <label for="fichierImport">Fichier modèle (.json)</label>
        <input id="fichierImport" type="file" accept="application/json">
      </div>
      <button class="bouton bouton--secondaire" id="importer">Importer</button>
    </div>
  `;

  function afficherErreur(message) {
    document.getElementById('erreur').innerHTML = message
      ? `<div class="erreur">${message}</div>`
      : '';
  }

  document.getElementById('creer').addEventListener('click', async () => {
    const nom = document.getElementById('nomMaison').value.trim();
    if (!nom) return afficherErreur('Donnez un nom à votre maison.');

    const bouton = document.getElementById('creer');
    bouton.textContent = 'Création…';
    bouton.disabled = true;

    const { id } = await creerMaison(nom, profil);
    enregistrerMaisonId(id);
    naviguer('accueil', { profil, maisonId: id }, { remplacer: true });
  });

  document.getElementById('rejoindre').addEventListener('click', async () => {
    const code = document.getElementById('codeMaison').value.trim();
    if (!code) return afficherErreur('Entrez un code d’invitation.');

    const bouton = document.getElementById('rejoindre');
    bouton.textContent = 'Recherche…';
    bouton.disabled = true;

    const maison = await rejoindreMaison(code, profil);

    if (!maison) {
      afficherErreur('Aucune maison ne correspond à ce code.');
      bouton.textContent = 'Rejoindre';
      bouton.disabled = false;
      return;
    }

    enregistrerMaisonId(maison.id);
    naviguer('accueil', { profil, maisonId: maison.id }, { remplacer: true });
  });

  async function creerDepuisModele(idBouton, fichierModele, nomParDefaut) {
    const nom = document.getElementById('nomMaison').value.trim() || nomParDefaut;

    const bouton = document.getElementById(idBouton);
    bouton.textContent = 'Création…';
    bouton.disabled = true;

    const reponse = await fetch(`/v2/modeles/${fichierModele}`);
    const structure = await reponse.json();
    const maison = await importerStructure(nom, structure, profil);
    enregistrerMaisonId(maison.id);
    naviguer('accueil', { profil, maisonId: maison.id }, { remplacer: true });
  }

  document.getElementById('creerModeleGenerique').addEventListener('click', () => {
    creerDepuisModele('creerModeleGenerique', 'generique.json', 'Chez nous');
  });

  document.getElementById('creerModeleFoyerPilote').addEventListener('click', () => {
    creerDepuisModele('creerModeleFoyerPilote', 'foyer-pilote.json', 'Chez nous (test)');
  });

  document.getElementById('importer').addEventListener('click', async () => {
    const nom = document.getElementById('nomImport').value.trim();
    const fichier = document.getElementById('fichierImport').files[0];

    if (!nom) return afficherErreur('Donnez un nom à la maison importée.');
    if (!fichier) return afficherErreur('Choisissez un fichier modèle.');

    const bouton = document.getElementById('importer');
    bouton.textContent = 'Import…';
    bouton.disabled = true;

    try {
      const texte = await fichier.text();
      const structure = JSON.parse(texte);
      const maison = await importerStructure(nom, structure, profil);
      enregistrerMaisonId(maison.id);
      naviguer('accueil', { profil, maisonId: maison.id }, { remplacer: true });
    } catch (e) {
      afficherErreur('Fichier invalide : ' + e.message);
      bouton.textContent = 'Importer';
      bouton.disabled = false;
    }
  });
}

// --------------------------------------------------------- écran maison

async function afficherEcranAccueil(profil, maisonId) {
  const maison = await chargerMaison(maisonId);

  if (!maison) {
    // Code d'invitation périmé ou maison supprimée : on repart de zéro.
    effacerMaisonId();
    naviguer('maison', { profil }, { remplacer: true });
    return;
  }

  ecran.innerHTML = `
    <div class="page">
      <p class="tag">Bonjour ${profil.prenom}</p>
      <div class="carte-maison">
        <h2 class="anton">${maison.nom}</h2>
        <p class="code-label">Code d'invitation</p>
        <p class="code">${maison.codeInvitation}</p>
      </div>
      <button class="lien-texte" id="parametres" style="align-self:flex-end; margin-top:0">⚙ Paramètres</button>

      <div id="tableauDeBord" style="margin-top:1rem"></div>
    </div>
  `;

  document.getElementById('parametres').addEventListener('click', () => {
    naviguer('parametres', { profil, maisonId, maison });
  });

  // Tableau de bord : ce qu'il y a à faire MAINTENANT, visible sans clic
  // supplémentaire (audit du 2026-09-09 — l'accueil ne montrait avant que
  // le nom de la maison et les membres, jamais l'état des tâches). Les
  // tâches "jamais renseignées" comptent comme urgentes au même titre que
  // "en retard"/"aujourd'hui" : sans date de début, elles sont dues depuis
  // le jour zéro (retour de Kinder le 2026-09-10) — avant, seules
  // "retard"/"aujourd'hui" étaient comptées, ce qui faisait croire "rien à
  // faire" alors qu'aucune tâche du modèle importé n'avait jamais été faite.
  const conteneurTableau = document.getElementById('tableauDeBord');
  const arreterEcouteTaches = ecouterTaches(maisonId, (taches) => {
    const enRetard = taches.filter((t) => statutTache(t) === 'retard');
    const jamaisFaites = taches.filter((t) => statutTache(t) === 'jamais');
    const duJour = taches.filter((t) => statutTache(t) === 'aujourdhui');
    const urgentes = [...enRetard, ...jamaisFaites, ...duJour];

    if (urgentes.length === 0) {
      conteneurTableau.innerHTML = `
        <p class="tag" style="margin:0 0 1.25rem; text-transform:none; letter-spacing:normal; font-weight:400">Rien à faire pour l'instant. 🎉</p>
      `;
      return;
    }

    const libelleCompte = [
      enRetard.length ? `${enRetard.length} en retard` : '',
      jamaisFaites.length ? `${jamaisFaites.length} jamais faites` : '',
      duJour.length ? `${duJour.length} aujourd'hui` : '',
    ].filter(Boolean).join(' · ');

    conteneurTableau.innerHTML = `
      <p class="bandeau-section${enRetard.length ? ' bandeau-section--retard' : ''}">${libelleCompte}</p>
      <ul class="membres" style="margin:0 0 1.25rem" id="listeUrgentes"></ul>
    `;

    document.getElementById('listeUrgentes').innerHTML = urgentes
      .map(
        (t) => `
        <li class="membre" data-tache-id="${t.id}" style="cursor:pointer">
          <span class="emoji-case emoji-case--du">${t.emoji || EMOJI_PAR_DEFAUT}</span>
          <span class="membre__nom" style="flex:1">${t.nom}</span>
        </li>
      `
      )
      .join('');

    document.getElementById('listeUrgentes').querySelectorAll('[data-tache-id]').forEach((ligne) => {
      ligne.addEventListener('click', () => {
        naviguer('afaire', { profil, maisonId, maison });
      });
    });
  });

  definirNettoyage(arreterEcouteTaches);
}

// ------------------------------------------------------ écran paramètres

function afficherEcranParametres(profil, maisonId, maison) {
  ecran.innerHTML = `
    <div class="page">
      <button class="lien-texte" id="retour" style="margin:0 0 1rem; align-self:flex-start">← ${maison.nom}</button>
      <h1 class="titre anton">Paramètres</h1>

      <button class="bouton bouton--secondaire" id="aFaire">Voir toutes les tâches</button>
      <button class="bouton bouton--secondaire" id="historique">Historique</button>
      <button class="bouton bouton--secondaire" id="gerer">Pièces et tâches</button>

      <p class="tag" style="margin-top:1.5rem">Membres</p>
      <ul class="membres" id="membres"></ul>
      <p class="tag" style="margin-top:0.75rem; text-transform:none; letter-spacing:normal; font-weight:400">Notez ce code quelque part : c'est lui qui vous permettra de revenir si vous changez de téléphone ou videz les données du navigateur.</p>
      <button class="lien-texte" id="quitter">Quitter cette maison</button>
    </div>
  `;

  document.getElementById('retour').addEventListener('click', () => {
    history.back();
  });

  document.getElementById('gerer').addEventListener('click', () => {
    naviguer('gestion', { profil, maisonId, maison });
  });

  document.getElementById('aFaire').addEventListener('click', () => {
    naviguer('afaire', { profil, maisonId, maison });
  });

  document.getElementById('historique').addEventListener('click', () => {
    naviguer('historique', { profil, maisonId, maison });
  });

  const listeMembres = document.getElementById('membres');
  const arreterEcoute = ecouterMembres(maisonId, (membres) => {
    listeMembres.innerHTML = membres
      .map(
        (m) => `
        <li class="membre">
          <span class="jeton" style="--couleur:${m.couleur}">${initiale(m.prenom)}</span>
          <span class="membre__nom">${m.prenom}${m.id === profil.id ? ' (vous)' : ''}</span>
          ${m.id === profil.id ? '' : `<button class="membre__retirer" data-id="${m.id}" data-prenom="${m.prenom}">Retirer</button>`}
        </li>
      `
      )
      .join('');

    listeMembres.querySelectorAll('.membre__retirer').forEach((bouton) => {
      bouton.addEventListener('click', async () => {
        if (!confirm(`Retirer ${bouton.dataset.prenom} de cette maison ?`)) return;
        await retirerMembre(maisonId, bouton.dataset.id);
      });
    });
  });

  definirNettoyage(arreterEcoute);

  document.getElementById('quitter').addEventListener('click', async () => {
    if (!confirm('Quitter cette maison ?')) return;
    await quitterMaison(maisonId, profil.id);
    effacerMaisonId();
    naviguer('maison', { profil }, { remplacer: true });
  });
}

// -------------------------------------------------- écran pièces/tâches

function afficherEcranGestion(profil, maisonId, maison) {
  ecran.innerHTML = `
    <div class="page">
      <button class="lien-texte" id="retour" style="margin:0 0 1rem; align-self:flex-start">← ${maison.nom}</button>
      <h1 class="titre anton">Pièces<br>et tâches</h1>

      <div class="champ">
        <label for="nomPiece">Nouvelle pièce</label>
        <input id="nomPiece" type="text" placeholder="Cuisine">
      </div>
      <button class="bouton" id="ajouterPiece">Ajouter la pièce</button>

      <button class="lien-texte" id="exporter" style="margin-top:1.25rem">Exporter cette structure (.json)</button>

      <div id="erreurGestion"></div>
      <div id="listePieces" style="margin-top:1.75rem"></div>
    </div>
  `;

  function afficherErreur(message) {
    document.getElementById('erreurGestion').innerHTML = message
      ? `<div class="erreur">${message}</div>`
      : '';
  }

  document.getElementById('retour').addEventListener('click', () => {
    history.back();
  });

  document.getElementById('exporter').addEventListener('click', async () => {
    const structure = await exporterStructure(maisonId);
    const blob = new Blob([JSON.stringify(structure, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const lien = document.createElement('a');
    lien.href = url;
    lien.download = `${maison.nom.toLowerCase().replace(/[^a-z0-9]+/g, '-')}-modele.json`;
    lien.click();
    URL.revokeObjectURL(url);
  });

  document.getElementById('ajouterPiece').addEventListener('click', async () => {
    const champ = document.getElementById('nomPiece');
    const nom = champ.value.trim();
    if (!nom) return champ.focus();
    champ.value = '';
    await creerPiece(maisonId, nom);
  });

  let pieces = [];
  let taches = [];

  function rendreListe() {
    const conteneur = document.getElementById('listePieces');

    if (pieces.length === 0) {
      conteneur.innerHTML = '<p class="tag">Aucune pièce pour l’instant.</p>';
      return;
    }

    conteneur.innerHTML = pieces
      .map((piece) => {
        const tachesPiece = taches.filter((t) => t.pieceId === piece.id);
        return `
          <div class="piece" data-piece-id="${piece.id}">
            <div style="display:flex; align-items:center; gap:0.75rem; margin-bottom:0.5rem">
              <p class="tag" style="margin:0; flex:1">${piece.nom}</p>
              <button class="lien-texte piece-renommer" style="margin:0">Renommer</button>
              <button class="lien-texte piece-supprimer" style="margin:0">Supprimer</button>
            </div>
            <div class="edition-piece" hidden style="margin-bottom:0.75rem">
              <div class="champ">
                <label>Nom de la pièce</label>
                <input type="text" class="ch-piece-nom" value="${piece.nom}">
              </div>
              <button class="bouton bouton--secondaire btn-piece-enregistrer">Enregistrer</button>
            </div>
            <ul class="membres" style="margin-bottom:0.75rem">
              ${
                tachesPiece.length
                  ? tachesPiece
                      .map(
                        (t) => `
                <li class="membre" style="display:block; padding:0.625rem 0" data-tache-id="${t.id}">
                  <div style="display:flex; align-items:flex-start; gap:0.75rem">
                    <span class="emoji-case emoji-case--avenir">${t.emoji || EMOJI_PAR_DEFAUT}</span>
                    <div style="flex:1">
                      <span class="membre__nom">${t.nom}</span>
                      <span class="tag" style="margin:0.25rem 0 0">Tous les ${t.frequenceJours} j${t.produit ? ' · ' + t.produit : ''}</span>
                      ${t.astuce ? `<span class="tag" style="margin:0.15rem 0 0; color:var(--encre-faible)">${t.astuce}</span>` : ''}
                    </div>
                    <button class="lien-texte tache-modifier" style="margin:0">Modifier</button>
                    <button class="lien-texte tache-supprimer" style="margin:0">Supprimer</button>
                  </div>
                  <div class="edition-tache" hidden style="margin-top:0.75rem">
                    <div class="champ">
                      <label>Nom</label>
                      <input type="text" class="ch-mod-nom" value="${t.nom}">
                    </div>
                    <div class="champ">
                      <label>Fréquence (jours)</label>
                      <input type="number" class="ch-mod-frequence" value="${t.frequenceJours}" min="1">
                    </div>
                    <div class="champ">
                      <label>Produit</label>
                      <input type="text" class="ch-mod-produit" value="${t.produit || ''}">
                    </div>
                    <div class="champ">
                      <label>Astuce</label>
                      <input type="text" class="ch-mod-astuce" value="${t.astuce || ''}">
                    </div>
                    ${grilleEmoji(t.emoji || EMOJI_PAR_DEFAUT)}
                    <button class="bouton bouton--secondaire btn-tache-enregistrer">Enregistrer</button>
                  </div>
                </li>`
                      )
                      .join('')
                  : '<li class="membre" style="border:none; padding:0.375rem 0"><span class="tag">Aucune tâche.</span></li>'
              }
            </ul>
            <details>
              <summary class="lien-texte" style="display:inline-block; cursor:pointer">+ Ajouter une tâche</summary>
              <div class="champ" style="margin-top:0.75rem">
                <label>Nom</label>
                <input type="text" class="ch-nom" placeholder="Nettoyer l'évier">
              </div>
              <div class="champ">
                <label>Fréquence (jours)</label>
                <input type="number" class="ch-frequence" placeholder="7" min="1">
              </div>
              <div class="champ">
                <label>Produit</label>
                <input type="text" class="ch-produit" placeholder="Liquide vaisselle">
              </div>
              <div class="champ">
                <label>Astuce</label>
                <input type="text" class="ch-astuce" placeholder="Rincer et sécher">
              </div>
              ${grilleEmoji(EMOJI_PAR_DEFAUT)}
              <button class="bouton bouton--secondaire btn-ajouter-tache">Ajouter la tâche</button>
            </details>
          </div>
          <div style="border-bottom:2px solid var(--encre); margin:1.25rem 0"></div>
        `;
      })
      .join('');

    conteneur.querySelectorAll('.piece').forEach((blocPiece) => {
      const pieceId = blocPiece.dataset.pieceId;

      initSelecteurEmoji(blocPiece.querySelector('details'));

      blocPiece.querySelector('.btn-ajouter-tache').addEventListener('click', async () => {
        const nom = blocPiece.querySelector('.ch-nom').value.trim();
        const frequenceJours = blocPiece.querySelector('.ch-frequence').value;
        const produit = blocPiece.querySelector('.ch-produit').value.trim();
        const astuce = blocPiece.querySelector('.ch-astuce').value.trim();
        const emoji = valeurEmoji(blocPiece.querySelector('details'));

        if (!nom || !frequenceJours) return;

        await creerTache(maisonId, { nom, pieceId, frequenceJours, produit, astuce, emoji });
      });

      const editionPiece = blocPiece.querySelector('.edition-piece');
      blocPiece.querySelector('.piece-renommer').addEventListener('click', () => {
        editionPiece.hidden = !editionPiece.hidden;
      });
      blocPiece.querySelector('.btn-piece-enregistrer').addEventListener('click', async () => {
        const nom = blocPiece.querySelector('.ch-piece-nom').value.trim();
        if (!nom) return;
        await modifierPiece(maisonId, pieceId, nom);
        editionPiece.hidden = true;
      });
      blocPiece.querySelector('.piece-supprimer').addEventListener('click', async () => {
        if (!confirm('Supprimer cette pièce ?')) return;
        try {
          await supprimerPiece(maisonId, pieceId);
          afficherErreur(null);
        } catch (e) {
          afficherErreur(e.message);
        }
      });

      blocPiece.querySelectorAll('[data-tache-id]').forEach((ligneTache) => {
        const tacheId = ligneTache.dataset.tacheId;
        const editionTache = ligneTache.querySelector('.edition-tache');

        initSelecteurEmoji(editionTache);

        ligneTache.querySelector('.tache-modifier').addEventListener('click', () => {
          editionTache.hidden = !editionTache.hidden;
        });
        ligneTache.querySelector('.btn-tache-enregistrer').addEventListener('click', async () => {
          const nom = ligneTache.querySelector('.ch-mod-nom').value.trim();
          const frequenceJours = ligneTache.querySelector('.ch-mod-frequence').value;
          const produit = ligneTache.querySelector('.ch-mod-produit').value.trim();
          const astuce = ligneTache.querySelector('.ch-mod-astuce').value.trim();
          const emoji = valeurEmoji(editionTache);
          if (!nom || !frequenceJours) return;
          await modifierTache(maisonId, tacheId, { nom, frequenceJours, produit, astuce, emoji });
          editionTache.hidden = true;
        });
        ligneTache.querySelector('.tache-supprimer').addEventListener('click', async () => {
          if (!confirm('Supprimer cette tâche ?')) return;
          await supprimerTache(maisonId, tacheId);
        });
      });
    });
  }

  const arreterEcoutePieces = ecouterPieces(maisonId, (p) => {
    pieces = p;
    rendreListe();
  });
  const arreterEcouteTaches = ecouterTaches(maisonId, (t) => {
    taches = t;
    rendreListe();
  });

  // Nettoyage à la sortie de l'écran (évite deux écoutes concurrentes actives),
  // qu'on parte par le bouton retour ou par le bouton retour d'Android.
  definirNettoyage(() => {
    arreterEcoutePieces();
    arreterEcouteTaches();
  });
}

// -------------------------------------------------------- écran à faire

const LIBELLE_SECTION = {
  retard: 'En retard',
  aujourdhui: "À faire aujourd'hui",
  avenir: 'À venir',
  jamais: 'Jamais renseignées',
};

const ORDRE_SECTIONS = ['retard', 'aujourdhui', 'avenir', 'jamais'];

function afficherEcranAFaire(profil, maisonId, maison) {
  ecran.innerHTML = `
    <div class="page">
      <button class="lien-texte" id="retour" style="margin:0 0 1rem; align-self:flex-start">← ${maison.nom}</button>
      <h1 class="titre anton">À faire</h1>
      <div id="listeAFaire"></div>
    </div>
  `;

  document.getElementById('retour').addEventListener('click', () => {
    history.back();
  });

  // tacheId -> { finExpiree: () => void, forcerEnregistrement: () => void }
  // Le "Fait" est différé de quelques secondes : rien n'est écrit dans
  // Firestore avant l'expiration du délai. Ça permet une annulation simple
  // sans jamais toucher à une Réalisation déjà enregistrée (§ 3, règle
  // héritée, désormais imposée par firestore.rules : jamais modifiée, jamais
  // supprimée). Décidé avec Kinder le 2026-09-08 : pas de confirmation sur
  // ce geste (le plus fréquent de l'app, doit rester fluide), une annulation
  // après coup à la place.
  const DELAI_ANNULATION_MS = 5000;
  const enAttente = new Map();

  function rendre(taches) {
    const conteneur = document.getElementById('listeAFaire');

    if (taches.length === 0) {
      conteneur.innerHTML = '<p class="tag">Aucune tâche. Ajoutez-en depuis "Pièces et tâches".</p>';
      return;
    }

    // Une tâche tout juste cochée quitte immédiatement sa section d'origine
    // pour rejoindre un bloc "Fait ✓" à part — sinon, pendant les 5 secondes
    // d'annulation, elle restait plantée dans "En retard"/"À faire" avec
    // juste un bouton renommé, ce qui donnait l'impression que rien ne
    // s'était passé (audit du 2026-09-09, point 2).
    const tachesRestantes = taches.filter((t) => !enAttente.has(t.id));

    const groupes = { retard: [], aujourdhui: [], avenir: [], jamais: [] };
    tachesRestantes.forEach((t) => groupes[statutTache(t)].push(t));

    const blocFait = enAttente.size === 0 ? '' : `
      <p class="bandeau-section bandeau-section--fait">Fait ✓</p>
      <ul class="membres" style="margin:0 0 1.25rem">
        ${[...enAttente.values()].map(({ tache }) => `
          <li class="membre" data-tache-id="${tache.id}">
            <span class="emoji-case emoji-case--avenir">${tache.emoji || EMOJI_PAR_DEFAUT}</span>
            <span class="membre__nom" style="flex:1">${tache.nom}</span>
            <button class="bouton bouton--secondaire btn-annuler" style="width:auto; margin:0; padding:0.5rem 0.75rem">Annuler</button>
          </li>
        `).join('')}
      </ul>
    `;

    conteneur.innerHTML = blocFait + ORDRE_SECTIONS.filter((s) => groupes[s].length).map((s) => `
      <p class="bandeau-section${s === 'retard' ? ' bandeau-section--retard' : ''}">${LIBELLE_SECTION[s]}</p>
      <ul class="membres" style="margin:0 0 1.25rem">
        ${groupes[s].map((t) => `
          <li class="membre" data-tache-id="${t.id}">
            <span class="emoji-case emoji-case--${s === 'retard' || s === 'aujourdhui' ? 'du' : s}">${t.emoji || EMOJI_PAR_DEFAUT}</span>
            <span class="membre__nom" style="flex:1">
              ${t.nom}
              <span class="tag" style="margin:0.2rem 0 0">${t.prochaineEcheance ? 'échéance ' + t.prochaineEcheance : 'pas encore faite'}</span>
            </span>
            <button class="bouton bouton--secondaire btn-cocher" style="width:auto; margin:0; padding:0.5rem 0.75rem">Fait</button>
          </li>
        `).join('')}
      </ul>
    `).join('');

    conteneur.querySelectorAll('.btn-annuler').forEach((bouton) => {
      const tacheId = bouton.closest('[data-tache-id]').dataset.tacheId;
      bouton.addEventListener('click', () => {
        enAttente.get(tacheId)?.annuler();
      });
    });

    conteneur.querySelectorAll('.btn-cocher').forEach((bouton) => {
      bouton.addEventListener('click', async () => {
        const li = bouton.closest('[data-tache-id]');
        const tache = taches.find((t) => t.id === li.dataset.tacheId);

        const aujourdhui = dateAujourdhui();
        const prochaineEcheance = ajouterJours(aujourdhui, tache.frequenceJours);

        let enregistre = false;
        const enregistrer = async () => {
          if (enregistre) return;
          enregistre = true;
          enAttente.delete(tache.id);
          await enregistrerRealisation(maisonId, tache.id, profil.id, aujourdhui, prochaineEcheance);
        };

        const minuteur = setTimeout(enregistrer, DELAI_ANNULATION_MS);

        enAttente.set(tache.id, {
          tache,
          forcerEnregistrement: () => {
            clearTimeout(minuteur);
            enregistrer();
          },
          annuler: () => {
            if (enregistre) return;
            clearTimeout(minuteur);
            enregistre = true;
            enAttente.delete(tache.id);
            rendre(taches);
          },
        });

        rendre(taches);
      });
    });
  }

  const arreterEcouteTaches = ecouterTaches(maisonId, rendre);

  // Nettoyage à la sortie de l'écran, qu'on parte par le bouton retour ou
  // par le bouton retour d'Android. Un "Fait" en attente d'annulation qui
  // n'a pas encore expiré doit tout de même s'enregistrer si on quitte
  // l'écran — sinon un geste réel se perdrait silencieusement juste parce
  // qu'on a changé d'écran.
  definirNettoyage(() => {
    arreterEcouteTaches();
    enAttente.forEach((p) => p.forcerEnregistrement());
  });
}

// ---------------------------------------------------- écran historique

function libelleJour(dateISO) {
  const aujourdhui = dateAujourdhui();
  const hier = ajouterJours(aujourdhui, -1);
  if (dateISO === aujourdhui) return "Aujourd'hui";
  if (dateISO === hier) return 'Hier';
  return dateISO;
}

function afficherEcranHistorique(profil, maisonId, maison) {
  ecran.innerHTML = `
    <div class="page">
      <button class="lien-texte" id="retour" style="margin:0 0 1rem; align-self:flex-start">← ${maison.nom}</button>
      <h1 class="titre anton">Historique</h1>
      <div id="listeHistorique"></div>
    </div>
  `;

  let taches = [];
  let membres = [];
  let realisations = [];

  function rendre() {
    const conteneur = document.getElementById('listeHistorique');

    if (realisations.length === 0) {
      conteneur.innerHTML = '<p class="tag">Aucune réalisation pour l’instant.</p>';
      return;
    }

    const parJour = {};
    realisations.forEach((r) => {
      (parJour[r.dateRealisation] ??= []).push(r);
    });

    conteneur.innerHTML = Object.keys(parJour)
      .sort((a, b) => b.localeCompare(a))
      .map((jour) => `
        <p class="tag" style="margin:1.25rem 0 0.5rem">${libelleJour(jour)}</p>
        <ul class="membres" style="margin:0">
          ${parJour[jour].map((r) => {
            const tache = taches.find((t) => t.id === r.tacheId);
            const membre = membres.find((m) => m.id === r.realiseParId);
            return `
              <li class="membre">
                <span class="jeton" style="--couleur:${membre ? membre.couleur : '#999'}">${membre ? initiale(membre.prenom) : '?'}</span>
                <span class="emoji-case emoji-case--avenir" style="width:2rem; height:2rem; font-size:1.125rem">${tache ? (tache.emoji || EMOJI_PAR_DEFAUT) : '❔'}</span>
                <span class="membre__nom">${tache ? tache.nom : 'Tâche supprimée'} <span class="tag" style="margin:0">par ${membre ? membre.prenom : '?'}</span></span>
              </li>
            `;
          }).join('')}
        </ul>
      `).join('');
  }

  document.getElementById('retour').addEventListener('click', () => {
    history.back();
  });

  const arreterTaches = ecouterTaches(maisonId, (t) => { taches = t; rendre(); });
  const arreterMembres = ecouterMembres(maisonId, (m) => { membres = m; rendre(); });
  const arreterRealisations = ecouterRealisations(maisonId, (r) => { realisations = r; rendre(); });

  // Nettoyage à la sortie de l'écran, qu'on parte par le bouton retour ou
  // par le bouton retour d'Android.
  definirNettoyage(() => {
    arreterTaches();
    arreterMembres();
    arreterRealisations();
  });
}

// ------------------------------------------------------------- routage
//
// Historique du navigateur réel (history.pushState/popstate), pas juste un
// remplacement de contenu : sans ça, le bouton retour d'Android n'a nulle
// part où revenir et ferme l'application directement au lieu de naviguer
// dans l'app (peaufinage V2, audit du 2026-09-09).
//
// "profil" et "maison" (les écrans de démarrage, avant d'être dans une
// maison) remplacent toujours l'entrée d'historique courante : ce sont des
// portes d'entrée, pas des pages qu'on veut retrouver avec le bouton retour.
// Une fois dans une maison, "accueil" est la racine de la pile ; "gestion",
// "afaire" et "historique" empilent une entrée, pour que retour ramène
// naturellement à l'accueil.

// Nettoyage (désabonnements Firestore, etc.) de l'écran actuellement
// affiché, à exécuter avant d'en afficher un autre — que ce soit une
// navigation normale ou le bouton retour d'Android.
let arreterEcranActuel = () => {};

function definirNettoyage(fonction) {
  arreterEcranActuel = fonction || (() => {});
}

function rendreVue(etat) {
  const { vue, params } = etat;
  if (vue === 'profil') return afficherEcranProfil(params.uid);
  if (vue === 'maison') return afficherEcranMaison(params.profil);
  if (vue === 'accueil') return afficherEcranAccueil(params.profil, params.maisonId);
  if (vue === 'gestion') return afficherEcranGestion(params.profil, params.maisonId, params.maison);
  if (vue === 'afaire') return afficherEcranAFaire(params.profil, params.maisonId, params.maison);
  if (vue === 'historique') return afficherEcranHistorique(params.profil, params.maisonId, params.maison);
  if (vue === 'parametres') return afficherEcranParametres(params.profil, params.maisonId, params.maison);
}

function naviguer(vue, params = {}, { remplacer = false } = {}) {
  arreterEcranActuel();
  arreterEcranActuel = () => {};
  const etat = { vue, params };
  if (remplacer) {
    history.replaceState(etat, '');
  } else {
    history.pushState(etat, '');
  }
  rendreVue(etat);
}

window.addEventListener('popstate', (evenement) => {
  if (!evenement.state) return;
  arreterEcranActuel();
  arreterEcranActuel = () => {};
  rendreVue(evenement.state);
});

async function demarrer() {
  // L'authentification anonyme doit être résolue avant tout appel Firestore :
  // c'est elle qui rend l'appareil vérifiable côté serveur (règles fermées).
  const uid = await assurerAuthentification();

  const profil = chargerProfil();
  if (!profil) return naviguer('profil', { uid }, { remplacer: true });

  const maisonId = chargerMaisonId();
  if (!maisonId) return naviguer('maison', { profil }, { remplacer: true });

  naviguer('accueil', { profil, maisonId }, { remplacer: true });
}

demarrer();
