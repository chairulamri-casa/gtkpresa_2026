# Sistem GTKPRESA 2026
Aplikasi Pendaftaran & Penilaian — Anugerah Guru dan Tenaga Kependidikan Prestasi
Kanwil Kementerian Agama Provinsi Aceh, Bidang Pendidikan Madrasah

Dibangun **config-driven**: kategori mata lomba, rubrik/bobot penilaian, dan bobot
nilai akhir semuanya tersimpan sebagai data di tabel `app_settings`, `kategori_lomba`,
dan `kriteria_penilaian` — bukan hardcode di kode aplikasi. Jika Juknis berubah lagi,
cukup diedit lewat Panel Admin, tanpa ubah kode maupun deploy ulang.

Skema saat ini mengadopsi **Tata Cara Pelaksanaan Anugerah Guru dan Tenaga
Kependidikan Kementerian Agama Tingkat Nasional Tahun 2025**, dengan penyesuaian
konteks Provinsi Aceh.

## Struktur File
```
gtkpresa-app/
├── index.html                 # Halaman login (gerbang utama, redirect sesuai peran)
├── daftar.html                 # Modul Admin Kabupaten/Kota — daftar delegasi & unggah berkas
├── admin.html                  # Modul Admin Provinsi — rekap peserta, kategori/rubrik, akun, pengaturan
├── penilaian-berkas.html       # Modul Tim Pemeriksa Berkas (Kriteria Kategori + Feature Diri)
├── penilaian-presentasi.html   # Modul Dewan Juri (Presentasi & Wawancara + Nilai Tambah)
├── laporan.html                 # Modul Laporan/Rekap Nilai & Penetapan Pemenang (Panitia/Admin Provinsi)
├── shared/
│   ├── supabase-client.js       # Konfigurasi koneksi Supabase (ISI URL & ANON KEY DI SINI)
│   └── style.css                 # Tema visual (hijau/emas ala Kemenag)
└── schema.sql                    # Skema database lengkap (jalankan di Supabase SQL Editor)
```

## 6 Mata Lomba (Trait-Based)

Klaster Guru dan Klaster Tendik, masing-masing 3 kategori karakter identik:

| Klaster Guru | Klaster Tendik |
|---|---|
| Guru Inspiratif | Tendik Inspiratif |
| Guru Dedikatif | Tendik Dedikatif |
| Guru Inovatif | Tendik Inovatif |

Tendik dapat diwakili oleh **Kepala Madrasah/RA, Pengawas Madrasah, Laboran, atau
Pustakawan** — jabatan dicatat bebas di data peserta (`peserta.jabatan`), TIDAK
di-hardcode ke kategori. Substansi yang dinilai adalah karakter (Inspiratif/
Dedikatif/Inovatif), bukan prestasi menjalankan jabatan struktural.

## Langkah Instalasi

### 1. Buat Proyek Supabase Baru
Buat proyek baru di [supabase.com](https://supabase.com) khusus untuk GTKPRESA 2026
(disarankan terpisah dari proyek RUDAR, supaya data ujian dan data lomba tidak
tercampur).

### 2. Jalankan Skema Database
Buka **SQL Editor** di dashboard Supabase, salin seluruh isi `schema.sql`, lalu jalankan
(Run). Ini akan membuat seluruh tabel, 6 mata lomba awal, rubrik penilaian, 23
kabupaten/kota, dan seluruh kebijakan RLS (Row Level Security) sekaligus.

### 3. Isi Kredensial di `shared/supabase-client.js`
Buka **Project Settings > API** di Supabase, salin **Project URL** dan **anon public
key**, lalu tempel di:
```js
const SUPABASE_URL = "https://xxxxxxxx.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOi....";
```

### 4. Buat Akun Admin Provinsi Pertama
1. Di Supabase Dashboard → **Authentication → Users → Add User**, buat akun email +
   password untuk diri CA sendiri (Ketua Panitia).
2. Salin **User UID** hasil pembuatan akun tadi.
3. Di **Table Editor → profiles**, tambah baris baru:
   - `id` = User UID tadi
   - `nama` = nama CA
   - `role` = `admin_provinsi`
   - `aktif` = true

### 5. Deploy ke GitHub Pages
```bash
git init
git add .
git commit -m "Inisialisasi Sistem GTKPRESA 2026"
git remote add origin https://github.com/chairulamri-casa/gtkpresa-2026.git
git push -u origin main
```
Lalu aktifkan GitHub Pages di **Settings → Pages** repo tersebut, pilih branch `main`.

### 6. Mulai Kelola dari Panel Admin
Login ke `admin.html` dengan akun admin_provinsi tadi:
- **Tab Kelola Akun** — tambahkan akun Admin Kabupaten/Kota (23 akun), Tim Pemeriksa
  Berkas, dan Dewan Juri (akun login dibuat lebih dulu di Supabase Auth, lalu
  dihubungkan lewat panel ini menggunakan User UID).
- **Tab Kategori & Rubrik** — sesuaikan nama kategori/bobot rubrik jika Juknis
  berubah lagi.
- **Tab Pengaturan** — atur kuota delegasi, bobot nilai akhir, serta buka/tutup
  status pendaftaran.

## Alur Kerja Ringkas
1. **Admin Kabkota** login → daftarkan maksimal 6 peserta secara bebas sesuai
   kemampuan daerah (1 peserta per mata lomba, tidak wajib genap 6) → unggah
   Feature Diri (wajib), Best Practice/Makalah (opsional), dan bukti pendukung
   lain per peserta.
2. **Tidak ada ambang batas maupun mekanisme eliminasi** — keenam mata lomba
   selalu dilaksanakan setiap tahun, berapa pun jumlah peserta yang mendaftar.
3. **Tim Pemeriksa Berkas** login → menilai **Kriteria Kategori** (rubrik nasional,
   berlaku sama untuk pasangan Guru/Tendik) dan **Feature Diri** (rubrik universal),
   sekaligus menetapkan status verifikasi administrasi (**Lengkap** / **Tidak
   Lengkap**) tiap peserta. Nilai Berkas = 60% Kriteria Kategori + 40% Feature Diri.
4. **Seluruh peserta berstatus Lengkap** otomatis tampil di halaman Dewan Juri —
   tidak ada proses penyaringan nominator.
5. **Dewan Juri** login saat presentasi & wawancara di Banda Aceh → menilai
   **Rubrik Presentasi** (9 aspek nasional) dan **Rubrik Nilai Tambah** (bahasa
   asing, moderasi beragama, pemahaman kompetensi peran).
6. **Panitia** menetapkan Juara 1-3 dan Harapan 1-3 berdasarkan Nilai Akhir
   (komposisi otomatis 35% Berkas + 50% Presentasi + 15% Nilai Tambah, dapat
   diubah di Pengaturan).
7. Juara 1-3 tiap mata lomba menjadi calon usulan ke Anugerah GTK Kemenag Tingkat
   Nasional (kuota maksimal 3 perwakilan/kategori).

## Catatan Keamanan
- Seluruh akses data diatur lewat **Row Level Security (RLS)** di database — Admin
  Kabupaten/Kota hanya bisa melihat/mengubah data kabupaten/kotanya sendiri; Juri dan
  Pemeriksa Berkas hanya bisa menulis nilai atas namanya sendiri.
- Pembuatan akun login (email/password) sengaja tidak dibuat lewat aplikasi ini
  (memerlukan *service role key* yang tidak aman ditaruh di kode front-end publik).
  Gunakan Supabase Auth Dashboard untuk membuat akun, lalu hubungkan lewat panel
  Kelola Akun.

## Status Pengembangan
Versi ketiga — disesuaikan penuh dengan Tata Cara Pelaksanaan Anugerah GTK
Kementerian Agama Tingkat Nasional Tahun 2025: 6 mata lomba trait-based (Guru/Tendik
× Inspiratif/Dedikatif/Inovatif), kuota maksimal (bukan wajib) 6 peserta/kab-kota,
tanpa ambang batas/eliminasi, Kriteria Kategori mengadopsi kriteria nasional
(berlaku sama untuk pasangan Guru-Tendik), Feature Diri wajib universal, Best
Practice/Makalah opsional universal (maks. 7 halaman), Rubrik Presentasi 9-aspek
nasional, dan Rubrik Nilai Tambah (bahasa asing, moderasi beragama, pemahaman
kompetensi peran). Nilai Akhir = 35% Berkas + 50% Presentasi + 15% Nilai Tambah.

**Catatan:** versi demo offline (mock, tanpa Supabase) belum disesuaikan dengan
skema ini dan masih mencerminkan struktur kategori lama — perlu dibangun ulang
sebelum dipakai untuk uji coba visual.
