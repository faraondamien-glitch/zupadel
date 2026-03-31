import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

// 🔧 Remplace par ta config Firebase (console.firebase.google.com → Paramètres du projet → Tes applications)
const firebaseConfig = {
  apiKey: "AIzaSyBxvu8zHy98pFZ3Yh5ilNGOtOvDWSLEZjU",
  authDomain: "zupadel2.firebaseapp.com",
  projectId: "zupadel2",
  storageBucket: "zupadel2.firebasestorage.app",
  messagingSenderId: "412115504586",
  appId: "1:412115504586:web:470bfd0261b2d2882e1333",
  measurementId: "G-71FPXNSCB0"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
