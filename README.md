# Zupadel Admin — Back-office

App React connectée à Firebase avec authentification et données temps réel.

## Setup en 5 étapes

### 1. Installer les dépendances
```bash
cd zupadel-admin
npm install
```

### 2. Configurer Firebase
Ouvre `src/firebase.js` et remplace les valeurs par ta config Firebase :
- Va sur console.firebase.google.com
- Projet zupadel2 → Paramètres → Tes applications → SDK de configuration Web
- Copie les valeurs apiKey, authDomain, projectId, etc.

### 3. Créer les comptes admin
Dans Firebase Console → Authentication → Ajouter un utilisateur :
- Email : ton email admin
- Mot de passe : mot de passe sécurisé

⚠️ Seuls les comptes créés ici auront accès au back-office.

### 4. Lancer en local
```bash
npm start
```
L'app s'ouvre sur http://localhost:3000

### 5. Déployer sur Firebase Hosting
```bash
npm run build
firebase deploy --only hosting --project zupadel2
```
URL : https://zupadel2.web.app

## Sécurité — Règles Firestore
Ajoute ces règles dans Firebase Console → Firestore → Règles pour protéger les données admin :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Liste des emails admin autorisés
    function isAdmin() {
      return request.auth != null && request.auth.token.email in [
        'ton-email@gmail.com',
        'email-equipe@gmail.com'
      ];
    }

    match /{document=**} {
      allow read, write: if isAdmin();
    }
  }
}
```

## Fonctionnalités
- Dashboard : métriques temps réel (users, matchs, en attente)
- Utilisateurs : liste, bannir/débannir, ajout crédits manuel
- Tournois : valider / refuser / dépublier
- Inscriptions : accepter / refuser par tournoi
- Coachs : valider abonnements, suspendre
- Concours : attribuer crédits + historique complet
