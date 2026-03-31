import { useState, useEffect, useCallback } from "react";
import { onAuthStateChanged, signOut } from "firebase/auth";
import {
  collection, query, orderBy, limit,
  onSnapshot, where, getDocs
} from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { auth, db, functions } from "./firebase";
import Login from "./Login";

// ─── Tokens ─────────────────────────────────
const C = {
  bg:      "#0D0F14",
  surface: "#161920",
  card:    "#1E2230",
  border:  "rgba(255,255,255,0.07)",
  accent:  "#C8F04A",
  accent2: "#4AF0C8",
  red:     "#FF4D6A",
  gold:    "#F5C842",
  text:    "#F0F2F5",
  muted:   "#7A8090",
  dim:     "#4A4F60",
};

const font = { syne: "'Syne', sans-serif", dm: "'DM Sans', sans-serif" };

// ─── Badge ───────────────────────────────────
function Badge({ status }) {
  const map = {
    active:    { bg: "rgba(200,240,74,0.12)",  color: C.accent,  label: "Actif" },
    banned:    { bg: "rgba(255,77,106,0.12)",  color: C.red,     label: "Banni" },
    pending:   { bg: "rgba(245,200,66,0.12)",  color: C.gold,    label: "En attente" },
    published: { bg: "rgba(200,240,74,0.12)",  color: C.accent,  label: "Publié" },
    refused:   { bg: "rgba(255,77,106,0.12)",  color: C.red,     label: "Refusé" },
    accepted:  { bg: "rgba(200,240,74,0.12)",  color: C.accent,  label: "Accepté" },
  };
  const s = map[status] || map.pending;
  return (
    <span style={{ background: s.bg, color: s.color, padding: "3px 10px", borderRadius: 20, fontSize: 11, fontWeight: 600, fontFamily: font.syne, whiteSpace: "nowrap" }}>
      {s.label}
    </span>
  );
}

// ─── Metric Card ─────────────────────────────
function Metric({ label, value, sub, color }) {
  return (
    <div style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 12, padding: "16px 18px" }}>
      <div style={{ fontSize: 11, color: C.muted, fontFamily: font.dm, textTransform: "uppercase", letterSpacing: 0.8, marginBottom: 8 }}>{label}</div>
      <div style={{ fontSize: 28, fontWeight: 700, fontFamily: font.syne, color: color || C.text, lineHeight: 1 }}>{value}</div>
      {sub && <div style={{ fontSize: 12, color: C.dim, marginTop: 6, fontFamily: font.dm }}>{sub}</div>}
    </div>
  );
}

// ─── Table ───────────────────────────────────
function Table({ headers, children }) {
  return (
    <div style={{ overflowX: "auto" }}>
      <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13, fontFamily: font.dm }}>
        <thead>
          <tr style={{ borderBottom: `1px solid ${C.border}` }}>
            {headers.map(h => (
              <th key={h} style={{ padding: "10px 14px", textAlign: "left", fontWeight: 500, color: C.muted, fontSize: 11, textTransform: "uppercase", letterSpacing: 0.6, whiteSpace: "nowrap" }}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>{children}</tbody>
      </table>
    </div>
  );
}

// ─── Btn ─────────────────────────────────────
function Btn({ label, onClick, variant = "default", small }) {
  const styles = {
    default: { border: `1px solid ${C.border}`, color: C.text, background: C.card },
    success: { border: `1px solid ${C.accent}`, color: C.accent, background: "rgba(200,240,74,0.08)" },
    danger:  { border: `1px solid ${C.red}`,    color: C.red,   background: "rgba(255,77,106,0.08)" },
    primary: { border: "none", color: C.bg, background: C.accent },
  };
  return (
    <button onClick={onClick} style={{
      ...styles[variant],
      padding: small ? "4px 10px" : "8px 16px",
      borderRadius: 8,
      fontSize: small ? 11 : 13,
      fontFamily: font.syne,
      fontWeight: 600,
      cursor: "pointer",
      whiteSpace: "nowrap",
      transition: "opacity 0.15s",
    }}>
      {label}
    </button>
  );
}

// ─── Section Title ────────────────────────────
function STitle({ children }) {
  return <h2 style={{ fontFamily: font.syne, fontWeight: 800, fontSize: 20, color: C.text, marginBottom: 4 }}>{children}</h2>;
}

// ══════════════════════════════════════════════
//  DASHBOARD
// ══════════════════════════════════════════════
function Dashboard() {
  const [stats, setStats] = useState({ users: 0, matches: 0, tournaments: 0, pendingTournaments: 0, pendingRegistrations: 0 });

  useEffect(() => {
    const unsubs = [];
    unsubs.push(onSnapshot(collection(db, "users"), s => setStats(p => ({ ...p, users: s.size }))));
    unsubs.push(onSnapshot(collection(db, "matches"), s => setStats(p => ({ ...p, matches: s.size }))));
    unsubs.push(onSnapshot(query(collection(db, "tournaments"), where("status", "==", "pending")), s => setStats(p => ({ ...p, pendingTournaments: s.size }))));
    unsubs.push(onSnapshot(query(collection(db, "tournamentRegistrations"), where("status", "==", "pending")), s => setStats(p => ({ ...p, pendingRegistrations: s.size }))));
    return () => unsubs.forEach(u => u());
  }, []);

  return (
    <div>
      <STitle>Dashboard</STitle>
      <div style={{ fontSize: 13, color: C.muted, fontFamily: font.dm, marginBottom: 24 }}>
        {new Date().toLocaleDateString("fr-FR", { weekday: "long", year: "numeric", month: "long", day: "numeric" })}
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))", gap: 12, marginBottom: 24 }}>
        <Metric label="Utilisateurs" value={stats.users.toLocaleString()} />
        <Metric label="Matchs total" value={stats.matches.toLocaleString()} />
        <Metric label="Tournois en attente" value={stats.pendingTournaments} color={stats.pendingTournaments > 0 ? C.gold : C.text} />
        <Metric label="Inscriptions en attente" value={stats.pendingRegistrations} color={stats.pendingRegistrations > 0 ? C.gold : C.text} />
      </div>
      <div style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 12, padding: 20 }}>
        <div style={{ fontFamily: font.syne, fontWeight: 700, color: C.accent, marginBottom: 8 }}>Bienvenue sur le back-office Zupadel</div>
        <div style={{ fontSize: 13, color: C.muted, fontFamily: font.dm, lineHeight: 1.7 }}>
          Gère les tournois, utilisateurs, inscriptions, coachs et concours depuis ce panneau. Les données sont synchronisées en temps réel avec Firebase.
        </div>
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════
//  USERS
// ══════════════════════════════════════════════
function Users() {
  const [users, setUsers]   = useState([]);
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState(null);
  const [amount, setAmount] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, "users"), orderBy("createdAt", "desc"), limit(100));
    return onSnapshot(q, snap => {
      setUsers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
  }, []);

  const filtered = users.filter(u =>
    (u.pseudo || "").toLowerCase().includes(search.toLowerCase()) ||
    (u.email  || "").toLowerCase().includes(search.toLowerCase())
  );

  const toggleBan = async (u) => {
    const fn = httpsCallable(functions, "adminBanUser");
    await fn({ uid: u.id, ban: u.status !== "banned" });
  };

  const addCredits = async () => {
    if (!selected || !amount) return;
    const fn = httpsCallable(functions, "adminAddCredits");
    await fn({ uid: selected.id, amount: parseInt(amount), description: "Ajout manuel admin" });
    setSelected(null);
    setAmount(0);
  };

  if (loading) return <Loader />;

  return (
    <div>
      <STitle>Utilisateurs</STitle>
      <div style={{ display: "flex", gap: 12, marginBottom: 16, alignItems: "center" }}>
        <input
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Rechercher par pseudo ou email..."
          style={inputStyle}
        />
        <span style={{ fontSize: 12, color: C.muted, fontFamily: font.dm, whiteSpace: "nowrap" }}>{filtered.length} utilisateurs</span>
      </div>

      <div style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 12, overflow: "hidden" }}>
        <Table headers={["Pseudo", "Email", "Ville", "Niv.", "Crédits", "Matchs", "Statut", "Actions"]}>
          {filtered.map(u => (
            <tr key={u.id} style={{ borderBottom: `1px solid ${C.border}` }}>
              <td style={{ padding: "10px 14px", fontWeight: 600, color: C.text, fontFamily: font.syne }}>{u.pseudo || "—"}</td>
              <td style={{ padding: "10px 14px", color: C.muted }}>{u.email}</td>
              <td style={{ padding: "10px 14px", color: C.text }}>{u.city || "—"}</td>
              <td style={{ padding: "10px 14px", color: C.text }}>{u.level || 1}</td>
              <td style={{ padding: "10px 14px", color: C.accent, fontWeight: 700, fontFamily: font.syne }}>{u.credits || 0} ⬡</td>
              <td style={{ padding: "10px 14px", color: C.text }}>{u.matchesPlayed || 0}</td>
              <td style={{ padding: "10px 14px" }}><Badge status={u.status || "active"} /></td>
              <td style={{ padding: "10px 14px" }}>
                <div style={{ display: "flex", gap: 6 }}>
                  <Btn label="+ Crédits" small onClick={() => setSelected(u)} variant="success" />
                  <Btn label={u.status === "banned" ? "Débannir" : "Bannir"} small onClick={() => toggleBan(u)} variant="danger" />
                </div>
              </td>
            </tr>
          ))}
        </Table>
      </div>

      {selected && (
        <div style={{ marginTop: 16, background: C.card, border: `1px solid ${C.accent}`, borderRadius: 12, padding: 20 }}>
          <div style={{ fontFamily: font.syne, fontWeight: 700, marginBottom: 12, color: C.text }}>
            Modifier les crédits de {selected.pseudo} — solde actuel : <span style={{ color: C.accent }}>{selected.credits || 0} ⬡</span>
          </div>
          <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
            <input
              type="number"
              value={amount}
              onChange={e => setAmount(e.target.value)}
              placeholder="Montant"
              style={{ ...inputStyle, width: 120 }}
            />
            <Btn label={`Ajouter ${amount} ⬡`} onClick={addCredits} variant="primary" />
            <Btn label="Annuler" onClick={() => setSelected(null)} />
          </div>
        </div>
      )}
    </div>
  );
}

// ══════════════════════════════════════════════
//  TOURNAMENTS
// ══════════════════════════════════════════════
function Tournaments() {
  const [tournaments, setTournaments] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, "tournaments"), orderBy("createdAt", "desc"));
    return onSnapshot(q, snap => {
      setTournaments(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
  }, []);

  const updateStatus = async (id, status) => {
    const fn = httpsCallable(functions, "adminUpdateTournamentStatus");
    await fn({ tournamentId: id, status });
  };

  if (loading) return <Loader />;

  return (
    <div>
      <STitle>Tournois</STitle>
      <div style={{ fontSize: 13, color: C.muted, fontFamily: font.dm, marginBottom: 20 }}>
        {tournaments.filter(t => t.status === "pending").length} tournoi(s) en attente de validation
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {tournaments.length === 0 && <Empty text="Aucun tournoi créé pour l'instant" />}
        {tournaments.map(t => (
          <div key={t.id} style={{ background: C.card, border: `1px solid ${t.status === "pending" ? C.gold : C.border}`, borderRadius: 12, padding: 16 }}>
            <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 16 }}>
              <div>
                <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 6 }}>
                  <span style={{ fontFamily: font.syne, fontSize: 20, fontWeight: 800, color: C.gold }}>{t.level}</span>
                  <span style={{ fontFamily: font.syne, fontWeight: 700, fontSize: 15, color: C.text }}>{t.title}</span>
                  <Badge status={t.status || "pending"} />
                </div>
                <div style={{ fontSize: 12, color: C.muted, fontFamily: font.dm, display: "flex", gap: 16, flexWrap: "wrap" }}>
                  <span>Organisateur : {t.club || "—"}</span>
                  <span>Date : {t.startDate?.toDate?.()?.toLocaleDateString("fr-FR") || "—"}</span>
                  <span>Inscrits : {(t.registeredIds || []).length}/{t.maxPlayers || "—"}</span>
                  <span>Frais : {t.entryFee === 0 ? "Gratuit" : `${t.entryFee}€`}</span>
                  <span>{t.surface} · {t.category}</span>
                </div>
              </div>
              <div style={{ display: "flex", gap: 8, flexShrink: 0 }}>
                {t.status === "pending" && (
                  <>
                    <Btn label="Valider" onClick={() => updateStatus(t.id, "published")} variant="success" />
                    <Btn label="Refuser" onClick={() => updateStatus(t.id, "refused")} variant="danger" />
                  </>
                )}
                {t.status === "published" && (
                  <Btn label="Dépublier" onClick={() => updateStatus(t.id, "refused")} variant="danger" />
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════
//  REGISTRATIONS
// ══════════════════════════════════════════════
function Registrations() {
  const [regs, setRegs]     = useState([]);
  const [filter, setFilter] = useState("pending");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, "tournamentRegistrations"), orderBy("createdAt", "desc"), limit(200));
    return onSnapshot(q, snap => {
      setRegs(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
  }, []);

  const updateStatus = async (id, status) => {
    const fn = httpsCallable(functions, "adminUpdateRegistrationStatus");
    await fn({ registrationId: id, status });
  };

  const filters = ["pending", "accepted", "refused", "all"];
  const filtered = filter === "all" ? regs : regs.filter(r => r.status === filter);

  if (loading) return <Loader />;

  return (
    <div>
      <STitle>Inscriptions tournois</STitle>
      <div style={{ display: "flex", gap: 8, marginBottom: 16, flexWrap: "wrap" }}>
        {filters.map(f => {
          const count = f === "all" ? regs.length : regs.filter(r => r.status === f).length;
          const active = filter === f;
          return (
            <button key={f} onClick={() => setFilter(f)} style={{
              padding: "6px 14px", borderRadius: 20, fontSize: 12, fontFamily: font.syne, fontWeight: 600,
              cursor: "pointer", border: `1px solid ${active ? C.accent : C.border}`,
              background: active ? "rgba(200,240,74,0.12)" : C.card,
              color: active ? C.accent : C.muted,
            }}>
              {f === "all" ? "Toutes" : f === "pending" ? "En attente" : f === "accepted" ? "Acceptées" : "Refusées"}
              <span style={{ marginLeft: 6, background: C.surface, borderRadius: 10, padding: "1px 6px", fontSize: 10 }}>{count}</span>
            </button>
          );
        })}
      </div>
      <div style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 12, overflow: "hidden" }}>
        <Table headers={["Joueur", "Tournoi", "Licence FFT", "Classement", "Date", "Statut", "Actions"]}>
          {filtered.length === 0 && (
            <tr><td colSpan={7} style={{ padding: 24, textAlign: "center", color: C.muted, fontFamily: font.dm }}>Aucune inscription</td></tr>
          )}
          {filtered.map(r => (
            <tr key={r.id} style={{ borderBottom: `1px solid ${C.border}` }}>
              <td style={{ padding: "10px 14px", fontWeight: 600, color: C.text, fontFamily: font.syne }}>{r.userPseudo || r.userId}</td>
              <td style={{ padding: "10px 14px", color: C.muted }}>{r.tournamentTitle || r.tournamentId}</td>
              <td style={{ padding: "10px 14px", color: C.text }}>{r.fftLicense || "—"}</td>
              <td style={{ padding: "10px 14px", color: C.text }}>{r.fftRank || "—"}</td>
              <td style={{ padding: "10px 14px", color: C.muted }}>{r.createdAt?.toDate?.()?.toLocaleDateString("fr-FR") || "—"}</td>
              <td style={{ padding: "10px 14px" }}><Badge status={r.status || "pending"} /></td>
              <td style={{ padding: "10px 14px" }}>
                {r.status === "pending" && (
                  <div style={{ display: "flex", gap: 6 }}>
                    <Btn label="Accepter" small onClick={() => updateStatus(r.id, "accepted")} variant="success" />
                    <Btn label="Refuser" small onClick={() => updateStatus(r.id, "refused")} variant="danger" />
                  </div>
                )}
              </td>
            </tr>
          ))}
        </Table>
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════
//  COACHES
// ══════════════════════════════════════════════
function Coaches() {
  const [coaches, setCoaches] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, "coaches"), orderBy("avgRating", "desc"));
    return onSnapshot(q, snap => {
      setCoaches(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
  }, []);

  const updateStatus = async (id, status) => {
    const fn = httpsCallable(functions, "adminUpdateCoachStatus");
    await fn({ coachId: id, isActive: status === "active" });
  };

  if (loading) return <Loader />;

  return (
    <div>
      <STitle>Coachs</STitle>
      <div style={{ fontSize: 13, color: C.muted, fontFamily: font.dm, marginBottom: 20 }}>
        {coaches.filter(c => !c.isActive).length} coach(s) en attente de validation
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {coaches.length === 0 && <Empty text="Aucun coach inscrit pour l'instant" />}
        {coaches.map(c => {
          const initials = `${c.firstName?.[0] || ""}${c.lastName?.[0] || ""}`;
          return (
            <div key={c.id} style={{ background: C.card, border: `1px solid ${!c.isActive ? C.gold : C.border}`, borderRadius: 12, padding: 16, display: "flex", alignItems: "center", gap: 16 }}>
              <div style={{ width: 44, height: 44, borderRadius: 22, background: "rgba(200,240,74,0.12)", display: "flex", alignItems: "center", justifyContent: "center", fontFamily: font.syne, fontWeight: 700, fontSize: 14, color: C.accent, flexShrink: 0 }}>
                {initials || "?"}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: font.syne, fontWeight: 700, color: C.text }}>{c.firstName} {c.lastName}</div>
                <div style={{ fontSize: 12, color: C.muted, fontFamily: font.dm, marginTop: 2, display: "flex", gap: 12, flexWrap: "wrap" }}>
                  <span>{c.city}</span>
                  <span>★ {c.avgRating?.toFixed(1) || "N/A"} ({c.ratingCount || 0} avis)</span>
                  <span>{c.hourlyRate}€/h</span>
                  {c.subscribedUntil && <span>Abonnement jusqu'au {c.subscribedUntil?.toDate?.()?.toLocaleDateString("fr-FR")}</span>}
                </div>
              </div>
              <Badge status={c.isActive ? "active" : "pending"} />
              <div style={{ display: "flex", gap: 8 }}>
                {!c.isActive && <Btn label="Valider" onClick={() => updateStatus(c.id, "active")} variant="success" />}
                {c.isActive && <Btn label="Suspendre" onClick={() => updateStatus(c.id, "suspended")} variant="danger" />}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════
//  CONCOURS
// ══════════════════════════════════════════════
function Concours() {
  const [users, setUsers]   = useState([]);
  const [selected, setSelected] = useState("");
  const [amount, setAmount] = useState(10);
  const [reason, setReason] = useState("");
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    onSnapshot(query(collection(db, "users"), limit(100)), s =>
      setUsers(s.docs.map(d => ({ id: d.id, ...d.data() })).filter(u => u.status !== "banned"))
    );
    const q = query(collection(db, "creditTransactions"), where("type", "==", "concours"), orderBy("createdAt", "desc"), limit(20));
    onSnapshot(q, s => setHistory(s.docs.map(d => ({ id: d.id, ...d.data() }))));
  }, []);

  const send = async () => {
    if (!selected || !reason || !amount) return;
    setLoading(true);
    try {
      const fn = httpsCallable(functions, "adminAddCredits");
      await fn({ uid: selected, amount: parseInt(amount), description: reason });
      setSelected("");
      setReason("");
      setAmount(10);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <STitle>Concours & sponsoring</STitle>
      <div style={{ fontSize: 13, color: C.muted, fontFamily: font.dm, marginBottom: 20 }}>Attribue des crédits manuellement aux gagnants de concours.</div>

      <div style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 12, padding: 20, marginBottom: 20 }}>
        <div style={{ fontFamily: font.syne, fontWeight: 700, color: C.text, marginBottom: 16 }}>Attribuer des crédits</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 16 }}>
          <div>
            <label style={labelStyle}>Destinataire</label>
            <select value={selected} onChange={e => setSelected(e.target.value)} style={inputStyle}>
              <option value="">Sélectionner un utilisateur</option>
              {users.map(u => (
                <option key={u.id} value={u.id}>{u.pseudo} — {u.credits || 0} ⬡ actuels</option>
              ))}
            </select>
          </div>
          <div>
            <label style={labelStyle}>Montant : {amount} ⬡ ≈ {(amount * 0.5).toFixed(0)}€</label>
            <input type="range" min="1" max="500" step="1" value={amount} onChange={e => setAmount(parseInt(e.target.value))} style={{ width: "100%", accentColor: C.accent }} />
          </div>
        </div>
        <div style={{ marginBottom: 16 }}>
          <label style={labelStyle}>Raison</label>
          <input value={reason} onChange={e => setReason(e.target.value)} placeholder="Ex: Meilleur joueur du mois, Concours photo padel..." style={inputStyle} />
        </div>
        <Btn label={loading ? "Envoi..." : `Attribuer ${amount} ⬡ →`} onClick={send} variant="primary" />
      </div>

      <div style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 12, overflow: "hidden" }}>
        <div style={{ padding: "14px 16px", borderBottom: `1px solid ${C.border}`, fontFamily: font.syne, fontWeight: 700, color: C.text }}>Historique des attributions</div>
        <Table headers={["Joueur", "Crédits", "Raison", "Date"]}>
          {history.length === 0 && (
            <tr><td colSpan={4} style={{ padding: 20, textAlign: "center", color: C.muted, fontFamily: font.dm }}>Aucune attribution pour l'instant</td></tr>
          )}
          {history.map(h => {
            const user = users.find(u => u.id === h.userId);
            return (
              <tr key={h.id} style={{ borderBottom: `1px solid ${C.border}` }}>
                <td style={{ padding: "10px 14px", fontWeight: 600, color: C.text, fontFamily: font.syne }}>{user?.pseudo || h.userId}</td>
                <td style={{ padding: "10px 14px", color: C.accent, fontWeight: 700, fontFamily: font.syne }}>+{h.amount} ⬡</td>
                <td style={{ padding: "10px 14px", color: C.muted }}>{h.description}</td>
                <td style={{ padding: "10px 14px", color: C.muted }}>{h.createdAt?.toDate?.()?.toLocaleDateString("fr-FR") || "—"}</td>
              </tr>
            );
          })}
        </Table>
      </div>
    </div>
  );
}

// ─── Helpers ─────────────────────────────────
function Loader() {
  return <div style={{ padding: 40, textAlign: "center", color: C.muted, fontFamily: font.dm }}>Chargement...</div>;
}
function Empty({ text }) {
  return <div style={{ padding: 40, textAlign: "center", color: C.muted, fontFamily: font.dm, background: C.card, border: `1px solid ${C.border}`, borderRadius: 12 }}>{text}</div>;
}

const inputStyle = {
  width: "100%",
  padding: "10px 14px",
  background: "#0D0F14",
  border: `1px solid ${C.border}`,
  borderRadius: 8,
  color: C.text,
  fontSize: 13,
  fontFamily: font.dm,
  outline: "none",
  boxSizing: "border-box",
};
const labelStyle = {
  display: "block",
  fontSize: 11,
  color: C.muted,
  fontFamily: font.dm,
  textTransform: "uppercase",
  letterSpacing: 0.8,
  marginBottom: 6,
};

// ══════════════════════════════════════════════
//  MAIN APP
// ══════════════════════════════════════════════
//  TERRAINS
// ══════════════════════════════════════════════
function Terrains() {
  const [clubs, setClubs]       = useState([]);
  const [courts, setCourts]     = useState({});   // { clubId: [court, ...] }
  const [loading, setLoading]   = useState(true);
  const [seeding, setSeeding]   = useState(false);
  const [seedDone, setSeedDone] = useState(false);
  const [seedMsg, setSeedMsg]   = useState("");

  useEffect(() => {
    const q = query(collection(db, "clubs"), orderBy("name"));
    return onSnapshot(q, async snap => {
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setClubs(list);
      // Charger les terrains de chaque club
      const allCourts = {};
      await Promise.all(list.map(async club => {
        const cSnap = await getDocs(collection(db, "clubs", club.id, "courts"));
        allCourts[club.id] = cSnap.docs.map(d => ({ id: d.id, ...d.data() }));
      }));
      setCourts(allCourts);
      setLoading(false);
    });
  }, []);

  const handleSeed = async () => {
    if (!window.confirm("Créer les 4 clubs partenaires par défaut ? (opération non réversible)")) return;
    setSeeding(true);
    setSeedMsg("");
    try {
      const fn = httpsCallable(functions, "seedClubs");
      const result = await fn({});
      setSeedMsg(`✓ ${result.data.clubsCreated} clubs et ${result.data.courtsCreated} terrains créés.`);
      setSeedDone(true);
    } catch (e) {
      setSeedMsg(`Erreur : ${e.message}`);
    } finally {
      setSeeding(false);
    }
  };

  if (loading) return <Loader />;

  return (
    <div>
      <STitle>Clubs partenaires & Terrains</STitle>
      <div style={{ fontSize: 13, color: C.muted, fontFamily: font.dm, marginBottom: 20 }}>
        {clubs.length} club(s) · {Object.values(courts).flat().length} terrain(s) au total
      </div>

      {/* Seed */}
      {clubs.length === 0 && (
        <div style={{ background: C.card, border: `1px solid ${C.gold}`, borderRadius: 12, padding: 20, marginBottom: 24 }}>
          <div style={{ fontFamily: font.syne, fontWeight: 700, color: C.gold, marginBottom: 8 }}>
            ⚠ Aucun club configuré
          </div>
          <div style={{ fontSize: 13, color: C.muted, fontFamily: font.dm, marginBottom: 16 }}>
            Initialise les 4 clubs partenaires parisiens (Padel Station Paris 15, Club Padel Boulogne,
            Padel Indoor Vincennes, Urban Padel Levallois) avec leurs terrains et horaires.
          </div>
          <Btn
            label={seeding ? "Initialisation..." : "Initialiser les clubs partenaires"}
            onClick={handleSeed}
            variant="success"
          />
          {seedMsg && (
            <div style={{ marginTop: 12, fontSize: 13, color: seedDone ? C.accent : C.red, fontFamily: font.dm }}>
              {seedMsg}
            </div>
          )}
        </div>
      )}

      {clubs.length > 0 && (
        <div style={{ marginBottom: 20, display: "flex", alignItems: "center", gap: 12 }}>
          <Btn
            label={seeding ? "Ajout en cours..." : "Ré-initialiser (ajouter les clubs manquants)"}
            onClick={handleSeed}
            variant="default"
            small
          />
          {seedMsg && (
            <span style={{ fontSize: 13, color: seedDone ? C.accent : C.red, fontFamily: font.dm }}>
              {seedMsg}
            </span>
          )}
        </div>
      )}

      {/* Liste des clubs */}
      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {clubs.map(club => {
          const clubCourts = courts[club.id] || [];
          return (
            <div key={club.id} style={{ background: C.card, border: `1px solid ${club.isActive ? C.border : C.red}`, borderRadius: 12, padding: 16 }}>
              <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 16, marginBottom: 12 }}>
                <div>
                  <div style={{ fontFamily: font.syne, fontWeight: 700, color: C.text, fontSize: 15 }}>
                    {club.name}
                  </div>
                  <div style={{ fontSize: 12, color: C.muted, fontFamily: font.dm, marginTop: 3 }}>
                    📍 {club.address}, {club.city}
                    {club.phoneNumber && <span style={{ marginLeft: 12 }}>📞 {club.phoneNumber}</span>}
                  </div>
                </div>
                <div style={{ display: "flex", gap: 8, alignItems: "center", flexShrink: 0 }}>
                  <Badge status={club.isActive ? "active" : "refused"} />
                  <span style={{ fontSize: 12, color: C.accent, fontFamily: font.syne, fontWeight: 700, background: "rgba(200,240,74,0.1)", padding: "3px 10px", borderRadius: 20 }}>
                    {club.pricePerSlotCredits} ⬡ / {club.slotDurationMinutes} min
                  </span>
                </div>
              </div>

              {/* Terrains */}
              <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
                {clubCourts.map(court => (
                  <div key={court.id} style={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 8, padding: "6px 12px", fontSize: 12, fontFamily: font.dm, color: C.text, display: "flex", alignItems: "center", gap: 6 }}>
                    <span>{court.isIndoor ? "🏠" : "☀️"}</span>
                    <span style={{ fontWeight: 600 }}>{court.name}</span>
                    <span style={{ color: C.muted }}>{court.surface}</span>
                    {!court.isActive && <span style={{ color: C.red, fontSize: 10 }}>INACTIF</span>}
                  </div>
                ))}
                {clubCourts.length === 0 && (
                  <span style={{ fontSize: 12, color: C.muted, fontFamily: font.dm }}>Aucun terrain</span>
                )}
              </div>

              {/* Horaires */}
              {club.openingHours && (
                <div style={{ marginTop: 12, display: "flex", flexWrap: "wrap", gap: 8 }}>
                  {["monday","tuesday","wednesday","thursday","friday","saturday","sunday"].map(day => {
                    const h = club.openingHours[day];
                    const labels = { monday: "Lun", tuesday: "Mar", wednesday: "Mer", thursday: "Jeu", friday: "Ven", saturday: "Sam", sunday: "Dim" };
                    return (
                      <div key={day} style={{ fontSize: 11, fontFamily: font.dm, color: h ? C.text : C.dim, background: C.surface, border: `1px solid ${C.border}`, borderRadius: 6, padding: "3px 8px" }}>
                        <span style={{ fontWeight: 600 }}>{labels[day]}</span>
                        {" "}{h || "Fermé"}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}
        {clubs.length === 0 && <Empty text="Aucun club configuré. Utilise le bouton ci-dessus." />}
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════
const NAV = [
  { id: "dashboard",     label: "Dashboard",    icon: "◈" },
  { id: "users",         label: "Utilisateurs", icon: "◉" },
  { id: "tournaments",   label: "Tournois",     icon: "◆" },
  { id: "registrations", label: "Inscriptions", icon: "◇" },
  { id: "coaches",       label: "Coachs",       icon: "◎" },
  { id: "concours",      label: "Concours",     icon: "◐" },
  { id: "terrains",      label: "Terrains",     icon: "⬡" },
];

export default function App() {
  const [user, setUser]       = useState(undefined);
  const [isAdmin, setIsAdmin] = useState(false);
  const [section, setSection] = useState("dashboard");
  const [counts, setCounts]   = useState({});

  useEffect(() => {
    return onAuthStateChanged(auth, async (u) => {
      setUser(u);
      if (u) {
        const tokenResult = await u.getIdTokenResult();
        setIsAdmin(!!tokenResult.claims.admin);
      } else {
        setIsAdmin(false);
      }
    });
  }, []);

  useEffect(() => {
    if (!user || !isAdmin) return;
    const unsubs = [];
    unsubs.push(onSnapshot(query(collection(db, "tournaments"), where("status", "==", "pending")), s => setCounts(p => ({ ...p, tournaments: s.size }))));
    unsubs.push(onSnapshot(query(collection(db, "tournamentRegistrations"), where("status", "==", "pending")), s => setCounts(p => ({ ...p, registrations: s.size }))));
    unsubs.push(onSnapshot(query(collection(db, "coaches"), where("isActive", "==", false)), s => setCounts(p => ({ ...p, coaches: s.size }))));
    return () => unsubs.forEach(u => u());
  }, [user, isAdmin]);

  if (user === undefined) return <div style={{ minHeight: "100vh", background: C.bg, display: "flex", alignItems: "center", justifyContent: "center", color: C.accent, fontFamily: font.syne, fontSize: 20, fontWeight: 800 }}>ZUPADEL</div>;
  if (!user || !isAdmin) return <Login />;

  const SCREENS = { dashboard: Dashboard, users: Users, tournaments: Tournaments, registrations: Registrations, coaches: Coaches, concours: Concours, terrains: Terrains };
  const Screen = SCREENS[section];

  return (
    <>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Syne:wght@400;600;700;800&family=DM+Sans:wght@300;400;500&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { background: ${C.bg}; }
        ::-webkit-scrollbar { width: 4px; } ::-webkit-scrollbar-track { background: ${C.surface}; } ::-webkit-scrollbar-thumb { background: ${C.border}; border-radius: 2px; }
        input:focus, select:focus { border-color: ${C.accent} !important; outline: none; }
      `}</style>
      <div style={{ display: "flex", minHeight: "100vh", fontFamily: font.dm }}>

        {/* Sidebar */}
        <div style={{ width: 240, background: C.surface, borderRight: `1px solid ${C.border}`, display: "flex", flexDirection: "column", flexShrink: 0 }}>
          <div style={{ padding: "28px 20px 20px", borderBottom: `1px solid ${C.border}` }}>
            <div style={{ fontFamily: font.syne, fontSize: 22, fontWeight: 800, color: C.accent, letterSpacing: -0.5 }}>ZUPADEL</div>
            <div style={{ fontSize: 11, color: C.muted, marginTop: 2, textTransform: "uppercase", letterSpacing: 1 }}>Back-office</div>
          </div>

          <nav style={{ flex: 1, padding: "12px 0" }}>
            {NAV.map(item => {
              const count = counts[item.id];
              const active = section === item.id;
              return (
                <button key={item.id} onClick={() => setSection(item.id)} style={{
                  display: "flex", alignItems: "center", justifyContent: "space-between",
                  width: "100%", padding: "11px 20px", border: "none",
                  background: active ? "rgba(200,240,74,0.08)" : "transparent",
                  borderLeft: `2px solid ${active ? C.accent : "transparent"}`,
                  color: active ? C.text : C.muted,
                  fontFamily: font.dm, fontSize: 14, fontWeight: active ? 500 : 400,
                  cursor: "pointer", textAlign: "left",
                  transition: "all 0.15s",
                }}>
                  <span style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    <span style={{ fontSize: 14, color: active ? C.accent : C.dim }}>{item.icon}</span>
                    {item.label}
                  </span>
                  {count > 0 && (
                    <span style={{ background: "rgba(245,200,66,0.2)", color: C.gold, borderRadius: 10, padding: "1px 7px", fontSize: 10, fontFamily: font.syne, fontWeight: 700 }}>
                      {count}
                    </span>
                  )}
                </button>
              );
            })}
          </nav>

          <div style={{ padding: 16, borderTop: `1px solid ${C.border}` }}>
            <div style={{ fontSize: 12, color: C.muted, marginBottom: 8, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{user.email}</div>
            <button onClick={() => signOut(auth)} style={{ width: "100%", padding: "8px", background: "rgba(255,77,106,0.08)", border: `1px solid rgba(255,77,106,0.2)`, borderRadius: 8, color: C.red, fontSize: 12, fontFamily: font.syne, fontWeight: 600, cursor: "pointer" }}>
              Se déconnecter
            </button>
          </div>
        </div>

        {/* Main */}
        <div style={{ flex: 1, overflow: "auto", background: C.bg }}>
          <div style={{ maxWidth: 1200, margin: "0 auto", padding: 32 }}>
            <Screen />
          </div>
        </div>
      </div>
    </>
  );
}
