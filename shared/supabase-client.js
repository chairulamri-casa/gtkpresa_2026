// =====================================================================
// GTKPRESA 2026 — Konfigurasi Supabase (dipakai di semua halaman)
// Proyek: gtkpresa-2026 (organisasi: Perangkat Pembelajaran MI)
// =====================================================================
const SUPABASE_URL = "https://llypthirfhydcttvlntf.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxseXB0aGlyZmh5ZGN0dHZsbnRmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2NzQ3MTcsImV4cCI6MjEwNDI1MDcxN30._EE-fFlDOSIVkBDfPBIlR0lFfMVMEYk641qixYiU3aA";

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ---------------------------------------------------------------------
// Helper: ambil profil (role, kabkota_id) user yang sedang login
// ---------------------------------------------------------------------
async function getProfile() {
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return null;
  const { data, error } = await sb.from("profiles").select("*").eq("id", user.id).single();
  if (error) { console.error(error); return null; }
  return data;
}

// ---------------------------------------------------------------------
// Helper: proteksi halaman — redirect ke index.html bila belum login
// atau role tidak sesuai. Panggil di awal setiap halaman modul.
// allowedRoles: array role yang boleh akses, kosong/undefined = semua role login
// ---------------------------------------------------------------------
async function requireAuth(allowedRoles) {
  const { data: { session } } = await sb.auth.getSession();
  if (!session) { window.location.href = "index.html"; return null; }
  const profile = await getProfile();
  if (!profile || !profile.aktif) {
    alert("Akun tidak ditemukan atau dinonaktifkan. Hubungi Admin Provinsi.");
    await sb.auth.signOut();
    window.location.href = "index.html";
    return null;
  }
  if (allowedRoles && allowedRoles.length && !allowedRoles.includes(profile.role)) {
    alert("Anda tidak memiliki akses ke halaman ini.");
    window.location.href = "index.html";
    return null;
  }
  return profile;
}

async function logout() {
  await sb.auth.signOut();
  window.location.href = "index.html";
}

// ---------------------------------------------------------------------
// Helper format
// ---------------------------------------------------------------------
function fmtNum(n, d = 2) {
  return Number(n || 0).toFixed(d);
}
function roleLabel(role) {
  return {
    admin_provinsi: "Admin Provinsi (Panitia)",
    admin_kabkota: "Admin Kabupaten/Kota",
    pemeriksa_berkas: "Tim Pemeriksa Berkas",
    juri: "Dewan Juri",
    panitia: "Panitia (Lihat Saja)",
    peserta: "Peserta"
  }[role] || role;
}

// ---------------------------------------------------------------------
// Pratinjau Google Drive langsung di halaman (tanpa pindah tab).
// Dipakai di penilaian-berkas.html, peserta.html, dsb.
// ---------------------------------------------------------------------
function driveEmbedUrl(url) {
  if (!url) return null;
  const patterns = [
    { re: /\/document\/d\/([a-zA-Z0-9_-]+)/, base: "https://docs.google.com/document/d/" },
    { re: /\/spreadsheets\/d\/([a-zA-Z0-9_-]+)/, base: "https://docs.google.com/spreadsheets/d/" },
    { re: /\/presentation\/d\/([a-zA-Z0-9_-]+)/, base: "https://docs.google.com/presentation/d/" },
    { re: /\/file\/d\/([a-zA-Z0-9_-]+)/, base: "https://drive.google.com/file/d/" },
    { re: /[?&]id=([a-zA-Z0-9_-]+)/, base: "https://drive.google.com/file/d/" },
  ];
  for (const p of patterns) {
    const m = url.match(p.re);
    if (m) return `${p.base}${m[1]}/preview`;
  }
  return null; // bukan link Google Drive/Docs yg dikenali -> tidak ada pratinjau
}

let _previewSeq = 0;
// Render 1 baris tautan bukti, dengan tombol Pratinjau jika link dikenali sbg Google Drive/Docs.
function renderTautanBukti(url) {
  const embedUrl = driveEmbedUrl(url);
  if (!embedUrl) {
    return `<div style="font-size:12.5px; margin:5px 0;"><a href="${url}" target="_blank">🔗 ${url}</a></div>`;
  }
  const pid = "preview_" + (_previewSeq++);
  return `
    <div style="font-size:12.5px; margin:6px 0;">
      <a href="${url}" target="_blank">🔗 ${url}</a>
      <button type="button" class="btn btn-outline btn-sm" style="padding:2px 9px; margin-left:6px;" onclick="togglePreview('${pid}', '${embedUrl.replace(/'/g, "\\'")}')">👁 Pratinjau</button>
      <div id="${pid}" style="display:none; margin-top:8px;"></div>
    </div>`;
}

function togglePreview(containerId, embedUrl) {
  const el = document.getElementById(containerId);
  if (!el) return;
  const showing = el.style.display !== "none" && el.style.display !== "";
  if (showing) {
    el.style.display = "none";
    return;
  }
  if (!el.dataset.loaded) {
    el.innerHTML = `<iframe src="${embedUrl}" loading="lazy" style="width:100%; height:440px; border:1px solid var(--border); border-radius:8px; background:#fafafa;" allow="autoplay"></iframe>`;
    el.dataset.loaded = "1";
  }
  el.style.display = "block";
}

// ---------------------------------------------------------------------
// Gerbang tanggal pendaftaran + jadwal kegiatan publik.
// Dipakai di index.html & registrasi.html (bisa diakses sebelum login).
// ---------------------------------------------------------------------
function fmtTanggalWIB(iso) {
  if (!iso) return "-";
  const d = new Date(iso);
  return d.toLocaleString("id-ID", { day: "numeric", month: "long", year: "numeric", hour: "2-digit", minute: "2-digit", timeZone: "Asia/Jakarta" }) + " WIB";
}

async function cekInfoPendaftaran() {
  const { data, error } = await sb.rpc("get_info_pendaftaran");
  if (error) { console.error(error); return null; }
  return data;
}

async function renderJadwalKegiatan(containerId) {
  const { data } = await sb.from("jadwal_kegiatan").select("*").order("urutan");
  const el = document.getElementById(containerId);
  if (!el) return;
  if (!data || !data.length) { el.innerHTML = '<div class="empty-state">Jadwal belum tersedia.</div>'; return; }
  el.innerHTML = `<div class="timeline">
    ${data.map((j, i) => `
      <div class="timeline-item">
        <div class="timeline-dot">${i + 1}</div>
        <div class="timeline-title">${j.kegiatan}</div>
        <div class="timeline-date">🗓 ${j.tanggal}</div>
        ${j.keterangan ? `<div class="timeline-desc">${j.keterangan}</div>` : ""}
      </div>`).join("")}
  </div>`;
}

// URL publik dokumen Juknis (Supabase Storage, bucket "dokumen"). Admin
// Provinsi bisa unggah/ganti file-nya lewat admin.html tanpa perlu deploy ulang.
function urlJuknisPdf() {
  return SUPABASE_URL + "/storage/v1/object/public/dokumen/juknis-gtkpresa-2026.pdf";
}

// URL publik logo resmi (Supabase Storage, bucket "aset"). Dipakai di
// Kartu Peserta & Sertifikat.
function urlLogoKemenag() {
  return SUPABASE_URL + "/storage/v1/object/public/aset/logo-kemenag.png";
}

// URL publik barcode tanda tangan elektronik (Srikandi), bucket "aset" --
// 1 gambar yang sama dipakai berulang di semua sertifikat.
function urlBarcodeTtd() {
  return SUPABASE_URL + "/storage/v1/object/public/aset/barcode-ttd.png";
}

// ---------------------------------------------------------------------
// Pop up (modal) info Dokumen & Jadwal -- dipakai di index.html & registrasi.html
// ---------------------------------------------------------------------
function bukaModalInfo() {
  const el = document.getElementById("modalInfo");
  if (el) el.classList.add("show");
}
function tutupModalInfo() {
  const el = document.getElementById("modalInfo");
  if (el) el.classList.remove("show");
}
document.addEventListener("keydown", (e) => { if (e.key === "Escape") tutupModalInfo(); });
