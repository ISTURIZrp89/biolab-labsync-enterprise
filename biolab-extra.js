
// ── BioLab Extra Features v6.4 ─────────────────────────────────────
// CalendarTab, ReportsTab, SettingsTab, new BioLabApp mount

// ── Persistent Config Helpers ───────────────────────────────────────
const getConfig = (key, fallback) => {
  try { const v = localStorage.getItem(key); return v !== null ? JSON.parse(v) : fallback; } catch { return fallback; }
};
const setConfig = (key, val) => { try { localStorage.setItem(key, JSON.stringify(val)); } catch {} };

// Default equipment lists (can be overridden in Settings)
let EQUIPOS_INCUBADORAS  = getConfig("biolab-eq-incubadoras",  ["SANYO", "HERACELL", "STERI-CULT"]);
let EQUIPOS_ULTRACRYO    = getConfig("biolab-eq-ultracryo",    ["THERMOFISHER", "REVCO", "SANYO -80°C"]);
let EQUIPOS_AUTOCLAVES   = getConfig("biolab-eq-autoclaves",   ["Autoclave 1"]);
let MODULOS_ACTIVOS      = getConfig("biolab-modulos-activos", null); // null = todos activos
let LAB_CONFIG           = getConfig("biolab-lab-config", {
  nombre: "Laboratorio de Cultivo Celular",
  institucion: "IMMUNOTHERAPY",
  carpeta: "C:\\Users\\HP\\Documents\\BioLab_Reportes",
  diasLaborales: [1,2,3,4,5], // Mon-Fri
});

// Save to local folder via server API
async function saveFileToFolder(folder, filename, contentBase64) {
  try {
    const r = await fetch("/api/save-file", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ path: folder, filename, contentBase64 }),
    });
    const data = await r.json();
    return data;
  } catch (e) {
    return { success: false, error: e.message };
  }
}

// Convert string to base64
function strToBase64(str) {
  const bytes = new TextEncoder().encode(str);
  let binary = "";
  bytes.forEach(b => binary += String.fromCharCode(b));
  return btoa(binary);
}

// Format date for filenames
const fmtDate = (d) => d ? d.replace(/-/g, "") : "";
const monthName = (m) => ["Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"][m];

// ── Status Bar Component ─────────────────────────────────────────────
function StatusBar({ entries }) {
  const todayStr = new Date().toISOString().slice(0, 10);
  const hasTodayBitacora = entries.some(e => e.module === "bitacora" && e.date === todayStr);
  const thisMonth = todayStr.slice(0, 7);
  const daysThisMonth = entries.filter(e => e.module === "bitacora" && e.date?.startsWith(thisMonth))
    .map(e => e.date).filter((d, i, a) => a.indexOf(d) === i).length;

  // Count weekdays in current month so far
  const now = new Date();
  let weekdays = 0;
  for (let d = 1; d <= now.getDate(); d++) {
    const day = new Date(now.getFullYear(), now.getMonth(), d).getDay();
    if (day >= 1 && day <= 5) weekdays++;
  }
  const pct = weekdays > 0 ? Math.round((daysThisMonth / weekdays) * 100) : 0;

  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 12, padding: "4px 16px",
      background: C.surf, borderBottom: `1px solid ${C.border}`, fontSize: 11, fontFamily: "monospace",
    }}>
      <span style={{ color: hasTodayBitacora ? C.primary : C.danger, fontWeight: 700 }}>
        {hasTodayBitacora ? "✓ Hoy al día" : "⚠ Falta bitácora hoy"}
      </span>
      <span style={{ color: C.muted }}>|</span>
      <span style={{ color: C.muted }}>
        Mes: <span style={{ color: pct >= 80 ? C.primary : pct >= 50 ? C.amber : C.danger, fontWeight: 700 }}>{daysThisMonth}/{weekdays} días ({pct}%)</span>
      </span>
      <span style={{ color: C.muted }}>|</span>
      <span style={{ color: C.muted }}>Total registros: <b style={{ color: C.text }}>{entries.length}</b></span>
    </div>
  );
}

// ── Calendar Tab ─────────────────────────────────────────────────────
function CalendarTab({ entries, onSelectDay }) {
  const [viewDate, setViewDate] = React.useState(new Date());

  const year = viewDate.getFullYear();
  const month = viewDate.getMonth();
  const firstDay = new Date(year, month, 1).getDay(); // 0=Sun
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const today = new Date().toISOString().slice(0, 10);

  // Build map: date -> { module: count }
  const dayMap = {};
  entries.forEach(e => {
    if (!e.date || !e.date.startsWith(`${year}-${String(month+1).padStart(2,"0")}`)) return;
    if (!dayMap[e.date]) dayMap[e.date] = {};
    dayMap[e.date][e.module] = (dayMap[e.date][e.module] || 0) + 1;
  });

  const modColors = {};
  MODULES.forEach(m => { modColors[m.id] = m.color; });

  const prevMonth = () => setViewDate(new Date(year, month - 1, 1));
  const nextMonth = () => setViewDate(new Date(year, month + 1, 1));

  const days = [];
  const startPad = firstDay === 0 ? 6 : firstDay - 1; // Mon-start
  for (let i = 0; i < startPad; i++) days.push(null);
  for (let d = 1; d <= daysInMonth; d++) days.push(d);

  const dayStr = (d) => `${year}-${String(month+1).padStart(2,"0")}-${String(d).padStart(2,"0")}`;

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      {/* Header */}
      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
        <button onClick={prevMonth} style={{ background: C.surf2, border: `1px solid ${C.border}`, color: C.text, borderRadius: 4, padding: "6px 12px", cursor: "pointer", fontFamily: "monospace" }}>◀</button>
        <h2 style={{ flex: 1, textAlign: "center", margin: 0, fontFamily: "monospace", color: C.primary, letterSpacing: 2 }}>
          {monthName(month).toUpperCase()} {year}
        </h2>
        <button onClick={nextMonth} style={{ background: C.surf2, border: `1px solid ${C.border}`, color: C.text, borderRadius: 4, padding: "6px 12px", cursor: "pointer", fontFamily: "monospace" }}>▶</button>
      </div>

      {/* Module legend */}
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        {MODULES.map(m => (
          <span key={m.id} style={{ display: "flex", alignItems: "center", gap: 4, fontSize: 10, fontFamily: "monospace", color: C.muted }}>
            <span style={{ width: 8, height: 8, borderRadius: "50%", background: m.color, display: "inline-block" }} />
            {m.label}
          </span>
        ))}
      </div>

      {/* Day headers */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(7,1fr)", gap: 4 }}>
        {["Lun","Mar","Mié","Jue","Vie","Sáb","Dom"].map(d => (
          <div key={d} style={{ textAlign: "center", fontSize: 10, color: C.muted, fontFamily: "monospace", padding: "4px 0", fontWeight: 700 }}>{d}</div>
        ))}
        {days.map((d, i) => {
          if (!d) return <div key={`e${i}`} />;
          const ds = dayStr(d);
          const mods = dayMap[ds] || {};
          const hasMods = Object.keys(mods).length > 0;
          const isToday = ds === today;
          const isFuture = ds > today;
          const isWeekend = [6, 0].includes(new Date(year, month, d).getDay());

          return (
            <div
              key={d}
              onClick={() => !isFuture && onSelectDay(ds)}
              style={{
                minHeight: 64, padding: 6, borderRadius: 6, cursor: isFuture ? "default" : "pointer",
                background: isToday ? C.surf3 : C.surf2,
                border: `1px solid ${isToday ? C.primary : hasMods ? C.border2 : C.border}`,
                opacity: isFuture ? 0.4 : 1,
                transition: "all 0.15s",
              }}
            >
              <div style={{ fontSize: 11, fontFamily: "monospace", color: isToday ? C.primary : isWeekend ? C.muted : C.text, fontWeight: isToday ? 700 : 400, marginBottom: 4 }}>{d}</div>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 2 }}>
                {MODULES.map(m => mods[m.id] ? (
                  <span key={m.id} title={`${m.label}: ${mods[m.id]} entrada(s)`}
                    style={{ width: 8, height: 8, borderRadius: "50%", background: m.color, display: "inline-block" }}
                  />
                ) : null)}
              </div>
              {!hasMods && !isFuture && !isWeekend && (
                <div style={{ fontSize: 8, color: C.danger, fontFamily: "monospace", marginTop: 2 }}>falta</div>
              )}
            </div>
          );
        })}
      </div>

      {/* Summary */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4,1fr)", gap: 8 }}>
        {MODULES.map(m => {
          const count = entries.filter(e => e.module === m.id && e.date?.startsWith(`${year}-${String(month+1).padStart(2,"0")}`)).length;
          return (
            <div key={m.id} style={{ background: C.surf2, border: `1px solid ${C.border}`, borderRadius: 6, padding: "8px 12px" }}>
              <div style={{ fontSize: 10, color: m.color, fontFamily: "monospace", fontWeight: 700 }}>{m.icon} {m.label}</div>
              <div style={{ fontSize: 18, fontFamily: "monospace", color: C.text, fontWeight: 700 }}>{count}</div>
              <div style={{ fontSize: 9, color: C.muted, fontFamily: "monospace" }}>registros este mes</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── Reports Tab ──────────────────────────────────────────────────────
function ReportsTab({ entries, showToast }) {
  const [dateFrom, setDateFrom] = React.useState(new Date().toISOString().slice(0,7) + "-01");
  const [dateTo, setDateTo] = React.useState(new Date().toISOString().slice(0,10));
  const [saving, setSaving] = React.useState(false);
  const cfg = getConfig("biolab-lab-config", { carpeta: "C:\\Users\\HP\\Documents\\BioLab_Reportes", nombre: "Laboratorio" });

  const filtered = entries.filter(e => e.date >= dateFrom && e.date <= dateTo);
  const modGroups = {};
  MODULES.forEach(m => { modGroups[m.id] = filtered.filter(e => e.module === m.id); });

  // Generate Word (.doc HTML) content for a group of entries
  const buildWordContent = (title, ents) => {
    const rows = ents.map(e => `<tr><td>${e.date}</td><td>${e.title}</td><td style="white-space:pre-wrap;font-size:10px">${(e.content||"").substring(0,500)}</td></tr>`).join("");
    return `<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">
<head><meta charset="utf-8"><title>${title}</title>
<style>body{font-family:Arial,sans-serif;font-size:11pt}h1{font-size:14pt;color:#003366}h2{font-size:12pt}table{border-collapse:collapse;width:100%}th{background:#003366;color:white;padding:6px;text-align:left}td{border:1px solid #ccc;padding:5px;vertical-align:top}</style>
</head><body>
<h1>${cfg.nombre || "BioLab"}</h1><h2>${title}</h2><p>Período: ${dateFrom} al ${dateTo} | Total: ${ents.length} registros</p>
<table><tr><th>Fecha</th><th>Título</th><th>Contenido</th></tr>${rows}</table>
</body></html>`;
  };

  // Generate Excel workbook with SheetJS
  const buildExcelWorkbook = (selectedMods) => {
    const wb = XLSX.utils.book_new();
    // Summary sheet
    const summaryData = [["Módulo","Registros","Fechas cubiertas"]];
    selectedMods.forEach(m => {
      const ents = modGroups[m.id] || [];
      const dates = [...new Set(ents.map(e => e.date))].sort();
      summaryData.push([m.label, ents.length, dates.join(", ")]);
    });
    XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(summaryData), "Resumen");

    // Sheet per module
    selectedMods.forEach(m => {
      const ents = modGroups[m.id] || [];
      if (!ents.length) return;
      const wsData = [["Fecha","Título","Guardado","Contenido"]];
      ents.forEach(e => wsData.push([e.date, e.title, e.savedAt?.slice(0,16)||"", e.content||""]));
      XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(wsData), m.label.substring(0,31));
    });
    return wb;
  };

  const exportGlobal = async (fmt) => {
    const allMods = MODULES.filter(m => filtered.some(e => e.module === m.id));
    if (!allMods.length) { showToast("Sin datos en el rango seleccionado", "error"); return; }
    const tag = `${fmtDate(dateFrom)}_${fmtDate(dateTo)}`;
    const subfolder = `${cfg.carpeta}\\${new Date(dateFrom).getFullYear()}\\${String(new Date(dateFrom).getMonth()+1).padStart(2,"0")}_${monthName(new Date(dateFrom).getMonth())}`;

    setSaving(true);
    if (fmt === "xlsx") {
      const wb = buildExcelWorkbook(allMods);
      const wbout = XLSX.write(wb, { bookType: "xlsx", type: "base64" });
      const res = await saveFileToFolder(subfolder, `BioLab_Global_${tag}.xlsx`, wbout);
      showToast(res.success ? `Guardado: ${res.savedTo}` : `Error: ${res.error}`, res.success ? "success" : "error");
      // Also trigger download
      const link = document.createElement("a");
      link.href = `data:application/octet-stream;base64,${wbout}`;
      link.download = `BioLab_Global_${tag}.xlsx`; link.click();
    } else {
      const content = allMods.map(m => `\n${"=".repeat(60)}\n${m.icon} ${m.label}\n${"=".repeat(60)}\n` + (modGroups[m.id]||[]).map(e => e.content).join("\n---\n")).join("\n");
      const wordHtml = buildWordContent(`Reporte Global BioLab`, filtered);
      const b64 = strToBase64(wordHtml);
      const res = await saveFileToFolder(subfolder, `BioLab_Global_${tag}.doc`, b64);
      showToast(res.success ? `Guardado: ${res.savedTo}` : `Error: ${res.error}`, res.success ? "success" : "error");
      const link = document.createElement("a");
      link.href = `data:application/msword;base64,${b64}`;
      link.download = `BioLab_Global_${tag}.doc`; link.click();
    }
    setSaving(false);
  };

  const exportSection = async (mod, fmt) => {
    const ents = modGroups[mod.id] || [];
    if (!ents.length) { showToast(`Sin datos para ${mod.label}`, "error"); return; }
    const tag = `${fmtDate(dateFrom)}_${fmtDate(dateTo)}`;
    const subfolder = `${cfg.carpeta}\\${new Date(dateFrom).getFullYear()}\\${String(new Date(dateFrom).getMonth()+1).padStart(2,"0")}_${monthName(new Date(dateFrom).getMonth())}\\Secciones`;
    setSaving(true);
    if (fmt === "xlsx") {
      const wb = XLSX.utils.book_new();
      const wsData = [["Fecha","Título","Guardado","Contenido"]];
      ents.forEach(e => wsData.push([e.date, e.title, e.savedAt?.slice(0,16)||"", e.content||""]));
      XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(wsData), mod.label.substring(0,31));
      const wbout = XLSX.write(wb, { bookType: "xlsx", type: "base64" });
      const res = await saveFileToFolder(subfolder, `${mod.label.replace(/\s+/g,"_")}_${tag}.xlsx`, wbout);
      showToast(res.success ? `Guardado: ${res.savedTo}` : `Error: ${res.error}`, res.success ? "success" : "error");
      const link = document.createElement("a"); link.href = `data:application/octet-stream;base64,${wbout}`; link.download = `${mod.label}_${tag}.xlsx`; link.click();
    } else {
      const wordHtml = buildWordContent(`${mod.icon} ${mod.label} — ${mod.label}`, ents);
      const b64 = strToBase64(wordHtml);
      const res = await saveFileToFolder(subfolder, `${mod.label.replace(/\s+/g,"_")}_${tag}.doc`, b64);
      showToast(res.success ? `Guardado: ${res.savedTo}` : `Error: ${res.error}`, res.success ? "success" : "error");
      const link = document.createElement("a"); link.href = `data:application/msword;base64,${b64}`; link.download = `${mod.label}_${tag}.doc`; link.click();
    }
    setSaving(false);
  };

  const btnS = { fontSize: 11, padding: "5px 10px", marginLeft: 4 };

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
      {/* Date range */}
      <div style={{ background: C.surf2, border: `1px solid ${C.border}`, borderRadius: 8, padding: 16 }}>
        <div style={{ fontSize: 11, color: C.muted, fontFamily: "monospace", marginBottom: 10, letterSpacing: 1 }}>PERÍODO DEL REPORTE</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr auto", gap: 10, alignItems: "end" }}>
          <div>
            <label style={{ fontSize: 10, color: C.muted, display: "block", marginBottom: 3 }}>DESDE</label>
            <input type="date" value={dateFrom} onChange={e => setDateFrom(e.target.value)} style={{ ...inp(false), width: "100%" }} />
          </div>
          <div>
            <label style={{ fontSize: 10, color: C.muted, display: "block", marginBottom: 3 }}>HASTA</label>
            <input type="date" value={dateTo} onChange={e => setDateTo(e.target.value)} style={{ ...inp(false), width: "100%" }} />
          </div>
          <div style={{ color: C.muted, fontFamily: "monospace", fontSize: 12, paddingBottom: 4 }}>
            {filtered.length} registros
          </div>
        </div>
        <div style={{ marginTop: 8, fontSize: 10, color: C.muted, fontFamily: "monospace" }}>
          Carpeta destino: <span style={{ color: C.text }}>{cfg.carpeta}</span>
          <span style={{ color: C.muted }}> → se organiza por año/mes automáticamente</span>
        </div>
      </div>

      {/* Global export */}
      <div style={{ background: C.surf2, border: `1px solid ${C.border2}`, borderRadius: 8, padding: 16 }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 8 }}>
          <div>
            <div style={{ fontFamily: "monospace", fontSize: 13, color: C.text, fontWeight: 700 }}>📊 Reporte Global</div>
            <div style={{ fontSize: 11, color: C.muted, fontFamily: "monospace" }}>Todos los módulos en un solo archivo</div>
          </div>
          <div>
            <Btn onClick={() => exportGlobal("xlsx")} color={C.primary} disabled={saving} style={btnS}>⬇ Excel (.xlsx)</Btn>
            <Btn onClick={() => exportGlobal("doc")} color={C.blue} disabled={saving} style={btnS}>⬇ Word (.doc)</Btn>
          </div>
        </div>
      </div>

      {/* Per-section exports */}
      <div style={{ fontSize: 11, color: C.muted, fontFamily: "monospace", letterSpacing: 1 }}>REPORTES POR SECCIÓN</div>
      {MODULES.map(m => {
        const count = (modGroups[m.id] || []).length;
        return (
          <div key={m.id} style={{ background: C.surf2, border: `1px solid ${C.border}`, borderRadius: 6, padding: "10px 14px", display: "flex", alignItems: "center" }}>
            <span style={{ fontSize: 16, marginRight: 8 }}>{m.icon}</span>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: "monospace", fontSize: 12, color: count > 0 ? C.text : C.muted }}>{m.label}</div>
              <div style={{ fontSize: 10, color: C.muted, fontFamily: "monospace" }}>{count} registro(s) en el período</div>
            </div>
            {count > 0 ? (
              <div>
                <Btn onClick={() => exportSection(m, "xlsx")} color={m.color} disabled={saving} style={btnS}>Excel</Btn>
                <Btn onClick={() => exportSection(m, "doc")} color={C.blue} disabled={saving} style={btnS}>Word</Btn>
              </div>
            ) : <span style={{ fontSize: 10, color: C.dim, fontFamily: "monospace" }}>sin datos</span>}
          </div>
        );
      })}
    </div>
  );
}

// ── Settings Tab ─────────────────────────────────────────────────────
function SettingsTab({ showToast, onConfigChange }) {
  const [tab, setTab] = React.useState("general");
  const [cfg, setCfg] = React.useState(getConfig("biolab-lab-config", {
    nombre: "Laboratorio de Cultivo Celular", institucion: "IMMUNOTHERAPY",
    carpeta: "C:\\Users\\HP\\Documents\\BioLab_Reportes", diasLaborales: [1,2,3,4,5],
  }));
  const [portada, setPortada] = React.useState(getConfig("biolab-portada", "BIOLAB — LABORATORIO DE CULTIVO CELULAR\nIMPORTED: IMMUNOTHERAPY"));
  const [personal, setPersonal] = React.useState(getConfig("biolab-personal-custom", PERSONAL));
  const [newUser, setNewUser] = React.useState({ nombre:"", cargo:"TÉCNICO" });
  const [eqInc, setEqInc]   = React.useState(getConfig("biolab-eq-incubadoras", ["SANYO","HERACELL","STERI-CULT"]));
  const [eqCryo, setEqCryo] = React.useState(getConfig("biolab-eq-ultracryo", ["THERMOFISHER","REVCO","SANYO -80°C"]));
  const [newEq, setNewEq]   = React.useState({ type: "incubadoras", nombre: "" });

  const saveCfg = () => { setConfig("biolab-lab-config", cfg); LAB_CONFIG = cfg; showToast("Configuración guardada", "success"); onConfigChange && onConfigChange(); };
  const savePortada = () => { setConfig("biolab-portada", portada); showToast("Portada guardada", "success"); };
  const savePersonal = () => { setConfig("biolab-personal-custom", personal); showToast("Personal guardado — reinicia el formulario para ver cambios", "success"); };
  const saveEquipos = () => {
    setConfig("biolab-eq-incubadoras", eqInc);
    setConfig("biolab-eq-ultracryo", eqCryo);
    EQUIPOS_INCUBADORAS = eqInc; EQUIPOS_ULTRACRYO = eqCryo;
    showToast("Equipos guardados", "success");
  };

  const addUser = () => {
    if (!newUser.nombre.trim()) return;
    setPersonal(p => [...p, `${newUser.cargo}. ${newUser.nombre.trim()}`]);
    setNewUser({ nombre: "", cargo: "TÉCNICO" });
  };
  const removeUser = (i) => setPersonal(p => p.filter((_, idx) => idx !== i));

  const addEquipo = () => {
    if (!newEq.nombre.trim()) return;
    if (newEq.type === "incubadoras") setEqInc(p => [...p, newEq.nombre.trim()]);
    else setEqCryo(p => [...p, newEq.nombre.trim()]);
    setNewEq(p => ({ ...p, nombre: "" }));
  };

  const tabBtnStyle = (id) => ({
    background: tab === id ? C.surf3 : "none",
    border: `1px solid ${tab === id ? C.border2 : "transparent"}`,
    borderRadius: 4, padding: "6px 14px", color: tab === id ? C.text : C.muted,
    cursor: "pointer", fontSize: 12, fontFamily: "monospace", marginRight: 4,
  });

  const sInp = { ...inp(false), marginBottom: 0 };

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      {/* Tab bar */}
      <div style={{ display: "flex", flexWrap: "wrap", gap: 4, borderBottom: `1px solid ${C.border}`, paddingBottom: 10 }}>
        {[["general","⚙ General"],["portada","📄 Portada"],["personal","👥 Personal"],["equipos","🔬 Equipos"]].map(([id,lbl]) => (
          <button key={id} onClick={() => setTab(id)} style={tabBtnStyle(id)}>{lbl}</button>
        ))}
      </div>

      {/* GENERAL */}
      {tab === "general" && (
        <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            <div>
              <label style={{ fontSize: 10, color: C.muted, display: "block", marginBottom: 3 }}>NOMBRE DEL LABORATORIO</label>
              <input value={cfg.nombre} onChange={e => setCfg(p => ({...p, nombre: e.target.value}))} style={sInp} />
            </div>
            <div>
              <label style={{ fontSize: 10, color: C.muted, display: "block", marginBottom: 3 }}>INSTITUCIÓN</label>
              <input value={cfg.institucion} onChange={e => setCfg(p => ({...p, institucion: e.target.value}))} style={sInp} />
            </div>
          </div>
          <div>
            <label style={{ fontSize: 10, color: C.muted, display: "block", marginBottom: 3 }}>📁 CARPETA DE REPORTES (ruta en tu PC)</label>
            <input value={cfg.carpeta} onChange={e => setCfg(p => ({...p, carpeta: e.target.value}))}
              placeholder="Ej: C:\Users\HP\Google Drive\BioLab_Reportes" style={sInp} />
            <div style={{ fontSize: 10, color: C.muted, marginTop: 4, fontFamily: "monospace" }}>
              Los reportes se guardan como: {cfg.carpeta}\{new Date().getFullYear()}\{String(new Date().getMonth()+1).padStart(2,"0")}_{monthName(new Date().getMonth())}\
            </div>
          </div>
          <Btn onClick={saveCfg} color={C.primary} style={{ alignSelf: "flex-start", padding: "8px 20px" }}>Guardar configuración general</Btn>
        </div>
      )}

      {/* PORTADA */}
      {tab === "portada" && (
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <div style={{ fontSize: 11, color: C.muted, fontFamily: "monospace" }}>
            Este texto aparece al inicio de cada reporte exportado (Word/Excel).
          </div>
          <textarea value={portada} onChange={e => setPortada(e.target.value)} rows={10}
            placeholder="BIOLAB — LABORATORIO&#10;Dr. Alberto Parra Barrera&#10;..." style={{ ...sInp, resize: "vertical", lineHeight: 1.8 }} />
          <div style={{ background: C.surf3, border: `1px solid ${C.border}`, borderRadius: 6, padding: 12, fontFamily: "monospace", fontSize: 11, color: C.text, whiteSpace: "pre-wrap" }}>
            {portada || "(vacío)"}
          </div>
          <Btn onClick={savePortada} color={C.primary} style={{ alignSelf: "flex-start", padding: "8px 20px" }}>Guardar portada</Btn>
        </div>
      )}

      {/* PERSONAL */}
      {tab === "personal" && (
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <div style={{ display: "flex", gap: 8, alignItems: "flex-end" }}>
            <div style={{ flex: 1 }}>
              <label style={{ fontSize: 10, color: C.muted, display: "block", marginBottom: 3 }}>NOMBRE COMPLETO</label>
              <input value={newUser.nombre} onChange={e => setNewUser(p=>({...p,nombre:e.target.value}))}
                placeholder="Ej: María López García" style={sInp} onKeyDown={e => e.key==="Enter" && addUser()} />
            </div>
            <div style={{ width: 160 }}>
              <label style={{ fontSize: 10, color: C.muted, display: "block", marginBottom: 3 }}>CARGO</label>
              <select value={newUser.cargo} onChange={e => setNewUser(p=>({...p,cargo:e.target.value}))} style={{ ...sInp, cursor: "pointer" }}>
                {["Dr.","Dra.","Biol.","Biól.","QFB.","TÉCNICO","Ing.","Lic."].map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>
            <Btn onClick={addUser} color={C.primary}>+ Agregar</Btn>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
            {personal.map((u, i) => (
              <div key={i} style={{ display: "flex", alignItems: "center", background: C.surf2, border: `1px solid ${C.border}`, borderRadius: 4, padding: "8px 12px" }}>
                <span style={{ flex: 1, fontFamily: "monospace", fontSize: 12, color: C.text }}>{u}</span>
                <button onClick={() => removeUser(i)} style={{ background: "none", border: "none", color: C.danger, cursor: "pointer", fontSize: 14 }}>✕</button>
              </div>
            ))}
          </div>
          <Btn onClick={savePersonal} color={C.primary} style={{ alignSelf: "flex-start", padding: "8px 20px" }}>Guardar personal</Btn>
        </div>
      )}

      {/* EQUIPOS */}
      {tab === "equipos" && (
        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <div style={{ display: "flex", gap: 8, alignItems: "flex-end" }}>
            <div style={{ width: 160 }}>
              <label style={{ fontSize: 10, color: C.muted, display: "block", marginBottom: 3 }}>TIPO</label>
              <select value={newEq.type} onChange={e => setNewEq(p=>({...p,type:e.target.value}))} style={{ ...sInp, cursor: "pointer" }}>
                <option value="incubadoras">Incubadoras</option>
                <option value="ultracryo">Ultracongeladores</option>
              </select>
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ fontSize: 10, color: C.muted, display: "block", marginBottom: 3 }}>MODELO / NOMBRE</label>
              <input value={newEq.nombre} onChange={e => setNewEq(p=>({...p,nombre:e.target.value}))}
                placeholder="Ej: HERACELL 240i" style={sInp} onKeyDown={e => e.key==="Enter" && addEquipo()} />
            </div>
            <Btn onClick={addEquipo} color={C.blue}>+ Agregar</Btn>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            {[["🌡️ Incubadoras", eqInc, setEqInc], ["🧊 Ultracongeladores", eqCryo, setEqCryo]].map(([title, list, setList]) => (
              <div key={title} style={{ background: C.surf2, border: `1px solid ${C.border}`, borderRadius: 6, padding: 12 }}>
                <div style={{ fontFamily: "monospace", fontSize: 11, color: C.muted, marginBottom: 8 }}>{title}</div>
                {list.map((eq, i) => (
                  <div key={i} style={{ display: "flex", alignItems: "center", padding: "4px 0", borderBottom: `1px solid ${C.border}` }}>
                    <span style={{ flex: 1, fontFamily: "monospace", fontSize: 12, color: C.text }}>{eq}</span>
                    <button onClick={() => setList(p => p.filter((_,idx)=>idx!==i))} style={{ background:"none", border:"none", color:C.danger, cursor:"pointer", fontSize:13 }}>✕</button>
                  </div>
                ))}
              </div>
            ))}
          </div>
          <Btn onClick={saveEquipos} color={C.primary} style={{ alignSelf: "flex-start", padding: "8px 20px" }}>Guardar equipos</Btn>
        </div>
      )}
    </div>
  );
}

// ── Main BioLab App (v6.4) ────────────────────────────────────────────
function BioLabApp() {
  const [activeModule, setActiveModule] = React.useState("bitacora");
  const [activeTab, setActiveTab] = React.useState("form");
  const [entries, setEntries] = React.useState([]);
  const [preview, setPreview] = React.useState(null);
  const [storageReady, setStorageReady] = React.useState(false);
  const [globalUser, setGlobalUser] = React.useState(getConfig("biolab-last-user",""));
  const [editingEntry, setEditingEntry] = React.useState(null);
  const [calendarDay, setCalendarDay] = React.useState(null);
  const { toasts, show: showToast, remove: removeToast } = useToast();

  // Load from localStorage
  React.useEffect(() => {
    try {
      const raw = localStorage.getItem("biolab-entries-v2");
      if (raw) { const p = JSON.parse(raw); if (Array.isArray(p)) setEntries(p); }
    } catch {}
    setStorageReady(true);
  }, []);

  React.useEffect(() => {
    if (!storageReady) return;
    try { localStorage.setItem("biolab-entries-v2", JSON.stringify(entries)); } catch {}
  }, [entries, storageReady]);

  React.useEffect(() => { if (globalUser) setConfig("biolab-last-user", globalUser); }, [globalUser]);

  const handlePreviewRequest = (entry) => setPreview(entry);
  const handleConfirmSave = React.useCallback(() => {
    if (!preview) return;
    if (editingEntry) {
      setEntries(p => p.map(e => e.id === editingEntry.id ? { ...e, ...preview, savedAt: new Date().toISOString() } : e));
      setEditingEntry(null);
    } else {
      setEntries(p => [{ ...preview, id: uid(), savedAt: new Date().toISOString() }, ...p]);
    }
    setPreview(null);
    showToast("Entrada guardada", "success");
  }, [preview, editingEntry, showToast]);

  const handleDelete = React.useCallback((id) => {
    if (!window.confirm("¿Eliminar esta entrada?")) return;
    setEntries(p => p.filter(e => e.id !== id));
    showToast("Entrada eliminada", "info");
  }, [showToast]);

  const handleEditEntry = (entry) => {
    setEditingEntry(entry);
    setActiveModule(entry.module);
    setActiveTab("form");
    showToast(`Editando: ${entry.title}`, "info");
  };

  const handleExportEntry = React.useCallback((entry) => {
    const blob = new Blob([entry.content], { type: "text/plain;charset=utf-8" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `${(entry.title||"bitacora").replace(/[^a-zA-Z0-9\-_]/g,"_")}.txt`;
    a.click();
  }, []);

  const clearAll = () => {
    if (!window.confirm("¿Eliminar TODAS las entradas?")) return;
    setEntries([]);
    try { localStorage.removeItem("biolab-entries-v2"); } catch {}
    showToast("Historial limpiado", "info");
  };

  const activeMod = MODULES.find(m => m.id === activeModule);

  const topTabs = [
    { id: "form",      icon: "✏",  label: "Formulario" },
    { id: "history",   icon: "📋", label: `Historial (${entries.length})` },
    { id: "calendar",  icon: "📅", label: "Calendario" },
    { id: "reports",   icon: "📊", label: "Reportes" },
    { id: "settings",  icon: "⚙",  label: "Ajustes" },
  ];

  return (
    <div style={{ background: C.bg, minHeight: "100vh", color: C.text, fontFamily: "'Segoe UI', system-ui, sans-serif", display: "flex", flexDirection: "column" }}>
      <ToastContainer toasts={toasts} onRemove={removeToast} />
      {preview && <PreviewModal content={preview.content} title={preview.title} onClose={() => { setPreview(null); setEditingEntry(null); }} onConfirm={handleConfirmSave} />}

      {/* Header */}
      <header style={{ background: C.surf, borderBottom: `1px solid ${C.border}`, padding: "0 20px", height: 52, display: "flex", alignItems: "center", gap: 12, position: "sticky", top: 0, zIndex: 100, flexShrink: 0 }}>
        <span style={{ fontSize: 18 }}>🔬</span>
        <span style={{ fontFamily: "'Courier New', monospace", fontWeight: 700, fontSize: 14, color: C.primary, letterSpacing: 2 }}>BIOLAB</span>
        <span style={{ fontFamily: "monospace", fontSize: 10, color: C.muted }}>v6.4</span>
        <div style={{ flex: 1 }} />
        {/* Global user selector */}
        <select value={globalUser} onChange={e => setGlobalUser(e.target.value)}
          style={{ ...inp(false), width: 200, fontSize: 11, padding: "4px 8px", background: C.surf2 }}>
          <option value="">— Seleccionar usuario —</option>
          {PERSONAL.map(p => <option key={p} value={p}>{p.split(" ").slice(-2).join(" ")}</option>)}
        </select>
        {/* Top tabs */}
        <div style={{ display: "flex", gap: 2 }}>
          {topTabs.map(t => (
            <button key={t.id} onClick={() => setActiveTab(t.id)} style={{
              background: activeTab === t.id ? C.surf3 : "none",
              border: `1px solid ${activeTab === t.id ? C.border2 : "transparent"}`,
              borderRadius: 4, padding: "5px 10px", color: activeTab === t.id ? C.text : C.muted,
              cursor: "pointer", fontSize: 11, fontFamily: "monospace", display: "flex", alignItems: "center", gap: 4,
            }}><span>{t.icon}</span><span>{t.label}</span></button>
          ))}
        </div>
      </header>

      {/* Status bar */}
      <StatusBar entries={entries} />

      <div style={{ display: "flex", flex: 1, overflow: "hidden" }}>
        {/* Sidebar: only for form tab */}
        {activeTab === "form" && (
          <nav style={{ width: 190, background: C.surf, borderRight: `1px solid ${C.border}`, padding: "12px 0", flexShrink: 0, overflowY: "auto" }}>
            <div style={{ padding: "0 12px 8px", fontSize: 9, color: C.muted, letterSpacing: 2, textTransform: "uppercase", fontFamily: "monospace" }}>Módulos</div>
            {MODULES.map(m => {
              const count = entries.filter(e => e.module === m.id).length;
              const isActive = activeModule === m.id;
              return (
                <button key={m.id} onClick={() => setActiveModule(m.id)} style={{
                  display: "flex", alignItems: "center", gap: 8, width: "100%",
                  padding: "9px 12px", background: isActive ? m.color + "15" : "none",
                  border: "none", borderLeft: `3px solid ${isActive ? m.color : "transparent"}`,
                  color: isActive ? m.color : C.muted, cursor: "pointer", textAlign: "left",
                  fontSize: 11, fontFamily: "monospace", transition: "all 0.12s",
                }}>
                  <span style={{ fontSize: 13 }}>{m.icon}</span>
                  <span style={{ flex: 1, lineHeight: 1.3 }}>{m.label}</span>
                  {count > 0 && <span style={{ background: m.color, color: "#000", borderRadius: 8, padding: "1px 5px", fontSize: 9, fontWeight: 700 }}>{count}</span>}
                </button>
              );
            })}
            {entries.length > 0 && (
              <div style={{ marginTop: 12, padding: "0 12px" }}>
                <button onClick={clearAll} style={{ background: "none", border: "none", color: C.danger + "88", cursor: "pointer", fontSize: 10, fontFamily: "monospace" }}>🗑 Limpiar todo</button>
              </div>
            )}
          </nav>
        )}

        {/* Main content */}
        <main style={{ flex: 1, padding: 20, overflowY: "auto" }}>
          {/* FORM TAB */}
          {activeTab === "form" && (
            <>
              <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 16 }}>
                <span style={{ fontSize: 20 }}>{activeMod?.icon}</span>
                <div>
                  <h1 style={{ margin: 0, fontSize: 16, fontFamily: "monospace", color: activeMod?.color, letterSpacing: 1 }}>{activeMod?.label}</h1>
                  <div style={{ fontSize: 10, color: C.muted, fontFamily: "monospace" }}>{new Date().toLocaleDateString("es-MX", { weekday: "long", year: "numeric", month: "long", day: "numeric" })}</div>
                </div>
                {editingEntry && (
                  <span style={{ background: C.amber + "22", color: C.amber, border: `1px solid ${C.amber}44`, borderRadius: 4, padding: "3px 10px", fontSize: 11, fontFamily: "monospace" }}>
                    ✏ Modo edición
                    <button onClick={() => setEditingEntry(null)} style={{ background: "none", border: "none", color: C.muted, cursor: "pointer", marginLeft: 6 }}>✕</button>
                  </span>
                )}
              </div>
              <div style={{ background: C.surf, border: `1px solid ${C.border}`, borderRadius: 8, padding: 18 }}>
                {activeModule === "bitacora" && <BitacoraDiariaForm onPreview={handlePreviewRequest} globalUser={globalUser} editData={editingEntry} />}
                {activeModule === "incubadoras" && <IncubadorasForm onPreview={handlePreviewRequest} globalUser={globalUser} />}
                {activeModule === "ultracryo" && <UltracryoForm onPreview={handlePreviewRequest} globalUser={globalUser} />}
                {activeModule === "autoclave" && <AutoclaveForm onPreview={handlePreviewRequest} globalUser={globalUser} />}
                {activeModule === "ambiental" && <AmbientalForm onPreview={handlePreviewRequest} globalUser={globalUser} />}
                {activeModule === "procesamiento" && <ProcesamientoForm onPreview={handlePreviewRequest} globalUser={globalUser} />}
                {activeModule === "cobre" && <CobreForm onPreview={handlePreviewRequest} globalUser={globalUser} />}
              </div>
            </>
          )}

          {/* HISTORY TAB */}
          {activeTab === "history" && (
            <HistoryPanel entries={entries} onDelete={handleDelete} onExport={handleExportEntry} onEdit={handleEditEntry} />
          )}

          {/* CALENDAR TAB */}
          {activeTab === "calendar" && (
            <CalendarTab entries={entries} onSelectDay={(day) => {
              setCalendarDay(day);
              showToast(`Mostrando entradas del ${day}`, "info");
              setActiveTab("history");
            }} />
          )}

          {/* REPORTS TAB */}
          {activeTab === "reports" && <ReportsTab entries={entries} showToast={showToast} />}

          {/* SETTINGS TAB */}
          {activeTab === "settings" && <SettingsTab showToast={showToast} />}
        </main>
      </div>
    </div>
  );
}

// ── Mount ────────────────────────────────────────────────────────────
const _root = ReactDOM.createRoot(document.getElementById("root"));
_root.render(<BioLabApp />);
if (document.getElementById("splash")) {
  setTimeout(() => {
    const s = document.getElementById("splash");
    if (s) { s.style.opacity = "0"; setTimeout(() => s.remove(), 400); }
  }, 800);
}
