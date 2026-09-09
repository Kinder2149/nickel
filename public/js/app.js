// NICKEL — couche LOGIQUE + rendu de l'interface
//
// Direction visuelle : « le registre d'entretien ». L'app n'est pas une
// todo-list de plus — c'est un carnet de maintenance de l'habitat.
// Papier kraft, encre noire, bandeaux inversés, codes en machine à écrire.
//
// La logique n'a pas changé depuis l'étape 7 : mêmes trois onglets,
// mêmes sections, même geste. Seul l'habillage est nouveau.

import {
  chargerHabitants,
  ecouterTaches,
  ecouterRealisations,
  definirProchaineEcheance,
  enregistrerRealisation,
} from './donnees.js';

const CLE_STOCKAGE = 'nickel.habitantId';
const CLE_VUE = 'nickel.vue';

const ecran = document.getElementById('ecran');

let habitants = [];
let taches = [];
let realisations = [];
let vue = 'afaire';
let pret = false;

// ---------------------------------------------------------------- mémoire

/** Identifiant de l'habitant mémorisé sur CET appareil, ou null. */
function profilMemorise() {
  try {
    return localStorage.getItem(CLE_STOCKAGE);
  } catch {
    // Navigation privée ou stockage refusé : on redemandera à chaque fois.
    return null;
  }
}

function memoriserProfil(id) {
  try {
    localStorage.setItem(CLE_STOCKAGE, id);
  } catch {
    // Sans mémoire, l'app reste utilisable — elle redemandera le profil.
  }
}

function oublierProfil() {
  try {
    localStorage.removeItem(CLE_STOCKAGE);
  } catch {
    /* rien à faire */
  }
}

function memoriserVue(nom) {
  try {
    localStorage.setItem(CLE_VUE, nom);
  } catch {
    /* rien à faire */
  }
}

function vueMemorisee() {
  try {
    return localStorage.getItem(CLE_VUE) || 'afaire';
  } catch {
    return 'afaire';
  }
}

// ------------------------------------------------------------------ dates

/** Aujourd'hui en « AAAA-MM-JJ », dans le fuseau du téléphone. */
function aujourdhui() {
  const d = new Date();
  const mois = String(d.getMonth() + 1).padStart(2, '0');
  const jour = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${mois}-${jour}`;
}

/** « AAAA-MM-JJ » + n jours → « AAAA-MM-JJ ». */
function ajouterJours(dateISO, n) {
  const [a, m, j] = dateISO.split('-').map(Number);
  // Construction en heure locale : évite le décalage d'un jour que
  // provoquerait new Date('AAAA-MM-JJ'), interprété en UTC.
  const d = new Date(a, m - 1, j + n);
  const mois = String(d.getMonth() + 1).padStart(2, '0');
  const jour = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${mois}-${jour}`;
}

/** Nombre de jours entre deux dates « AAAA-MM-JJ » (b - a). */
function ecartJours(a, b) {
  const [aa, am, aj] = a.split('-').map(Number);
  const [ba, bm, bj] = b.split('-').map(Number);
  const MS_PAR_JOUR = 86400000;
  return Math.round((new Date(ba, bm - 1, bj) - new Date(aa, am - 1, aj)) / MS_PAR_JOUR);
}

/** « 2026-09-14 » → « lun. 14 sept. ». */
function dateLisible(dateISO) {
  const [a, m, j] = dateISO.split('-').map(Number);
  return new Date(a, m - 1, j).toLocaleDateString('fr-FR', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  });
}

/** « 2026-09-08 » → « 08.09 » — format registre. */
function dateCode(dateISO) {
  const [, m, j] = dateISO.split('-');
  return `${j}.${m}`;
}

/** Le jour courant tel qu'affiché en tête d'écran. */
function dateEntete() {
  return new Date().toLocaleDateString('fr-FR', {
    weekday: 'short',
    day: '2-digit',
    month: 'short',
  });
}

/** « en retard de 3 jours », « aujourd'hui », « dans 4 jours »… */
function echeanceLisible(dateISO) {
  const ecart = ecartJours(aujourdhui(), dateISO);

  if (ecart === 0) return "aujourd'hui";
  if (ecart === 1) return 'demain';
  if (ecart < 0) return `retard ${-ecart} j`;
  if (ecart <= 7) return `dans ${ecart} jours`;
  return dateLisible(dateISO);
}

/** « 7 » → « 07 J » — code de fréquence du registre. */
function codeFrequence(jours) {
  return `${String(jours).padStart(2, '0')} J`;
}

// ------------------------------------------------------- statuts (calculés)

/**
 * Statut d'une tâche, déduit de sa prochaine échéance (D8).
 * @returns {'jamais'|'retard'|'aujourdhui'|'bientot'|'plustard'}
 */
function statut(tache) {
  if (tache.prochaineEcheance === null) return 'jamais';

  const ecart = ecartJours(aujourdhui(), tache.prochaineEcheance);
  if (ecart < 0) return 'retard';
  if (ecart === 0) return 'aujourdhui';
  if (ecart <= 7) return 'bientot';
  return 'plustard';
}

const SECTIONS = [
  { cle: 'retard', titre: 'En retard' },
  { cle: 'aujourdhui', titre: "Aujourd'hui" },
  { cle: 'bientot', titre: 'Dans les 7 jours' },
  { cle: 'jamais', titre: 'Jamais renseignées' },
];

/** Une tâche est « due » quand elle appelle une action aujourd'hui. */
const EST_DU = new Set(['retard', 'aujourdhui']);

// ------------------------------------------------------------- formatage

/** « 7 » → « Toutes les semaines ». Repli générique si la valeur est inattendue. */
function libelleFrequence(jours) {
  const connus = {
    1: 'Tous les jours',
    7: 'Toutes les semaines',
    14: 'Toutes les 2 semaines',
    30: 'Tous les mois',
    90: 'Tous les 3 mois',
    180: 'Tous les 6 mois',
    365: 'Tous les ans',
  };
  return connus[jours] || `Tous les ${jours} jours`;
}

function echapper(texte) {
  return String(texte).replace(/[&<>"]/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])
  );
}

/** « Val » → « VA ». Les initiales servent de signature dans l'historique. */
function initiales(nom) {
  return nom.slice(0, 2).toUpperCase();
}

function jeton(habitant, taille) {
  return `
    <span class="jeton mono" style="--couleur:${habitant.couleur}; --taille:${taille}">
      ${echapper(initiales(habitant.nom))}
    </span>`;
}

/** Le nombre affiché dans un bandeau de section : toujours sur deux chiffres. */
function compte(n) {
  return String(n).padStart(2, '0');
}

// ------------------------------------------------------------------ rendu

function afficherChoixProfil() {
  ecran.innerHTML = `
    <div class="vue vue--choix">
      <div class="garde">
        <h1 class="anton">Nickel</h1>
        <div class="garde__meta mono">
          Registre d'entretien<br>
          ${habitants.length} habitants · ${taches.length} tâches
        </div>
      </div>

      <p class="question mono">Qui es-tu&nbsp;?</p>

      <div class="profils">
        ${habitants
          .map(
            (h, i) => `
          <button class="profil" data-id="${h.id}">
            ${jeton(h, '3.125rem')}
            <span class="profil__nom anton">${echapper(h.nom)}</span>
            <span class="profil__rang mono">${compte(i + 1)}</span>
          </button>`
          )
          .join('')}
      </div>

      <p class="aide mono">Ce téléphone se souviendra de toi.</p>
    </div>`;

  ecran.querySelectorAll('.profil').forEach((bouton) => {
    bouton.addEventListener('click', () => {
      memoriserProfil(bouton.dataset.id);
      afficherAccueil();
    });
  });
}

/** Les raccourcis de saisie : « fait il y a n jours ». */
const RACCOURCIS = [
  { libelle: "Aujourd'hui", jours: 0 },
  { libelle: '−3 J', jours: 3 },
  { libelle: '−7 J', jours: 7 },
];

/** Ligne de la vue « À faire ». */
function ligneAFaire(tache) {
  const etat = statut(tache);
  const du = EST_DU.has(etat);

  const code = codeFrequence(tache.frequenceJours);

  const meta =
    etat === 'retard'
      ? `<span class="tampon">Retard ${-ecartJours(aujourdhui(), tache.prochaineEcheance)} j</span>${code} · ${echapper(tache.commentFaire).slice(0, 40)}`
      : etat === 'aujourdhui'
      ? `${code} · ${echapper(tache.commentFaire).slice(0, 44)}`
      : etat === 'jamais'
      ? `${code} · jamais renseignée`
      : `${code} · ${echeanceLisible(tache.prochaineEcheance)}`;

  // TOUTE tâche reste cochable, même pas encore due (décision figée D7).
  // Seul le poids visuel change : la case d'une tâche à venir est discrète.
  return `
    <li class="tache ${du ? 'tache--du' : ''}" data-id="${tache.id}">
      <span class="vignette ${du ? '' : 'vignette--pale'}">${echapper(tache.emoji)}</span>
      <span class="tache__corps">
        <span class="tache__nom ${du ? '' : 'tache__nom--pale'}">${echapper(tache.nom)}</span>
        <span class="tache__meta ${etat === 'jamais' ? 'tache__meta--faible' : ''}">${meta}</span>
      </span>
      <button class="case ${du ? '' : 'case--douce'}" data-cocher="${tache.id}"
              aria-label="Marquer « ${echapper(tache.nom)} » comme fait">
        <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor"
             stroke-width="3" stroke-linecap="square"><path d="M4 12.5 9.5 18 20 6.5"/></svg>
      </button>
    </li>`;
}

/** Ligne de la vue « Toutes » : la saisie des échéances. */
function ligneReglage(tache) {
  const renseignee = tache.prochaineEcheance !== null;

  const meta = renseignee
    ? `<span class="tache__meta tache__meta--vert">▸ Prochaine : ${dateLisible(tache.prochaineEcheance)}</span>`
    : `<span class="tache__meta tache__meta--faible">Jamais renseignée</span>`;

  const puces = RACCOURCIS.map(
    (r) => `<button class="puce" data-id="${tache.id}" data-jours="${r.jours}">${r.libelle}</button>`
  ).join('');

  return `
    <li class="reglage" data-id="${tache.id}">
      <span class="reglage__haut">
        <span class="vignette ${renseignee ? '' : 'vignette--attente'}">${echapper(tache.emoji)}</span>
        <span class="tache__corps">
          <span class="tache__nom">${echapper(tache.nom)}</span>
          ${meta}
        </span>
        <span class="code">${codeFrequence(tache.frequenceJours)}</span>
      </span>
      <span class="puces">
        ${puces}
        <label class="puce puce--douce puce--date">
          Date…
          <input type="date" data-id="${tache.id}" max="${aujourdhui()}">
        </label>
        ${renseignee ? `<button class="puce puce--douce" data-id="${tache.id}" data-effacer="1">Jamais</button>` : ''}
      </span>
    </li>`;
}

/** Corps de la vue « À faire ». */
function corpsAFaire() {
  const parStatut = {};
  for (const tache of taches) {
    (parStatut[statut(tache)] ||= []).push(tache);
  }

  // Au sein d'une section : la plus urgente d'abord.
  for (const liste of Object.values(parStatut)) {
    liste.sort(
      (a, b) =>
        (a.prochaineEcheance || '9999').localeCompare(b.prochaineEcheance || '9999') ||
        a.nom.localeCompare(b.nom, 'fr')
    );
  }

  const sections = SECTIONS.filter((s) => parStatut[s.cle]?.length).map(
    (s) => `
      <div class="bande ${s.cle === 'retard' ? 'bande--retard' : ''}">
        <span>${s.titre}</span><span>${compte(parStatut[s.cle].length)}</span>
      </div>
      <ul class="taches">${parStatut[s.cle].map(ligneAFaire).join('')}</ul>`
  );

  const plusTard = parStatut.plustard?.length || 0;

  if (sections.length === 0) {
    return `
      <div class="vide">
        <p class="vide__titre anton">Rien à faire</p>
        <p class="vide__detail">
          ${plusTard > 0 ? `${compte(plusTard)} tâches à venir plus tard.` : 'Aucune tâche renseignée.'}
        </p>
      </div>`;
  }

  return `
    ${sections.join('')}
    ${plusTard > 0 ? `<p class="reste">+ ${compte(plusTard)} plus tard</p>` : ''}`;
}

/** Corps de la vue « Toutes » : réglage des échéances. */
function corpsToutes() {
  const renseignees = taches.filter((t) => t.prochaineEcheance !== null).length;

  const groupes = [];
  for (const tache of taches) {
    const dernier = groupes[groupes.length - 1];
    if (dernier && dernier.frequence === tache.frequenceJours) {
      dernier.taches.push(tache);
    } else {
      groupes.push({ frequence: tache.frequenceJours, taches: [tache] });
    }
  }

  const segments = taches
    .map((_, i) => `<span class="${i < renseignees ? 'plein' : ''}"></span>`)
    .join('');

  return `
    <div class="avancement">
      <div class="avancement__chiffre">
        <strong class="anton" id="compteur">${compte(renseignees)}</strong>
        <span class="avancement__sur">/ ${taches.length} renseignées</span>
      </div>
      <div class="jauge" id="jauge">${segments}</div>
      <p class="avancement__aide">
        Quand as-tu fait chaque tâche pour la dernière fois&nbsp;? Approximatif convient.
      </p>
    </div>

    ${groupes
      .map(
        (groupe) => `
      <div class="bande">
        <span>${libelleFrequence(groupe.frequence)}</span><span>${compte(groupe.taches.length)}</span>
      </div>
      <ul class="taches">${groupe.taches.map(ligneReglage).join('')}</ul>`
      )
      .join('')}`;
}

/**
 * Corps de la vue « Historique ».
 *
 * C'est la liste des Réalisations, rien de plus : l'historique n'est pas
 * une fonctionnalité séparée, il tombe mécaniquement du modèle (§ 3).
 */
function corpsHistorique() {
  if (realisations.length === 0) {
    return `
      <div class="vide">
        <p class="vide__titre anton">Registre vierge</p>
        <p class="vide__detail">La première tâche cochée apparaîtra ici.</p>
      </div>`;
  }

  // Regroupement par jour, dans l'ordre déjà trié (plus récent en premier).
  const jours = [];
  for (const realisation of realisations) {
    const dernier = jours[jours.length - 1];
    if (dernier && dernier.date === realisation.dateRealisation) {
      dernier.realisations.push(realisation);
    } else {
      jours.push({ date: realisation.dateRealisation, realisations: [realisation] });
    }
  }

  const titreJour = (dateISO) => {
    const ecart = ecartJours(dateISO, aujourdhui());
    const prefixe = ecart === 0 ? "Aujourd'hui" : ecart === 1 ? 'Hier' : dateLisible(dateISO);
    return `${prefixe} — ${dateCode(dateISO)}`;
  };

  return jours
    .map(
      (jour, rang) => `
    <div class="bande">
      <span>${titreJour(jour.date)}</span><span>${compte(jour.realisations.length)}</span>
    </div>
    <ul class="taches">
      ${jour.realisations
        .map((realisation) => {
          const tache = taches.find((t) => t.id === realisation.tacheId);
          const habitant = habitants.find((h) => h.id === realisation.realiseParId);
          const recent = rang === 0;

          return `
        <li class="tache ${recent ? 'tache--du' : ''}">
          <span class="vignette ${recent ? '' : 'vignette--pale'}">${echapper(tache ? tache.emoji : '·')}</span>
          <span class="tache__corps">
            <span class="tache__nom ${recent ? '' : 'tache__nom--pale'}">${echapper(tache ? tache.nom : 'Tâche supprimée')}</span>
          </span>
          ${habitant
            ? jeton(habitant, '2.125rem')
            : '<span class="jeton mono" style="--couleur:#8A8474; --taille:2.125rem">??</span>'}
        </li>`;
        })
        .join('')}
    </ul>`
    )
    .join('');
}

const VUES = {
  afaire: corpsAFaire,
  toutes: corpsToutes,
  historique: corpsHistorique,
};

const ONGLETS = [
  { cle: 'afaire', titre: 'À faire' },
  { cle: 'toutes', titre: 'Toutes' },
  { cle: 'historique', titre: 'Historique' },
];

function afficherAccueil() {
  const habitant = habitants.find((h) => h.id === profilMemorise());

  // Profil mémorisé qui n'existe plus en base : on repart du choix.
  if (!habitant) {
    oublierProfil();
    afficherChoixProfil();
    return;
  }

  // Les tâches arrivent en temps réel : sans cela, la position de lecture
  // sauterait en haut à chaque modification faite par un autre habitant.
  const defilement = ecran.querySelector('.liste')?.scrollTop ?? 0;

  ecran.innerHTML = `
    <div class="vue">
      <header class="entete">
        <div class="entete__haut">
          <span class="anton entete__titre">Nickel</span>
          <button class="entete__identite" id="changer" aria-label="Changer d'habitant">
            ${jeton(habitant, '2.25rem')}
          </button>
        </div>
        <div class="entete__meta mono">
          <span>Registre d'entretien</span>
          <span>${dateEntete()}</span>
        </div>
      </header>

      <nav class="onglets">
        ${ONGLETS.map(
          (o) => `
          <button class="onglet ${vue === o.cle ? 'onglet--actif' : ''}" data-vue="${o.cle}">${o.titre}</button>`
        ).join('')}
      </nav>

      <div class="liste">${(VUES[vue] || corpsAFaire)()}</div>
    </div>`;

  const liste = ecran.querySelector('.liste');
  if (liste) liste.scrollTop = defilement;

  document.getElementById('changer').addEventListener('click', () => {
    oublierProfil();
    afficherChoixProfil();
  });

  ecran.querySelectorAll('.onglet').forEach((bouton) => {
    bouton.addEventListener('click', () => {
      vue = bouton.dataset.vue;
      memoriserVue(vue);
      afficherAccueil();
    });
  });

  brancherActions();
}

// -------------------------------------------------------------- cocher

/**
 * Le geste central de l'application (§ 2).
 *
 * Crée une Réalisation au nom de l'habitant qui utilise l'appareil (D9),
 * puis repousse l'échéance à aujourd'hui + fréquence (D5).
 */
async function cocher(tacheId) {
  const tache = taches.find((t) => t.id === tacheId);
  const habitantId = profilMemorise();
  if (!tache || !habitantId) return;

  const ligne = ecran.querySelector(`.tache[data-id="${tacheId}"]`);
  if (ligne) ligne.classList.add('tache--cochee');

  const date = aujourdhui();
  const echeance = ajouterJours(date, tache.frequenceJours);

  try {
    await enregistrerRealisation(tacheId, habitantId, date, echeance);
    // L'écoute temps réel se charge de redessiner l'écran : la tâche
    // quitte la liste du jour d'elle-même, ici comme sur les autres
    // téléphones.
  } catch (erreur) {
    if (ligne) {
      ligne.classList.remove('tache--cochee');
      ligne.classList.add('tache--erreur');
    }
    console.error('Impossible de cocher', tacheId, erreur);
  }
}

// ----------------------------------------------------------- enregistrement

/**
 * Enregistre la dernière réalisation d'une tâche et en déduit la prochaine
 * échéance : dernière réalisation + fréquence (décision figée D5).
 *
 * Utilisé par l'initialisation (étape 4) : ne crée AUCUNE Réalisation,
 * puisqu'on ignore qui a fait la tâche par le passé.
 */
async function enregistrer(tacheId, derniereRealisationISO) {
  const tache = taches.find((t) => t.id === tacheId);
  if (!tache) return;

  const echeance =
    derniereRealisationISO === null
      ? null
      : ajouterJours(derniereRealisationISO, tache.frequenceJours);

  try {
    await definirProchaineEcheance(tacheId, echeance);
  } catch (erreur) {
    const ligne = ecran.querySelector(`[data-id="${tacheId}"]`);
    if (ligne) ligne.classList.add('tache--erreur');
    console.error('Enregistrement impossible', tacheId, erreur);
  }
}

/**
 * Un seul écouteur sur la liste, plutôt qu'un par bouton : les lignes sont
 * redessinées à chaque changement reçu en temps réel, et des écouteurs
 * individuels seraient perdus à la première mise à jour.
 */
function brancherActions() {
  const liste = ecran.querySelector('.liste');
  if (!liste) return;

  liste.addEventListener('click', (evenement) => {
    const boutonCocher = evenement.target.closest('[data-cocher]');
    if (boutonCocher) {
      cocher(boutonCocher.dataset.cocher);
      return;
    }

    const puce = evenement.target.closest('.puce');
    if (!puce || puce.tagName !== 'BUTTON') return;

    if (puce.dataset.effacer) {
      enregistrer(puce.dataset.id, null);
    } else {
      enregistrer(puce.dataset.id, ajouterJours(aujourdhui(), -Number(puce.dataset.jours)));
    }
  });

  liste.addEventListener('change', (evenement) => {
    const champ = evenement.target;
    if (champ.type !== 'date' || !champ.value) return;
    enregistrer(champ.dataset.id, champ.value);
  });
}

function afficherErreur(message) {
  ecran.innerHTML = `
    <div class="vue vue--choix">
      <div class="garde">
        <h1 class="anton">Nickel</h1>
        <div class="garde__meta mono">Données inaccessibles</div>
      </div>
      <p class="detail">${echapper(message)}</p>
      <button class="lien" onclick="location.reload()">Réessayer</button>
    </div>`;
}

// ---------------------------------------------------------------- démarrage

try {
  vue = vueMemorisee();
  habitants = await chargerHabitants();

  if (habitants.length === 0) {
    afficherErreur('Aucun habitant en base.');
  } else {
    ecouterTaches((nouvelles) => {
      taches = nouvelles;

      if (!pret) {
        pret = true;
        if (profilMemorise()) afficherAccueil();
        else afficherChoixProfil();
        return;
      }

      // Mise à jour reçue d'un autre téléphone (ou de soi-même) :
      // on redessine, sauf si l'écran de choix de profil est affiché.
      if (!ecran.querySelector('.vue--choix')) afficherAccueil();
    });

    ecouterRealisations((nouvelles) => {
      realisations = nouvelles;
      // Ne redessiner que si l'historique est à l'écran : inutile de
      // reconstruire la liste du jour pour une réalisation.
      if (pret && vue === 'historique' && !ecran.querySelector('.vue--choix')) {
        afficherAccueil();
      }
    });
  }
} catch (erreur) {
  afficherErreur(erreur.message);
}
