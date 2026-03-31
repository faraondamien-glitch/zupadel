import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

// 🔧 Remplace par ta config Firebase (console.firebase.google.com → Paramètres du projet → Tes applications)
const firebaseConfig = {
  apiKey: "REMPLACE_PAR_TA_API_KEY",
  authDomain: "zupadel2.firebaseapp.com",
  projectId: "zupadel2",
  storageBucket: "zupadel2.appspot.com",
  messagingSenderId: "REMPLACE_PAR_TON_SENDER_ID",
  appId: "REMPLACE_PAR_TON_APP_ID",
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
