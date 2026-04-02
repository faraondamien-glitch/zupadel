import { useState, useEffect, useCallback } from "react";
import { onAuthStateChanged, signOut } from "firebase/auth";
import {
  collection, query, orderBy, limit,
  onSnapshot, doc, updateDoc, addDoc,
  serverTimestamp, where, getDocs
} from "firebase/firestore";
import { auth, db } from "./firebase";
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
  const [stats, setStats] = useState({ users: 0, matches: 0, clubs: 0, pendingClubs: 0, pendingTournaments: 0, pendingRegistrations: 0 });

  useEffect(() => {
    const unsubs = [];
    unsubs.push(onSnapshot(collection(db, "users"), s => setStats(p => ({ ...p, users: s.size }))));
    unsubs.push(onSnapshot(collection(db, "matches"), s => setStats(p => ({ ...p, matches: s.size }))));
    unsubs.push(onSnapshot(query(collection(db, "clubs"), where("isActive", "==", true)), s => setStats(p => ({ ...p, clubs: s.size }))));
    unsubs.push(onSnapshot(query(collection(db, "clubApplications"), where("status", "==", "pending")), s => setStats(p => ({ ...p, pendingClubs: s.size }))));
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
        <Metric label="Clubs actifs" value={stats.clubs} sub={stats.pendingClubs > 0 ? `${stats.pendingClubs} en attente` : undefined} color={stats.pendingClubs > 0 ? C.gold : C.text} />
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
    await updateDoc(doc(db, "users", u.id), { status: u.status === "banned" ? "active" : "banned" });
  };

  const addCredits = async () => {
    if (!selected || !amount) return;
    const cur = selected.credits || 0;
    await updateDoc(doc(db, "users", selected.id), { credits: cur + parseInt(amount) });
    await addDoc(collection(db, "creditTransactions"), {
      userId: selected.id,
      type: "concours",
      amount: parseInt(amount),
      balanceBefore: cur,
      balanceAfter: cur + parseInt(amount),
      description: "Ajout manuel admin",
      createdAt: serverTimestamp(),
    });
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
    await updateDoc(doc(db, "tournaments", id), { status });
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
    await updateDoc(doc(db, "tournamentRegistrations", id), { status });
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
    await updateDoc(doc(db, "coaches", id), { isActive: status === "active" });
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
    const user = users.find(u => u.id === selected);
    const cur  = user?.credits || 0;
    try {
      await updateDoc(doc(db, "users", selected), { credits: cur + parseInt(amount) });
      await addDoc(collection(db, "creditTransactions"), {
        userId: selected,
        type: "concours",
        amount: parseInt(amount),
        balanceBefore: cur,
        balanceAfter: cur + parseInt(amount),
        description: reason,
        createdAt: serverTimestamp(),
      });
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

// ══════════════════════════════════════════════
//  CLUBS
// ══════════════════════════════════════════════
const DAYS = [
  { key: "monday",    label: "Lundi" },
  { key: "tuesday",   label: "Mardi" },
  { key: "wednesday", label: "Mercredi" },
  { key: "thursday",  label: "Jeudi" },
  { key: "friday",    label: "Vendredi" },
  { key: "saturday",  label: "Samedi" },
  { key: "sunday",    label: "Dimanche" },
];

function Clubs() {
  const [tab, setTab] = useState("applications");
  const [apps, setApps] = useState([]);
  const [clubs, setClubs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState(null); // clubId en cours d'édition créneaux
  const [slots, setSlots] = useState({}); // { clubId: { monday: "08:00-22:00", ... slotDuration: 90, priceCredits: 5 } }
  const [saving, setSaving] = useState(null);

  useEffect(() => {
    const u1 = onSnapshot(
      query(collection(db, "clubApplications"), orderBy("createdAt", "desc")),
      s => { setApps(s.docs.map(d => ({ id: d.id, ...d.data() }))); setLoading(false); }
    );
    const u2 = onSnapshot(
      query(collection(db, "clubs"), orderBy("name")),
      s => setClubs(s.docs.map(d => ({ id: d.id, ...d.data() })))
    );
    return () => { u1(); u2(); };
  }, []);

  // Accepter une candidature → crée un doc clubs/
  const acceptApp = async (app) => {
    await Promise.all([
      updateDoc(doc(db, "clubApplications", app.id), { status: "accepted", acceptedAt: serverTimestamp() }),
      // Crée le club dans la collection utilisée par l'app Flutter
      addDoc(collection(db, "clubs"), {
        name:                app.name,
        address:             app.address || "",
        city:                app.city || "",
        location:            null,
        phoneNumber:         app.phone || "",
        website:             app.website || "",
        amenities:           [],
        isActive:            true,
        pricePerSlotCredits: 5,
        slotDurationMinutes: 90,
        openingHours:        {},
        applicationId:       app.id,
        contactName:         app.contactName || "",
        contactEmail:        app.contactEmail || "",
        createdAt:           serverTimestamp(),
      }),
    ]);
  };

  const refuseApp = async (id) => {
    await updateDoc(doc(db, "clubApplications", id), { status: "refused" });
  };

  const toggleActive = async (club) => {
    await updateDoc(doc(db, "clubs", club.id), { isActive: !club.isActive });
  };

  // Ouvre le panneau de gestion des créneaux pour un club
  const openSlots = (club) => {
    setExpanded(club.id);
    setSlots(prev => ({
      ...prev,
      [club.id]: {
        slotDuration:  club.slotDurationMinutes || 90,
        priceCredits:  club.pricePerSlotCredits || 5,
        ...Object.fromEntries(DAYS.map(d => [d.key, club.openingHours?.[d.key] || ""])),
      },
    }));
  };

  const saveSlots = async (clubId) => {
    setSaving(clubId);
    const s = slots[clubId];
    const openingHours = Object.fromEntries(
      DAYS.map(d => [d.key, s[d.key] || ""]).filter(([, v]) => v.trim() !== "")
    );
    await updateDoc(doc(db, "clubs", clubId), {
      openingHours,
      slotDurationMinutes: parseInt(s.slotDuration),
      pricePerSlotCredits: parseInt(s.priceCredits),
    });
    setSaving(null);
    setExpanded(null);
  };

  const pendingCount = apps.filter(a => a.status === "pending").length;

  if (loading) return <Loader />;

  return (
    <div>
      <STitle>Clubs partenaires</STitle>

      {/* Sous-onglets */}
      <div style={{ display: "flex", gap: 8, marginBottom: 24, marginTop: 8 }}>
        {[
          { id: "applications", label: "Demandes d'inscription", count: pendingCount },
          { id: "active",       label: "Clubs actifs",            count: null },
        ].map(t => (
          <button key={t.id} onClick={() => setTab(t.id)} style={{
            padding: "8px 18px", borderRadius: 20, fontSize: 13, fontFamily: font.syne, fontWeight: 600,
            cursor: "pointer", border: `1px solid ${tab === t.id ? C.accent : C.border}`,
            background: tab === t.id ? "rgba(200,240,74,0.1)" : C.card,
            color: tab === t.id ? C.accent : C.muted,
            display: "flex", alignItems: "center", gap: 8,
          }}>
            {t.label}
            {t.count > 0 && (
              <span style={{ background: "rgba(245,200,66,0.2)", color: C.gold, borderRadius: 10, padding: "1px 7px", fontSize: 10, fontWeight: 700 }}>
                {t.count}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* ── Onglet Demandes ── */}
      {tab === "applications" && (
        <div>
          <div style={{ fontSize: 13, color: C.muted, fontFamily: font.dm, marginBottom: 16 }}>
            Les clubs qui s'inscrivent via <strong style={{ color: C.text }}>zupadel.fr/clubs/rejoindre</strong> apparaissent ici.
            L'acceptation crée automatiquement le club dans l'app et lui permet de configurer ses créneaux.
          </div>

          {apps.length === 0 && <Empty text="Aucune candidature reçue pour l'instant" />}

          <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            {apps.map(app => (
              <div key={app.id} style={{
                background: C.card,
                border: `1px solid ${app.status === "pending" ? C.gold : C.border}`,
                borderRadius: 12, padding: 20,
              }}>
                <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 16, flexWrap: "wrap" }}>
                  <div style={{ flex: 1, minWidth: 240 }}>
                    {/* Nom + badge */}
                    <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 8 }}>
                      <div style={{ width: 40, height: 40, borderRadius: 10, background: "rgba(200,240,74,0.1)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 18, flexShrink: 0 }}>
                        🏟️
                      </div>
                      <div>
                        <div style={{ fontFamily: font.syne, fontWeight: 700, fontSize: 16, color: C.text }}>{app.name}</div>
                        <div style={{ fontSize: 12, color: C.muted, fontFamily: font.dm }}>{app.address}{app.city ? ` · ${app.city}` : ""}</div>
                      </div>
                      <Badge status={app.status || "pending"} />
                    </div>

                    {/* Infos contact */}
                    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))", gap: "6px 20px", fontSize: 12, fontFamily: font.dm, color: C.muted }}>
                      {app.contactName  && <span>👤 {app.contactName}</span>}
                      {app.contactEmail && <span>✉️ {app.contactEmail}</span>}
                      {app.phone        && <span>📞 {app.phone}</span>}
                      {app.website      && <span>🌐 {app.website}</span>}
                      {app.courts       && <span>🎾 {app.courts} terrain{app.courts > 1 ? "s" : ""}</span>}
                      {app.createdAt    && <span>📅 {app.createdAt?.toDate?.()?.toLocaleDateString("fr-FR") || "—"}</span>}
                    </div>

                    {/* Message de candidature */}
                    {app.message && (
                      <div style={{ marginTop: 10, padding: "10px 14px", background: C.surface, borderRadius: 8, fontSize: 12, color: C.muted, fontFamily: font.dm, fontStyle: "italic", lineHeight: 1.5 }}>
                        "{app.message}"
                      </div>
                    )}
                  </div>

                  {/* Actions */}
                  {app.status === "pending" && (
                    <div style={{ display: "flex", flexDirection: "column", gap: 8, flexShrink: 0 }}>
                      <Btn label="✓ Accepter" onClick={() => acceptApp(app)} variant="success" />
                      <Btn label="✕ Refuser"  onClick={() => refuseApp(app.id)} variant="danger" />
                    </div>
                  )}
                  {app.status === "accepted" && (
                    <div style={{ fontSize: 12, color: C.accent, fontFamily: font.dm, alignSelf: "center" }}>
                      ✓ Club créé dans l'app
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ── Onglet Clubs actifs ── */}
      {tab === "active" && (
        <div>
          <div style={{ fontSize: 13, color: C.muted, fontFamily: font.dm, marginBottom: 16 }}>
            {clubs.length} club{clubs.length !== 1 ? "s" : ""} enregistré{clubs.length !== 1 ? "s" : ""}.
            Configure les créneaux disponibles pour la réservation depuis l'app Zupadel.
          </div>

          {clubs.length === 0 && <Empty text="Aucun club actif. Accepte d'abord une candidature." />}

          <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            {clubs.map(club => (
              <div key={club.id} style={{ background: C.card, border: `1px solid ${club.isActive ? C.border : C.red}`, borderRadius: 12, overflow: "hidden" }}>
                {/* Header club */}
                <div style={{ display: "flex", alignItems: "center", gap: 14, padding: 16 }}>
                  <div style={{ width: 40, height: 40, borderRadius: 10, background: "rgba(200,240,74,0.1)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 18, flexShrink: 0 }}>
                    🏟️
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontFamily: font.syne, fontWeight: 700, color: C.text }}>{club.name}</div>
                    <div style={{ fontSize: 12, color: C.muted, fontFamily: font.dm, marginTop: 2, display: "flex", gap: 12, flexWrap: "wrap" }}>
                      <span>📍 {club.city || club.address || "—"}</span>
                      <span>⏱ Créneaux {club.slotDurationMinutes || 90} min</span>
                      <span>⬡ {club.pricePerSlotCredits || 5} crédits/créneau</span>
                      <span>{Object.keys(club.openingHours || {}).length} jour{Object.keys(club.openingHours || {}).length !== 1 ? "s" : ""} configuré{Object.keys(club.openingHours || {}).length !== 1 ? "s" : ""}</span>
                    </div>
                  </div>
                  <Badge status={club.isActive ? "active" : "refused"} />
                  <div style={{ display: "flex", gap: 8 }}>
                    <Btn
                      label={expanded === club.id ? "Fermer" : "⚙ Créneaux"}
                      onClick={() => expanded === club.id ? setExpanded(null) : openSlots(club)}
                      variant="default"
                      small
                    />
                    <Btn
                      label={club.isActive ? "Désactiver" : "Réactiver"}
                      onClick={() => toggleActive(club)}
                      variant={club.isActive ? "danger" : "success"}
                      small
                    />
                  </div>
                </div>

                {/* Panneau gestion des créneaux */}
                {expanded === club.id && slots[club.id] && (
                  <div style={{ borderTop: `1px solid ${C.border}`, padding: 20, background: C.surface }}>
                    <div style={{ fontFamily: font.syne, fontWeight: 700, color: C.text, marginBottom: 16, fontSize: 14 }}>
                      Configurer les créneaux disponibles
                    </div>

                    {/* Durée et prix */}
                    <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 20 }}>
                      <div>
                        <label style={labelStyle}>Durée d'un créneau (min)</label>
                        <select
                          value={slots[club.id].slotDuration}
                          onChange={e => setSlots(p => ({ ...p, [club.id]: { ...p[club.id], slotDuration: e.target.value } }))}
                          style={inputStyle}
                        >
                          <option value="60">60 min</option>
                          <option value="90">90 min</option>
                          <option value="120">120 min</option>
                        </select>
                      </div>
                      <div>
                        <label style={labelStyle}>Prix par créneau (crédits)</label>
                        <input
                          type="number" min="1" max="50"
                          value={slots[club.id].priceCredits}
                          onChange={e => setSlots(p => ({ ...p, [club.id]: { ...p[club.id], priceCredits: e.target.value } }))}
                          style={inputStyle}
                        />
                      </div>
                    </div>

                    {/* Horaires par jour */}
                    <div style={{ fontFamily: font.dm, fontSize: 12, color: C.muted, marginBottom: 10 }}>
                      Horaires d'ouverture — format <code style={{ background: C.card, padding: "1px 6px", borderRadius: 4, color: C.accent }}>HH:MM-HH:MM</code> · Laisser vide = fermé ce jour-là
                    </div>
                    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 10, marginBottom: 20 }}>
                      {DAYS.map(day => (
                        <div key={day.key}>
                          <label style={labelStyle}>{day.label}</label>
                          <input
                            placeholder="ex: 09:00-22:00"
                            value={slots[club.id][day.key] || ""}
                            onChange={e => setSlots(p => ({ ...p, [club.id]: { ...p[club.id], [day.key]: e.target.value } }))}
                            style={{
                              ...inputStyle,
                              borderColor: slots[club.id][day.key] ? C.accent : C.border,
                            }}
                          />
                        </div>
                      ))}
                    </div>

                    {/* Aperçu nb créneaux */}
                    <div style={{ background: C.card, borderRadius: 8, padding: "10px 14px", marginBottom: 16, fontSize: 12, fontFamily: font.dm, color: C.muted }}>
                      {DAYS.filter(d => slots[club.id][d.key]).map(d => {
                        const val = slots[club.id][d.key];
                        const duration = parseInt(slots[club.id].slotDuration) || 90;
                        const match = val.match(/^(\d{2}):(\d{2})-(\d{2}):(\d{2})$/);
                        if (!match) return <span key={d.key} style={{ color: C.red, marginRight: 12 }}>{d.label}: format invalide</span>;
                        const openMin  = parseInt(match[1]) * 60 + parseInt(match[2]);
                        const closeMin = parseInt(match[3]) * 60 + parseInt(match[4]);
                        const n = Math.floor((closeMin - openMin) / duration);
                        return n > 0
                          ? <span key={d.key} style={{ marginRight: 16 }}><span style={{ color: C.accent, fontWeight: 600 }}>{d.label.slice(0, 3)}</span> {n} créneau{n > 1 ? "x" : ""}</span>
                          : <span key={d.key} style={{ color: C.red, marginRight: 12 }}>{d.label}: 0 créneau</span>;
                      })}
                      {!DAYS.some(d => slots[club.id][d.key]) && "Aucun jour configuré"}
                    </div>

                    <div style={{ display: "flex", gap: 10 }}>
                      <Btn
                        label={saving === club.id ? "Enregistrement..." : "✓ Enregistrer les créneaux"}
                        onClick={() => saveSlots(club.id)}
                        variant="primary"
                      />
                      <Btn label="Annuler" onClick={() => setExpanded(null)} />
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}
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
const NAV = [
  { id: "dashboard",     label: "Dashboard",    icon: "◈" },
  { id: "users",         label: "Utilisateurs", icon: "◉" },
  { id: "clubs",         label: "Clubs",        icon: "🏟" },
  { id: "tournaments",   label: "Tournois",     icon: "◆" },
  { id: "registrations", label: "Inscriptions", icon: "◇" },
  { id: "coaches",       label: "Coachs",       icon: "◎" },
  { id: "concours",      label: "Concours",     icon: "◐" },
];

export default function App() {
  const [user, setUser]       = useState(undefined);
  const [section, setSection] = useState("dashboard");
  const [counts, setCounts]   = useState({});

  useEffect(() => {
    return onAuthStateChanged(auth, u => setUser(u));
  }, []);

  useEffect(() => {
    if (!user) return;
    const unsubs = [];
    unsubs.push(onSnapshot(query(collection(db, "tournaments"), where("status", "==", "pending")), s => setCounts(p => ({ ...p, tournaments: s.size }))));
    unsubs.push(onSnapshot(query(collection(db, "tournamentRegistrations"), where("status", "==", "pending")), s => setCounts(p => ({ ...p, registrations: s.size }))));
    unsubs.push(onSnapshot(query(collection(db, "coaches"), where("isActive", "==", false)), s => setCounts(p => ({ ...p, coaches: s.size }))));
    unsubs.push(onSnapshot(query(collection(db, "clubApplications"), where("status", "==", "pending")), s => setCounts(p => ({ ...p, clubs: s.size }))));
    return () => unsubs.forEach(u => u());
  }, [user]);

  if (user === undefined) return <div style={{ minHeight: "100vh", background: C.bg, display: "flex", alignItems: "center", justifyContent: "center", color: C.accent, fontFamily: font.syne, fontSize: 20, fontWeight: 800 }}>ZUPADEL</div>;
  if (!user) return <Login />;

  const SCREENS = { dashboard: Dashboard, users: Users, clubs: Clubs, tournaments: Tournaments, registrations: Registrations, coaches: Coaches, concours: Concours };
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
