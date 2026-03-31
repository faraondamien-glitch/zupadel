import { useState } from "react";
import { signInWithEmailAndPassword } from "firebase/auth";
import { auth } from "./firebase";

export default function Login() {
  const [email, setEmail]       = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState("");
  const [show, setShow]         = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch {
      setError("Email ou mot de passe incorrect.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={s.page}>
      <div style={s.grid}></div>
      <div style={s.card}>
        <div style={s.logo}>ZUPADEL</div>
        <div style={s.sub}>Back-office admin</div>

        <form onSubmit={submit} style={s.form}>
          <div style={s.field}>
            <label style={s.label}>Email</label>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              style={s.input}
              placeholder="admin@zupadel.com"
              required
            />
          </div>
          <div style={s.field}>
            <label style={s.label}>Mot de passe</label>
            <div style={{ position: "relative" }}>
              <input
                type={show ? "text" : "password"}
                value={password}
                onChange={e => setPassword(e.target.value)}
                style={{ ...s.input, paddingRight: 44 }}
                placeholder="••••••••"
                required
              />
              <button
                type="button"
                onClick={() => setShow(!show)}
                style={s.eyeBtn}
              >
                {show ? "🙈" : "👁"}
              </button>
            </div>
          </div>

          {error && <div style={s.error}>{error}</div>}

          <button type="submit" style={s.btn} disabled={loading}>
            {loading ? "Connexion..." : "Se connecter →"}
          </button>
        </form>

        <div style={s.footer}>Accès réservé à l'équipe Zupadel</div>
      </div>
    </div>
  );
}

const s = {
  page: {
    minHeight: "100vh",
    background: "#0D0F14",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    position: "relative",
    overflow: "hidden",
  },
  grid: {
    position: "absolute",
    inset: 0,
    backgroundImage: `
      linear-gradient(rgba(200,240,74,0.04) 1px, transparent 1px),
      linear-gradient(90deg, rgba(200,240,74,0.04) 1px, transparent 1px)
    `,
    backgroundSize: "40px 40px",
  },
  card: {
    position: "relative",
    width: 400,
    background: "#161920",
    border: "1px solid rgba(255,255,255,0.08)",
    borderRadius: 20,
    padding: "48px 40px",
    textAlign: "center",
  },
  logo: {
    fontFamily: "'Syne', sans-serif",
    fontSize: 36,
    fontWeight: 800,
    color: "#C8F04A",
    letterSpacing: -1,
    marginBottom: 6,
  },
  sub: {
    fontSize: 13,
    color: "#7A8090",
    marginBottom: 40,
    fontFamily: "'DM Sans', sans-serif",
  },
  form: {
    display: "flex",
    flexDirection: "column",
    gap: 16,
    textAlign: "left",
  },
  field: { display: "flex", flexDirection: "column", gap: 6 },
  label: {
    fontSize: 12,
    fontWeight: 500,
    color: "#7A8090",
    fontFamily: "'DM Sans', sans-serif",
    textTransform: "uppercase",
    letterSpacing: 0.8,
  },
  input: {
    background: "#1E2230",
    border: "1px solid rgba(255,255,255,0.08)",
    borderRadius: 10,
    padding: "12px 14px",
    color: "#F0F2F5",
    fontSize: 14,
    fontFamily: "'DM Sans', sans-serif",
    outline: "none",
    width: "100%",
    boxSizing: "border-box",
  },
  eyeBtn: {
    position: "absolute",
    right: 12,
    top: "50%",
    transform: "translateY(-50%)",
    background: "none",
    border: "none",
    cursor: "pointer",
    fontSize: 16,
    padding: 0,
  },
  error: {
    background: "rgba(255,77,106,0.12)",
    border: "1px solid rgba(255,77,106,0.3)",
    borderRadius: 8,
    padding: "10px 14px",
    color: "#FF4D6A",
    fontSize: 13,
    fontFamily: "'DM Sans', sans-serif",
  },
  btn: {
    background: "#C8F04A",
    color: "#0D0F14",
    border: "none",
    borderRadius: 10,
    padding: "14px",
    fontSize: 14,
    fontWeight: 700,
    fontFamily: "'Syne', sans-serif",
    cursor: "pointer",
    marginTop: 8,
    transition: "opacity 0.15s",
  },
  footer: {
    marginTop: 28,
    fontSize: 11,
    color: "#4A4F60",
    fontFamily: "'DM Sans', sans-serif",
  },
};
