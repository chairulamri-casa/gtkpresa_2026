-- =====================================================================
-- GTKPRESA 2026 — Skema Database (Supabase / PostgreSQL)
-- Kanwil Kemenag Provinsi Aceh — Bidang Pendidikan Madrasah
-- Dirancang CONFIG-DRIVEN: kategori lomba, rubrik, bobot, dan ambang
-- batas semuanya disimpan sebagai DATA (bukan hardcode di kode aplikasi)
-- sehingga bila juknis final berubah, cukup diubah lewat panel Admin.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. EXTENSIONS
-- ---------------------------------------------------------------------
create extension if not exists "uuid-ossp";

-- ---------------------------------------------------------------------
-- 1. PENGATURAN GLOBAL (config-driven, key-value)
-- ---------------------------------------------------------------------
create table app_settings (
  key text primary key,
  value jsonb not null,
  keterangan text,
  updated_at timestamptz default now()
);

insert into app_settings (key, value, keterangan) values
  ('kuota_delegasi_per_kabkota', '6', 'Jumlah maksimal delegasi yang boleh dikirim setiap kabupaten/kota (maksimal, tidak wajib genap 6; 1 peserta per mata lomba)'),
  ('bobot_nilai_berkas', '0.35', 'Bobot Nilai Berkas terhadap nilai akhir (mengacu Tata Cara Nasional GTK Kemenag 2025)'),
  ('bobot_nilai_grandfinal', '0.50', 'Bobot Nilai Presentasi & Wawancara terhadap nilai akhir'),
  ('bobot_nilai_tambah', '0.15', 'Bobot Nilai Tambah (bahasa asing, moderasi beragama, pemahaman kompetensi peran) terhadap nilai akhir'),
  ('bobot_kompetensi_dalam_berkas', '0.60', 'Dalam komponen Nilai Berkas: bobot Rubrik Kompetensi Kategori'),
  ('bobot_feature_dalam_berkas', '0.40', 'Dalam komponen Nilai Berkas: bobot Rubrik Feature Diri'),
  ('jumlah_pemenang_per_kategori', '6', 'Jumlah pemenang (Juara 1-3 + Harapan 1-3) per mata lomba'),
  ('tanggal_mulai_pendaftaran', '"2026-09-01T00:00:00+07:00"', 'Tanggal/jam mulai pendaftaran & registrasi mandiri peserta dibuka'),
  ('tanggal_tutup_pendaftaran', '"2026-09-30T21:59:00+07:00"', 'Batas akhir pendaftaran & upload berkas'),
  ('status_pendaftaran', '"buka"', 'buka | tutup — mengontrol apakah form pendaftaran masih menerima input'),
  ('biaya_pendaftaran', '0', 'Nominal biaya pendaftaran per peserta (Rupiah) — 0 = gratis sesuai Juknis Bab II.C')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- 2. KABUPATEN/KOTA (23 wilayah, referensi tetap)
-- ---------------------------------------------------------------------
create table kabupaten_kota (
  id serial primary key,
  nama text not null unique,
  kode text unique
);

insert into kabupaten_kota (nama, kode) values
  ('Kota Banda Aceh','1171'),('Kota Sabang','1172'),('Kota Langsa','1173'),
  ('Kota Lhokseumawe','1174'),('Kota Subulussalam','1175'),
  ('Aceh Besar','1106'),('Pidie','1107'),('Pidie Jaya','1112'),
  ('Bireuen','1111'),('Aceh Utara','1108'),('Aceh Timur','1103'),
  ('Aceh Tamiang','1113'),('Aceh Tengah','1109'),('Bener Meriah','1114'),
  ('Gayo Lues','1115'),('Aceh Barat','1105'),('Aceh Barat Daya','1116'),
  ('Nagan Raya','1117'),('Aceh Jaya','1118'),('Aceh Selatan','1104'),
  ('Aceh Singkil','1101'),('Simeulue','1102'),('Aceh Tenggara','1110')
on conflict (nama) do nothing;

-- ---------------------------------------------------------------------
-- 3. KATEGORI / MATA LOMBA (config-driven, bukan hardcode)
-- ---------------------------------------------------------------------
-- klaster: 'guru' | 'tendik' (informasi struktural, tidak lagi memengaruhi
-- logika peleburan karena skema saat ini tidak memiliki mekanisme realokasi:
-- mata lomba yang gagal kuorum dinyatakan tidak dilombakan, dan peserta
-- yang terdampak dinyatakan gugur pada tahun berjalan)
-- Tidak ada mekanisme eliminasi/ambang batas: keenam mata lomba selalu aktif
-- setiap tahun penyelenggaraan (sesuai Bab III.D Juknis GTKPRESA 2026)
create table kategori_lomba (
  id uuid primary key default uuid_generate_v4(),
  nama text not null,
  klaster text not null check (klaster in ('guru','tendik')),
  urutan int not null default 0,
  aktif boolean not null default true,      -- switch tampil/tidak di form pendaftaran
  deskripsi text,
  created_at timestamptz default now()
);

-- 6 mata lomba trait-based: klaster Guru dan klaster Tendik masing-masing
-- punya 3 kategori karakter yang identik (Inspiratif/Dedikatif/Inovatif).
-- Tendik dapat diwakili Kepala Madrasah/RA, Pengawas Madrasah, Laboran,
-- atau Pustakawan -- jabatan peserta dicatat bebas di tabel peserta.jabatan,
-- TIDAK dihardcode ke kategori_lomba (substansi yang dinilai adalah
-- karakter, bukan jabatan struktural).
insert into kategori_lomba (nama, klaster, urutan, deskripsi) values
  ('Guru Inspiratif','guru',1,'Karya buku/jurnal ilmiah, mengantarkan siswa ke PT, penghargaan relevan'),
  ('Guru Dedikatif','guru',2,'Loyalitas 3T, aktif sosial-keagamaan, peduli keberagaman/inklusif'),
  ('Guru Inovatif','guru',3,'Metode/aplikasi inovatif, konten digital, sistem manajemen, kemitraan, forum ilmiah'),
  ('Tendik Inspiratif','tendik',4,'Karya buku/jurnal ilmiah, mengantarkan binaan ke PT, penghargaan relevan'),
  ('Tendik Dedikatif','tendik',5,'Loyalitas 3T, aktif sosial-keagamaan, peduli keberagaman/inklusif'),
  ('Tendik Inovatif','tendik',6,'Metode/aplikasi inovatif, konten digital, sistem manajemen, kemitraan, forum ilmiah');

-- ---------------------------------------------------------------------
-- 4. RUBRIK / KRITERIA PENILAIAN BERKAS (config-driven per kategori)
-- ---------------------------------------------------------------------
create table kriteria_penilaian (
  id uuid primary key default uuid_generate_v4(),
  kategori_id uuid not null references kategori_lomba(id) on delete cascade,
  indikator text not null,
  bobot numeric(5,2) not null check (bobot >= 0 and bobot <= 100), -- dalam persen, total per kategori idealnya = 100
  urutan int not null default 0,
  bukti_pendukung text -- contoh bukti pendukung ref Dokumen Kelengkapan Penilaian
                        -- Tata Cara Nasional 2025 -- ditampilkan di akun Peserta
                        -- dan akun Tim Pemeriksa Berkas sbg panduan dokumen yg perlu disiapkan/dicari
);

-- Kriteria berikut mengacu langsung pada Tata Cara Pelaksanaan Anugerah GTK
-- Kementerian Agama Tingkat Nasional 2025 (Bab II.B / Lampiran Dokumen
-- Kelengkapan Penilaian), dan berlaku SAMA baik untuk jalur Guru maupun
-- jalur Tendik pada kategori karakter yang bersesuaian. Peserta TIDAK
-- PERLU memenuhi seluruh kriteria sekaligus (logika OR/salah-satu).

-- Kriteria Inspiratif (Guru Inspiratif & Tendik Inspiratif) -- 4 kriteria @ 25%
insert into kriteria_penilaian (kategori_id, indikator, bobot, urutan, bukti_pendukung)
select id, x.indikator, x.bobot, x.urutan, x.bukti
from kategori_lomba
cross join lateral (values
  ('Memiliki karya buku terbanyak yang relevan dengan bidang tugas', 25::numeric, 1, 'Daftar bibliografi buku; Foto/scan cover; ISBN & bukti penerbitan'),
  ('Memiliki karya tulis ilmiah terbanyak pada jurnal nasional/internasional', 25, 2, 'Daftar artikel; Tautan/DOI; Sertifikat publikasi'),
  ('Mengantarkan banyak peserta didik/binaan diterima di perguruan tinggi dalam/luar negeri', 25, 3, 'Rekap daftar peserta didik/binaan; Surat keterangan dari madrasah'),
  ('Memiliki penghargaan relevan tingkat nasional/internasional (2023-2025)', 25, 4, 'Sertifikat/piagam; SK/undangan dan dokumentasi kegiatan')
) as x(indikator, bobot, urutan, bukti)
where nama in ('Guru Inspiratif','Tendik Inspiratif');

-- Kriteria Dedikatif (Guru Dedikatif & Tendik Dedikatif) -- 3 kriteria, bobot SETARA
insert into kriteria_penilaian (kategori_id, indikator, bobot, urutan, bukti_pendukung)
select id, x.indikator, x.bobot, x.urutan, x.bukti
from kategori_lomba
cross join lateral (values
  ('Loyalitas bertugas tinggi (≥10 tahun), terutama namun tidak terbatas pada daerah 3T/keterbatasan sarana', 34::numeric, 1, 'SK pengangkatan/penugasan; Surat keterangan lokasi tugas; Dokumentasi kondisi wilayah'),
  ('Aktif dalam kegiatan sosial-keagamaan dan pembinaan karakter', 33, 2, 'Foto kegiatan; Surat keterangan madrasah/komunitas'),
  ('Kepekaan terhadap keberagaman dan penerapan pendekatan inklusif', 33, 3, 'Modul/panduan inklusif; Dokumentasi kegiatan; Testimoni siswa/rekan/orang tua')
) as x(indikator, bobot, urutan, bukti)
where nama in ('Guru Dedikatif','Tendik Dedikatif');

-- Kriteria Inovatif (Guru Inovatif & Tendik Inovatif) -- 5 kriteria @ 20%
insert into kriteria_penilaian (kategori_id, indikator, bobot, urutan, bukti_pendukung)
select id, x.indikator, x.bobot, x.urutan, x.bukti
from kategori_lomba
cross join lateral (values
  ('Menciptakan metode pembelajaran/pelayanan inovatif (termasuk aplikasi/game)', 20::numeric, 1, 'Deskripsi inovasi; Tangkapan layar/link aplikasi/game; Surat pemanfaatan oleh pihak lain'),
  ('Memiliki karya/konten digital dengan jangkauan (subscriber/viewer/like) luas', 20, 2, 'Link platform digital; Statistik subscriber/viewer/like; Dokumentasi pembuatan konten'),
  ('Menciptakan sistem manajemen madrasah berbasis digital', 20, 3, 'SOP/diagram alur; Screenshot sistem; Surat penetapan penggunaan'),
  ('Mengembangkan kemitraan dengan dunia usaha/perguruan tinggi/masyarakat', 20, 4, 'MoU/Nota Kesepahaman; Dokumentasi kegiatan'),
  ('Aktif mengikuti forum ilmiah nasional/internasional (2023-2025)', 20, 5, 'Sertifikat peserta/pemakalah; Prosiding; Undangan/surat tugas')
) as x(indikator, bobot, urutan, bukti)
where nama in ('Guru Inovatif','Tendik Inovatif');

-- ---------------------------------------------------------------------
-- 4b. SUB-ITEM RUBRIK BERKAS (rincian per indikator, config-driven)
-- ---------------------------------------------------------------------
-- Memecah setiap indikator (Bab G Juknis) menjadi item konkret bernilai poin,
-- sehingga Tim Pemeriksa Berkas cukup mengisi angka per item (tanpa
-- menghitung manual di luar aplikasi). Jumlah skor_maks semua sub-item
-- dalam satu kriteria_id idealnya = bobot indikator tersebut.
create table sub_kriteria_penilaian (
  id uuid primary key default uuid_generate_v4(),
  kriteria_id uuid not null references kriteria_penilaian(id) on delete cascade,
  item text not null,
  skor_maks numeric(5,2) not null check (skor_maks >= 0),
  urutan int not null default 0
);

-- Sub-item untuk Kriteria Inspiratif (Guru Inspiratif & Tendik Inspiratif)
insert into sub_kriteria_penilaian (kriteria_id, item, skor_maks, urutan)
select k.id, x.item, x.skor, x.urutan
from kategori_lomba kl
join kriteria_penilaian k on k.kategori_id = kl.id
cross join lateral (values
  ('Memiliki karya buku terbanyak yang relevan dengan bidang tugas', 'Jumlah dan relevansi karya buku dengan bidang tugas', 15::numeric, 1),
  ('Memiliki karya buku terbanyak yang relevan dengan bidang tugas', 'Kualitas dan bukti penerbitan (ISBN/bukti resmi)', 10, 2),
  ('Memiliki karya tulis ilmiah terbanyak pada jurnal nasional/internasional', 'Jumlah dan kualitas artikel ilmiah', 15, 1),
  ('Memiliki karya tulis ilmiah terbanyak pada jurnal nasional/internasional', 'Tingkat jurnal (nasional/internasional) dan bukti publikasi', 10, 2),
  ('Mengantarkan banyak peserta didik/binaan diterima di perguruan tinggi dalam/luar negeri', 'Jumlah peserta didik/binaan yang berhasil diterima', 15, 1),
  ('Mengantarkan banyak peserta didik/binaan diterima di perguruan tinggi dalam/luar negeri', 'Reputasi perguruan tinggi tujuan (dalam/luar negeri)', 10, 2),
  ('Memiliki penghargaan relevan tingkat nasional/internasional (2023-2025)', 'Jumlah dan relevansi penghargaan dengan bidang tugas', 15, 1),
  ('Memiliki penghargaan relevan tingkat nasional/internasional (2023-2025)', 'Tingkat penghargaan (nasional/internasional)', 10, 2)
) as x(indikator, item, skor, urutan)
where kl.nama in ('Guru Inspiratif','Tendik Inspiratif') and k.indikator = x.indikator;

-- Sub-item untuk Kriteria Dedikatif (Guru Dedikatif & Tendik Dedikatif)
insert into sub_kriteria_penilaian (kriteria_id, item, skor_maks, urutan)
select k.id, x.item, x.skor, x.urutan
from kategori_lomba kl
join kriteria_penilaian k on k.kategori_id = kl.id
cross join lateral (values
  ('Loyalitas bertugas tinggi (≥10 tahun), terutama namun tidak terbatas pada daerah 3T/keterbatasan sarana', 'Lama masa tugas dan konsistensi pengabdian', 17::numeric, 1),
  ('Loyalitas bertugas tinggi (≥10 tahun), terutama namun tidak terbatas pada daerah 3T/keterbatasan sarana', 'Tingkat keterbatasan wilayah/sarana tempat bertugas', 17, 2),
  ('Aktif dalam kegiatan sosial-keagamaan dan pembinaan karakter', 'Frekuensi dan konsistensi keterlibatan kegiatan', 17, 1),
  ('Aktif dalam kegiatan sosial-keagamaan dan pembinaan karakter', 'Dampak kegiatan bagi karakter siswa/masyarakat', 16, 2),
  ('Kepekaan terhadap keberagaman dan penerapan pendekatan inklusif', 'Penerapan nyata pendekatan pembelajaran/pelayanan inklusif', 17, 1),
  ('Kepekaan terhadap keberagaman dan penerapan pendekatan inklusif', 'Dampak terhadap peserta didik/binaan berkebutuhan khusus', 16, 2)
) as x(indikator, item, skor, urutan)
where kl.nama in ('Guru Dedikatif','Tendik Dedikatif') and k.indikator = x.indikator;

-- Sub-item untuk Kriteria Inovatif (Guru Inovatif & Tendik Inovatif)
insert into sub_kriteria_penilaian (kriteria_id, item, skor_maks, urutan)
select k.id, x.item, x.skor, x.urutan
from kategori_lomba kl
join kriteria_penilaian k on k.kategori_id = kl.id
cross join lateral (values
  ('Menciptakan metode pembelajaran/pelayanan inovatif (termasuk aplikasi/game)', 'Orisinalitas dan kemudahan penggunaan metode/aplikasi', 10::numeric, 1),
  ('Menciptakan metode pembelajaran/pelayanan inovatif (termasuk aplikasi/game)', 'Bukti pemanfaatan oleh pihak lain', 10, 2),
  ('Memiliki karya/konten digital dengan jangkauan (subscriber/viewer/like) luas', 'Jumlah subscriber/viewer/like', 10, 1),
  ('Memiliki karya/konten digital dengan jangkauan (subscriber/viewer/like) luas', 'Kualitas dan konsistensi konten', 10, 2),
  ('Menciptakan sistem manajemen madrasah berbasis digital', 'Efektivitas dan efisiensi sistem', 10, 1),
  ('Menciptakan sistem manajemen madrasah berbasis digital', 'Bukti implementasi nyata (bukan sekadar rencana)', 10, 2),
  ('Mengembangkan kemitraan dengan dunia usaha/perguruan tinggi/masyarakat', 'Jumlah dan kualitas kemitraan', 10, 1),
  ('Mengembangkan kemitraan dengan dunia usaha/perguruan tinggi/masyarakat', 'Dampak kemitraan bagi peningkatan mutu pendidikan', 10, 2),
  ('Aktif mengikuti forum ilmiah nasional/internasional (2023-2025)', 'Tingkat forum (nasional/internasional)', 10, 1),
  ('Aktif mengikuti forum ilmiah nasional/internasional (2023-2025)', 'Peran (peserta/pemakalah) dan bukti keikutsertaan', 10, 2)
) as x(indikator, item, skor, urutan)
where kl.nama in ('Guru Inovatif','Tendik Inovatif') and k.indikator = x.indikator;

-- ---------------------------------------------------------------------
-- 5. PROFIL PENGGUNA & PERAN (role-based access)
-- ---------------------------------------------------------------------
-- role: 'admin_provinsi' | 'admin_kabkota' | 'pemeriksa_berkas' | 'juri' | 'panitia'
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nama text not null,
  role text not null check (role in ('admin_provinsi','admin_kabkota','pemeriksa_berkas','juri','panitia','peserta')),
  kabkota_id int references kabupaten_kota(id),  -- wajib diisi jika role = admin_kabkota
  kategori_ditugaskan uuid[] default '{}',       -- utk pemeriksa_berkas / juri: daftar kategori_lomba.id yang ditugaskan (kosong = semua)
  aktif boolean not null default true,
  created_at timestamptz default now()
);

-- ---------------------------------------------------------------------
-- 6. PESERTA (delegasi kabupaten/kota)
-- ---------------------------------------------------------------------
create table peserta (
  id uuid primary key default uuid_generate_v4(),
  kabkota_id int not null references kabupaten_kota(id),
  kategori_id uuid not null references kategori_lomba(id),
  akun_id uuid references profiles(id) unique, -- akun login milik peserta sendiri (diisi via daftar_dengan_token)

  -- biodata
  nama_lengkap text not null,
  nrg text,
  jabatan_fungsional text,
  tempat_lahir text,
  tanggal_lahir date,
  jenis_kelamin text check (jenis_kelamin in ('L','P')),
  agama text,
  peg_id text, npk text, nip text, nik text,
  pangkat_golongan text,
  jabatan text,
  unit_kerja text,
  alamat_unit_kerja text,
  kelurahan_madrasah text,
  kecamatan_madrasah text,
  alamat_tempat_tinggal text,
  kelurahan_tinggal text,
  kecamatan_tinggal text,
  telp_rumah text,
  no_hp text,
  email text,
  sosial_media jsonb default '{}',

  -- status alur
  status_verifikasi text not null default 'diajukan'
    check (status_verifikasi in ('diajukan','lengkap','tidak_lengkap','didiskualifikasi')),
  status_final text not null default 'peserta'
    check (status_final in ('peserta','juara_1','juara_2','juara_3','harapan_1','harapan_2','harapan_3','tidak_lolos','gugur_tidak_dilombakan')),

  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  -- ATURAN INTI: 1 kabupaten/kota hanya boleh 1 peserta per kategori
  unique (kabkota_id, kategori_id)
);

-- ---------------------------------------------------------------------
-- 7. BERKAS / DOKUMEN PENDUKUNG
-- ---------------------------------------------------------------------
create table berkas_peserta (
  id uuid primary key default uuid_generate_v4(),
  peserta_id uuid not null references peserta(id) on delete cascade,
  jenis text not null check (jenis in (
    'feature_diri','video_bukti','bukti_karya','best_practice','surat_rekomendasi','surat_pernyataan','surat_pernyataan_keaslian','sk_terakhir','dokumen_lain'
  )),
  kriteria_id uuid references kriteria_penilaian(id), -- diisi HANYA utk jenis=bukti_karya:
    -- menautkan bukti ke 1 kriteria_penilaian spesifik, supaya pemeriksa berkas
    -- bisa langsung buka link yg relevan saat menilai kriteria tsb. NULL utk
    -- jenis berkas lain (feature_diri, best_practice, surat_*, dokumen_lain).
  nama_file text,
  url text not null,           -- link Supabase Storage / Google Drive
  uploaded_at timestamptz default now()
);

-- ---------------------------------------------------------------------
-- 8. PENILAIAN BERKAS (Tim Pemeriksa Berkas)
-- ---------------------------------------------------------------------
create table penilaian_berkas (
  id uuid primary key default uuid_generate_v4(),
  peserta_id uuid not null references peserta(id) on delete cascade,
  kriteria_id uuid not null references kriteria_penilaian(id),
  pemeriksa_id uuid not null references profiles(id),
  skor numeric(5,2) not null check (skor >= 0 and skor <= 100),
  catatan text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (peserta_id, kriteria_id, pemeriksa_id)
);

-- Skor per SUB-ITEM (rincian). Baris di tabel penilaian_berkas di atas
-- diisi/dihitung OTOMATIS oleh aplikasi sebagai agregat (persentase) dari
-- tabel ini, sehingga Tim Pemeriksa Berkas cukup mengisi angka per item
-- konkret tanpa menghitung manual di luar aplikasi.
create table penilaian_berkas_detail (
  id uuid primary key default uuid_generate_v4(),
  peserta_id uuid not null references peserta(id) on delete cascade,
  sub_kriteria_id uuid not null references sub_kriteria_penilaian(id),
  pemeriksa_id uuid not null references profiles(id),
  skor numeric(5,2) not null check (skor >= 0),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (peserta_id, sub_kriteria_id, pemeriksa_id)
);

-- ---------------------------------------------------------------------
-- 8b. RUBRIK PRESENTASI & WAWANCARA (generik, berlaku sama untuk semua
-- kategori; mengadopsi 9 aspek resmi Tata Cara Pelaksanaan Anugerah GTK
-- Kementerian Agama Tingkat Nasional Tahun 2025)
-- ---------------------------------------------------------------------
create table kriteria_presentasi (
  id uuid primary key default uuid_generate_v4(),
  indikator text not null,
  bobot numeric(5,2) not null check (bobot >= 0 and bobot <= 100),
  urutan int not null default 0
);

insert into kriteria_presentasi (indikator, bobot, urutan) values
  ('Penguasaan Materi', 30, 1),
  ('Kejelasan Penyampaian', 10, 2),
  ('Kemampuan Menjawab Pertanyaan dan Menyampaikan Argumentasi', 10, 3),
  ('Ketuntasan Jawaban/Pemaparan', 10, 4),
  ('Sistematika Penyampaian', 10, 5),
  ('Penggunaan Media Presentasi', 10, 6),
  ('Ketepatan Waktu', 5, 7),
  ('Penampilan (Kerapian, Kesopanan, Keramahan)', 5, 8),
  ('Slide/Infografis Presentasi', 10, 9);

-- ---------------------------------------------------------------------
-- 8c. SUB-ITEM RUBRIK PRESENTASI (rincian per aspek, config-driven)
-- ---------------------------------------------------------------------
-- Aspek nasional sudah cukup atomik, sehingga setiap aspek diberi TEPAT
-- 1 sub-item senilai penuh bobotnya, agar tetap konsisten dengan pola
-- input berindikator yang dipakai di seluruh aplikasi (Bab penilaian
-- berkas), tanpa memaksakan pemecahan lebih lanjut yang tidak perlu.
create table sub_kriteria_presentasi (
  id uuid primary key default uuid_generate_v4(),
  kriteria_id uuid not null references kriteria_presentasi(id) on delete cascade,
  item text not null,
  skor_maks numeric(5,2) not null check (skor_maks >= 0),
  urutan int not null default 0
);

insert into sub_kriteria_presentasi (kriteria_id, item, skor_maks, urutan)
select id, indikator, bobot, 1 from kriteria_presentasi;

-- ---------------------------------------------------------------------
-- 8d. RUBRIK FEATURE DIRI (generik, berlaku sama untuk semua kategori;
-- mengadopsi standar penilaian feature Tata Cara Pelaksanaan Anugerah
-- GTK Kementerian Agama Tingkat Nasional Tahun 2025). Dinilai oleh Tim
-- Pemeriksa Berkas sebagai komponen ke-2 pembentuk Nilai Berkas
-- (lihat bobot_kompetensi_dalam_berkas / bobot_feature_dalam_berkas).
-- ---------------------------------------------------------------------
create table kriteria_feature (
  id uuid primary key default uuid_generate_v4(),
  indikator text not null,
  bobot numeric(5,2) not null check (bobot >= 0 and bobot <= 100),
  urutan int not null default 0
);

insert into kriteria_feature (indikator, bobot, urutan) values
  ('Kesesuaian Tulisan dengan Tema Mata Lomba', 10, 1),
  ('Penyajian Realita/Fakta Konkret dalam Tulisan', 15, 2),
  ('Bahasa dan Gaya Bahasa', 20, 3),
  ('Orisinalitas dan Autentisitas Tulisan', 20, 4),
  ('Keunikan/Human Interest', 20, 5),
  ('Makna yang Ditekankan dalam Tulisan', 15, 6);

create table sub_kriteria_feature (
  id uuid primary key default uuid_generate_v4(),
  kriteria_id uuid not null references kriteria_feature(id) on delete cascade,
  item text not null,
  skor_maks numeric(5,2) not null check (skor_maks >= 0),
  urutan int not null default 0
);

insert into sub_kriteria_feature (kriteria_id, item, skor_maks, urutan)
select id, indikator, bobot, 1 from kriteria_feature;

create table penilaian_feature_detail (
  id uuid primary key default uuid_generate_v4(),
  peserta_id uuid not null references peserta(id) on delete cascade,
  sub_kriteria_id uuid not null references sub_kriteria_feature(id),
  pemeriksa_id uuid not null references profiles(id),
  skor numeric(5,2) not null check (skor >= 0),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (peserta_id, sub_kriteria_id, pemeriksa_id)
);

create table penilaian_feature (
  id uuid primary key default uuid_generate_v4(),
  peserta_id uuid not null references peserta(id) on delete cascade,
  kriteria_id uuid not null references kriteria_feature(id),
  pemeriksa_id uuid not null references profiles(id),
  skor numeric(5,2) not null check (skor >= 0 and skor <= 100),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (peserta_id, kriteria_id, pemeriksa_id)
);

-- ---------------------------------------------------------------------
-- 8e. RUBRIK NILAI TAMBAH (generik, berlaku sama untuk semua kategori;
-- mengadopsi standar nasional. Dinilai oleh Dewan Juri, merupakan
-- KOMPONEN TERSENDIRI dalam komposisi Nilai Akhir -- bukan bagian dari
-- Nilai Presentasi -- menggantikan mekanisme skor_bahasa_asing lama
-- yang hanya berupa bonus poin mentah tanpa bobot formal.)
-- ---------------------------------------------------------------------
create table kriteria_nilai_tambah (
  id uuid primary key default uuid_generate_v4(),
  indikator text not null,
  bobot numeric(5,2) not null check (bobot >= 0 and bobot <= 100),
  urutan int not null default 0
);

insert into kriteria_nilai_tambah (indikator, bobot, urutan) values
  ('Penguasaan Bahasa Arab dan/atau Inggris/Asing Lainnya', 30, 1),
  ('Pemahaman Moderasi Beragama', 30, 2),
  ('Pemahaman Komponen Kompetensi Sesuai Peran (Guru/Kepala Madrasah/Pustakawan/Pengawas)', 40, 3);

create table penilaian_nilai_tambah (
  id uuid primary key default uuid_generate_v4(),
  peserta_id uuid not null references peserta(id) on delete cascade,
  kriteria_id uuid not null references kriteria_nilai_tambah(id),
  juri_id uuid not null references profiles(id),
  skor numeric(5,2) not null check (skor >= 0 and skor <= 100),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (peserta_id, kriteria_id, juri_id)
);

-- ---------------------------------------------------------------------
-- 9. PENILAIAN PRESENTASI / GRAND FINAL (Dewan Juri)
-- ---------------------------------------------------------------------
-- Tabel ini kini murni menyimpan CATATAN juri per peserta+juri. Nilai
-- tambah (bahasa/moderasi/kompetensi peran) sudah dipindah ke tabel
-- penilaian_nilai_tambah (Bab 8e) sebagai komponen resmi ber-bobot,
-- bukan lagi bonus poin mentah yang menempel di tabel ini.
create table penilaian_presentasi (
  id uuid primary key default uuid_generate_v4(),
  peserta_id uuid not null references peserta(id) on delete cascade,
  juri_id uuid not null references profiles(id),
  catatan text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (peserta_id, juri_id)
);

create table penilaian_presentasi_detail (
  id uuid primary key default uuid_generate_v4(),
  peserta_id uuid not null references peserta(id) on delete cascade,
  kriteria_id uuid not null references kriteria_presentasi(id),
  juri_id uuid not null references profiles(id),
  skor numeric(5,2) not null check (skor >= 0 and skor <= 100),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (peserta_id, kriteria_id, juri_id)
);

-- Skor per SUB-ITEM rubrik presentasi. Baris di tabel penilaian_presentasi_detail
-- di atas diisi/dihitung OTOMATIS oleh aplikasi sebagai agregat dari tabel ini,
-- sehingga Dewan Juri cukup mengisi angka per item konkret.
create table penilaian_presentasi_subdetail (
  id uuid primary key default uuid_generate_v4(),
  peserta_id uuid not null references peserta(id) on delete cascade,
  sub_kriteria_id uuid not null references sub_kriteria_presentasi(id),
  juri_id uuid not null references profiles(id),
  skor numeric(5,2) not null check (skor >= 0),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (peserta_id, sub_kriteria_id, juri_id)
);

-- ---------------------------------------------------------------------
-- 10. VIEW BANTUAN — Rekap Nilai Akhir (dipakai Laporan & Leaderboard)
-- ---------------------------------------------------------------------

-- 10a. Nilai Rubrik Kompetensi Kategori (0-100), dari Tim Pemeriksa Berkas
create or replace view v_rekap_nilai_kompetensi
with (security_invoker = true) as
select
  p.id as peserta_id,
  round(sum(pb.skor * kp.bobot / 100.0) / greatest(count(distinct pb.pemeriksa_id),1), 2) as nilai_kompetensi
from peserta p
join penilaian_berkas pb on pb.peserta_id = p.id
join kriteria_penilaian kp on kp.id = pb.kriteria_id
group by p.id;

-- 10b. Nilai Rubrik Feature Diri (0-100), dari Tim Pemeriksa Berkas
create or replace view v_rekap_nilai_feature
with (security_invoker = true) as
select
  p.id as peserta_id,
  round(sum(pf.skor * kf.bobot / 100.0) / greatest(count(distinct pf.pemeriksa_id),1), 2) as nilai_feature
from peserta p
join penilaian_feature pf on pf.peserta_id = p.id
join kriteria_feature kf on kf.id = pf.kriteria_id
group by p.id;

-- 10c. Nilai Berkas gabungan = 60% Kompetensi + 40% Feature (bobot dari app_settings)
create or replace view v_rekap_nilai_berkas
with (security_invoker = true) as
select
  p.id as peserta_id,
  round(
    coalesce(vk.nilai_kompetensi, 0) * (select (value#>>'{}')::numeric from app_settings where key='bobot_kompetensi_dalam_berkas')
    + coalesce(vf.nilai_feature, 0) * (select (value#>>'{}')::numeric from app_settings where key='bobot_feature_dalam_berkas')
  , 2) as nilai_berkas
from peserta p
left join v_rekap_nilai_kompetensi vk on vk.peserta_id = p.id
left join v_rekap_nilai_feature vf on vf.peserta_id = p.id;

-- 10d. Nilai Presentasi & Wawancara (0-100), dari Dewan Juri — TIDAK LAGI
-- mengandung bonus bahasa asing (lihat 10e untuk itu)
create or replace view v_rekap_nilai_presentasi
with (security_invoker = true) as
select
  ppd.peserta_id,
  round(sum(ppd.skor * kp.bobot / 100.0) / greatest(count(distinct ppd.juri_id),1), 2) as nilai_presentasi
from penilaian_presentasi_detail ppd
join kriteria_presentasi kp on kp.id = ppd.kriteria_id
group by ppd.peserta_id;

-- 10e. Nilai Tambah (0-100), dari Dewan Juri
create or replace view v_rekap_nilai_tambah
with (security_invoker = true) as
select
  pnt.peserta_id,
  round(sum(pnt.skor * knt.bobot / 100.0) / greatest(count(distinct pnt.juri_id),1), 2) as nilai_tambah
from penilaian_nilai_tambah pnt
join kriteria_nilai_tambah knt on knt.id = pnt.kriteria_id
group by pnt.peserta_id;

-- 10f. Nilai Akhir = 35% Berkas + 50% Presentasi + 15% Nilai Tambah
create or replace view v_nilai_akhir
with (security_invoker = true) as
select
  p.id as peserta_id,
  p.nama_lengkap,
  p.kategori_id,
  k.nama as kategori_nama,
  kk.nama as kabkota_nama,
  coalesce(vb.nilai_berkas, 0) as nilai_berkas,
  coalesce(vp.nilai_presentasi, 0) as nilai_presentasi,
  coalesce(vt.nilai_tambah, 0) as nilai_tambah,
  round(
    coalesce(vb.nilai_berkas,0) * (select (value#>>'{}')::numeric from app_settings where key='bobot_nilai_berkas')
    + coalesce(vp.nilai_presentasi,0) * (select (value#>>'{}')::numeric from app_settings where key='bobot_nilai_grandfinal')
    + coalesce(vt.nilai_tambah,0) * (select (value#>>'{}')::numeric from app_settings where key='bobot_nilai_tambah')
  , 2) as nilai_akhir
from peserta p
join kategori_lomba k on k.id = p.kategori_id
join kabupaten_kota kk on kk.id = p.kabkota_id
left join v_rekap_nilai_berkas vb on vb.peserta_id = p.id
left join v_rekap_nilai_presentasi vp on vp.peserta_id = p.id
left join v_rekap_nilai_tambah vt on vt.peserta_id = p.id;

-- View rekap jumlah peserta per mata lomba (murni informatif untuk dashboard
-- Admin Provinsi memantau progres pendaftaran -- TIDAK ada ambang batas/
-- eliminasi, seluruh mata lomba selalu dilaksanakan)
create or replace view v_rekap_peserta_kategori
with (security_invoker = true) as
select
  k.id as kategori_id,
  k.nama,
  k.klaster,
  count(p.id) as jumlah_peserta
from kategori_lomba k
left join peserta p on p.kategori_id = k.id
group by k.id, k.nama, k.klaster;

-- =====================================================================
-- 11. ROW LEVEL SECURITY (RLS)
-- =====================================================================
alter table app_settings enable row level security;
alter table kabupaten_kota enable row level security;
alter table kategori_lomba enable row level security;
alter table kriteria_penilaian enable row level security;
alter table sub_kriteria_penilaian enable row level security;
alter table profiles enable row level security;
alter table peserta enable row level security;
alter table berkas_peserta enable row level security;
alter table penilaian_berkas enable row level security;
alter table penilaian_berkas_detail enable row level security;
alter table kriteria_presentasi enable row level security;
alter table sub_kriteria_presentasi enable row level security;
alter table penilaian_presentasi enable row level security;
alter table penilaian_presentasi_detail enable row level security;
alter table penilaian_presentasi_subdetail enable row level security;
alter table kriteria_feature enable row level security;
alter table sub_kriteria_feature enable row level security;
alter table penilaian_feature enable row level security;
alter table penilaian_feature_detail enable row level security;
alter table kriteria_nilai_tambah enable row level security;
alter table penilaian_nilai_tambah enable row level security;

-- Helper: fungsi ambil role & kabkota_id user yang sedang login
create or replace function my_role() returns text as $$
  select role from profiles where id = auth.uid();
$$ language sql stable security definer set search_path = public;

create or replace function my_kabkota() returns int as $$
  select kabkota_id from profiles where id = auth.uid();
$$ language sql stable security definer set search_path = public;

-- Hanya boleh dipakai INTERNAL oleh RLS policy (dievaluasi sbg role
-- 'authenticated'), bukan dipanggil publik sbg RPC endpoint sendiri.
revoke execute on function my_role() from public, anon;
revoke execute on function my_kabkota() from public, anon;
grant execute on function my_role() to authenticated;
grant execute on function my_kabkota() to authenticated;

-- --- Data referensi & config: semua role login boleh baca, hanya admin_provinsi boleh ubah
create policy "read_all_authenticated" on app_settings for select using (auth.role() = 'authenticated');
create policy "write_admin_provinsi" on app_settings for all using (my_role() = 'admin_provinsi');

create policy "read_all_authenticated" on kabupaten_kota for select using (auth.role() = 'authenticated');

create policy "read_all_authenticated" on kategori_lomba for select using (auth.role() = 'authenticated');
create policy "write_admin_provinsi" on kategori_lomba for insert with check (my_role() = 'admin_provinsi');
create policy "update_admin_provinsi" on kategori_lomba for update using (my_role() = 'admin_provinsi');

create policy "read_all_authenticated" on kriteria_penilaian for select using (auth.role() = 'authenticated');
create policy "write_admin_provinsi" on kriteria_penilaian for all using (my_role() = 'admin_provinsi');

-- --- Sub-item rubrik berkas: pola sama seperti kriteria_penilaian
create policy "read_all_authenticated" on sub_kriteria_penilaian for select using (auth.role() = 'authenticated');
create policy "write_admin_provinsi" on sub_kriteria_penilaian for all using (my_role() = 'admin_provinsi');

-- --- Profiles: user lihat profil sendiri; admin_provinsi lihat & kelola semua
create policy "read_own_profile" on profiles for select using (id = auth.uid() or my_role() = 'admin_provinsi');
create policy "admin_manage_profiles" on profiles for all using (my_role() = 'admin_provinsi');

-- --- Peserta: admin_kabkota hanya kelola peserta kabupatennya sendiri;
--     pemeriksa_berkas/juri/panitia/admin_provinsi boleh baca semua
create policy "kabkota_view_own" on peserta for select
  using (my_role() = 'admin_kabkota' and kabkota_id = my_kabkota());
create policy "peserta_manage_own" on peserta for all
  using (my_role() = 'peserta' and akun_id = auth.uid())
  with check (my_role() = 'peserta' and akun_id = auth.uid());
create policy "provinsi_manage_all" on peserta for all using (my_role() = 'admin_provinsi');
create policy "readonly_roles" on peserta for select
  using (my_role() in ('pemeriksa_berkas','juri','panitia'));
-- Tim Pemeriksa Berkas perlu izin UPDATE (menetapkan status_verifikasi
-- Lengkap/Tidak Lengkap) -- ini tugas inti mereka, bukan cuma lihat.
create policy "pemeriksa_update_status_verifikasi" on peserta for update
  using (my_role() = 'pemeriksa_berkas')
  with check (my_role() = 'pemeriksa_berkas');
-- Panitia perlu izin UPDATE (menetapkan status_final Juara/Harapan) --
-- ini tugas inti mereka di laporan.html, bukan cuma lihat.
create policy "panitia_update_status_final" on peserta for update
  using (my_role() = 'panitia')
  with check (my_role() = 'panitia');

-- --- Berkas: sama pola dengan peserta (mengikuti kepemilikan peserta)
create policy "kabkota_view_own_berkas" on berkas_peserta for select
  using (exists (select 1 from peserta p where p.id = berkas_peserta.peserta_id
                 and my_role() = 'admin_kabkota' and p.kabkota_id = my_kabkota()));
create policy "peserta_manage_own_berkas" on berkas_peserta for all
  using (exists (select 1 from peserta p where p.id = berkas_peserta.peserta_id
                 and my_role() = 'peserta' and p.akun_id = auth.uid()))
  with check (exists (select 1 from peserta p where p.id = berkas_peserta.peserta_id
                 and my_role() = 'peserta' and p.akun_id = auth.uid()));
create policy "provinsi_all_berkas" on berkas_peserta for all using (my_role() = 'admin_provinsi');
create policy "readonly_berkas" on berkas_peserta for select
  using (my_role() in ('pemeriksa_berkas','juri','panitia'));

-- --- Penilaian berkas: hanya pemeriksa_berkas boleh isi nilai (miliknya sendiri);
--     admin_provinsi & panitia boleh baca semua utk rekap
create policy "pemeriksa_insert_own" on penilaian_berkas for insert
  with check (my_role() = 'pemeriksa_berkas' and pemeriksa_id = auth.uid());
create policy "pemeriksa_update_own" on penilaian_berkas for update
  using (my_role() = 'pemeriksa_berkas' and pemeriksa_id = auth.uid());
create policy "pemeriksa_read_own" on penilaian_berkas for select
  using (pemeriksa_id = auth.uid() or my_role() in ('admin_provinsi','panitia'));

-- --- Penilaian berkas detail (sub-item): pola sama
create policy "pemeriksa_insert_own_detail" on penilaian_berkas_detail for insert
  with check (my_role() = 'pemeriksa_berkas' and pemeriksa_id = auth.uid());
create policy "pemeriksa_update_own_detail" on penilaian_berkas_detail for update
  using (my_role() = 'pemeriksa_berkas' and pemeriksa_id = auth.uid());
create policy "pemeriksa_read_own_detail" on penilaian_berkas_detail for select
  using (pemeriksa_id = auth.uid() or my_role() in ('admin_provinsi','panitia'));

-- --- Rubrik presentasi: semua role login boleh baca, hanya admin_provinsi boleh ubah
create policy "read_all_authenticated" on kriteria_presentasi for select using (auth.role() = 'authenticated');
create policy "write_admin_provinsi" on kriteria_presentasi for all using (my_role() = 'admin_provinsi');

-- --- Sub-item rubrik presentasi: pola sama
create policy "read_all_authenticated" on sub_kriteria_presentasi for select using (auth.role() = 'authenticated');
create policy "write_admin_provinsi" on sub_kriteria_presentasi for all using (my_role() = 'admin_provinsi');

-- --- Penilaian presentasi: pola sama, khusus juri
create policy "juri_insert_own" on penilaian_presentasi for insert
  with check (my_role() = 'juri' and juri_id = auth.uid());
create policy "juri_update_own" on penilaian_presentasi for update
  using (my_role() = 'juri' and juri_id = auth.uid());
create policy "juri_read_own" on penilaian_presentasi for select
  using (juri_id = auth.uid() or my_role() in ('admin_provinsi','panitia'));

-- --- Penilaian presentasi detail (rubrik berindikator): pola sama
create policy "juri_insert_own_detail" on penilaian_presentasi_detail for insert
  with check (my_role() = 'juri' and juri_id = auth.uid());
create policy "juri_update_own_detail" on penilaian_presentasi_detail for update
  using (my_role() = 'juri' and juri_id = auth.uid());
create policy "juri_read_own_detail" on penilaian_presentasi_detail for select
  using (juri_id = auth.uid() or my_role() in ('admin_provinsi','panitia'));

-- --- Penilaian presentasi sub-detail (rincian per item): pola sama
create policy "juri_insert_own_subdetail" on penilaian_presentasi_subdetail for insert
  with check (my_role() = 'juri' and juri_id = auth.uid());
create policy "juri_update_own_subdetail" on penilaian_presentasi_subdetail for update
  using (my_role() = 'juri' and juri_id = auth.uid());
create policy "juri_read_own_subdetail" on penilaian_presentasi_subdetail for select
  using (juri_id = auth.uid() or my_role() in ('admin_provinsi','panitia'));

-- --- Rubrik & penilaian Feature Diri: pola sama seperti rubrik berkas/presentasi
create policy "read_all_authenticated" on kriteria_feature for select using (auth.role() = 'authenticated');
create policy "write_admin_provinsi" on kriteria_feature for all using (my_role() = 'admin_provinsi');
create policy "read_all_authenticated" on sub_kriteria_feature for select using (auth.role() = 'authenticated');
create policy "write_admin_provinsi" on sub_kriteria_feature for all using (my_role() = 'admin_provinsi');

create policy "pemeriksa_insert_own_feature" on penilaian_feature for insert
  with check (my_role() = 'pemeriksa_berkas' and pemeriksa_id = auth.uid());
create policy "pemeriksa_update_own_feature" on penilaian_feature for update
  using (my_role() = 'pemeriksa_berkas' and pemeriksa_id = auth.uid());
create policy "pemeriksa_read_own_feature" on penilaian_feature for select
  using (pemeriksa_id = auth.uid() or my_role() in ('admin_provinsi','panitia'));

create policy "pemeriksa_insert_own_feature_detail" on penilaian_feature_detail for insert
  with check (my_role() = 'pemeriksa_berkas' and pemeriksa_id = auth.uid());
create policy "pemeriksa_update_own_feature_detail" on penilaian_feature_detail for update
  using (my_role() = 'pemeriksa_berkas' and pemeriksa_id = auth.uid());
create policy "pemeriksa_read_own_feature_detail" on penilaian_feature_detail for select
  using (pemeriksa_id = auth.uid() or my_role() in ('admin_provinsi','panitia'));

-- --- Rubrik & penilaian Nilai Tambah: dinilai Dewan Juri
create policy "read_all_authenticated" on kriteria_nilai_tambah for select using (auth.role() = 'authenticated');
create policy "write_admin_provinsi" on kriteria_nilai_tambah for all using (my_role() = 'admin_provinsi');

create policy "juri_insert_own_tambah" on penilaian_nilai_tambah for insert
  with check (my_role() = 'juri' and juri_id = auth.uid());
create policy "juri_update_own_tambah" on penilaian_nilai_tambah for update
  using (my_role() = 'juri' and juri_id = auth.uid());
create policy "juri_read_own_tambah" on penilaian_nilai_tambah for select
  using (juri_id = auth.uid() or my_role() in ('admin_provinsi','panitia'));

-- =====================================================================
-- SISTEM TOKEN REGISTRASI PESERTA
-- Setiap peserta punya akun login sendiri, didaftarkan via token yang
-- di-generate Admin Provinsi (terkunci ke 1 slot kab/kota + mata lomba).
-- =====================================================================
create table token_registrasi (
  id uuid primary key default uuid_generate_v4(),
  token text not null unique,
  kabkota_id int not null references kabupaten_kota(id),
  kategori_id uuid not null references kategori_lomba(id),
  status text not null default 'belum_dipakai' check (status in ('belum_dipakai','sudah_dipakai')),
  peserta_id uuid references peserta(id),
  dibuat_oleh uuid references profiles(id),
  created_at timestamptz default now(),
  used_at timestamptz,
  unique (kabkota_id, kategori_id)
);

-- Generate token acak 8-karakter (hex, tanpa karakter ambigu) untuk
-- seluruh slot kab/kota x mata lomba sekaligus.
insert into token_registrasi (token, kabkota_id, kategori_id)
select
  upper(substr(md5(kk.id::text || kl.id::text || clock_timestamp()::text || random()::text), 1, 8)),
  kk.id, kl.id
from kabupaten_kota kk
cross join kategori_lomba kl;

-- Fungsi atomik pendaftaran via token -- dipanggil peserta SETELAH
-- berhasil signup (sb.auth.signUp), memakai sesi yg baru terbentuk.
-- SECURITY DEFINER supaya bisa menulis ke profiles/peserta/token_registrasi
-- meski role 'peserta' sendiri tidak diberi izin INSERT langsung ke situ.
create or replace function daftar_dengan_token(p_token text, p_nama_lengkap text, p_email text default null)
returns json as $$
declare
  v_token record;
  v_peserta_id uuid;
  v_status text;
  v_mulai timestamptz;
  v_tutup timestamptz;
begin
  -- Gerbang tanggal: tolak pendaftaran di luar jendela waktu resmi,
  -- meski seseorang mencoba memanggil fungsi ini langsung (bukan lewat UI).
  select (value#>>'{}') into v_status from app_settings where key = 'status_pendaftaran';
  select (value#>>'{}')::timestamptz into v_mulai from app_settings where key = 'tanggal_mulai_pendaftaran';
  select (value#>>'{}')::timestamptz into v_tutup from app_settings where key = 'tanggal_tutup_pendaftaran';

  if v_status is distinct from 'buka' or now() < v_mulai or now() > v_tutup then
    raise exception 'Pendaftaran sedang tidak dibuka. Jendela pendaftaran: % s.d. %', v_mulai, v_tutup;
  end if;

  select * into v_token from token_registrasi
    where token = p_token and status = 'belum_dipakai'
    for update;

  if not found then
    raise exception 'Token tidak valid atau sudah digunakan';
  end if;

  if exists (select 1 from profiles where id = auth.uid()) then
    raise exception 'Akun ini sudah terdaftar sebelumnya';
  end if;

  insert into profiles (id, nama, role, kabkota_id, aktif)
  values (auth.uid(), p_nama_lengkap, 'peserta', v_token.kabkota_id, true);

  -- simpan email login (p_email) langsung ke biodata peserta, supaya Admin
  -- Kab/Kota bisa membantu peserta yg lupa memakai email apa saat daftar.
  insert into peserta (kabkota_id, kategori_id, nama_lengkap, akun_id, email)
  values (v_token.kabkota_id, v_token.kategori_id, p_nama_lengkap, auth.uid(), p_email)
  returning id into v_peserta_id;

  update token_registrasi set status = 'sudah_dipakai', peserta_id = v_peserta_id, used_at = now()
  where id = v_token.id;

  return json_build_object('peserta_id', v_peserta_id, 'kategori_id', v_token.kategori_id, 'kabkota_id', v_token.kabkota_id);
end;
$$ language plpgsql security definer set search_path = public;

revoke execute on function daftar_dengan_token(text, text, text) from public, anon;
grant execute on function daftar_dengan_token(text, text, text) to authenticated;

alter table token_registrasi enable row level security;
create policy "provinsi_manage_tokens" on token_registrasi for all using (my_role() = 'admin_provinsi');
create policy "kabkota_view_own_tokens" on token_registrasi for select
  using (my_role() = 'admin_kabkota' and kabkota_id = my_kabkota());

-- Fungsi aman utk mengecek validitas 1 token spesifik TANPA membuka akses
-- baca ke seluruh tabel token_registrasi bagi publik.
create or replace function cek_token(p_token text)
returns json as $$
declare
  v_token record;
begin
  select t.status, kk.nama as kabkota_nama, kl.nama as kategori_nama
  into v_token
  from token_registrasi t
  join kabupaten_kota kk on kk.id = t.kabkota_id
  join kategori_lomba kl on kl.id = t.kategori_id
  where t.token = p_token;

  if not found then
    return json_build_object('valid', false, 'pesan', 'Token tidak ditemukan');
  end if;

  if v_token.status = 'sudah_dipakai' then
    return json_build_object('valid', false, 'pesan', 'Token sudah digunakan untuk mendaftar sebelumnya');
  end if;

  return json_build_object('valid', true, 'kabkota', v_token.kabkota_nama, 'kategori', v_token.kategori_nama);
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function cek_token(text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- JADWAL PELAKSANAAN (tabel publik, tampil di index.html & registrasi.html
-- sebelum login) + jendela waktu pendaftaran
-- ---------------------------------------------------------------------
create table jadwal_kegiatan (
  id uuid primary key default uuid_generate_v4(),
  urutan int not null default 0,
  kegiatan text not null,
  tanggal text not null,       -- teks bebas spt "Minggu I - III September 2026"
  keterangan text,
  created_at timestamptz default now()
);

insert into jadwal_kegiatan (urutan, kegiatan, tanggal, keterangan) values
  (1, 'Pendaftaran & Registrasi Mandiri Peserta', 'Minggu I – IV September 2026', 'Melalui token dari Kankemenag Kab/Kota'),
  (2, 'Verifikasi & Penilaian Berkas', 'Oktober 2026', 'Oleh Tim Pemeriksa Berkas'),
  (3, 'Presentasi, Wawancara & Malam Anugerah GTKPRESA 2026', 'Minggu I November 2026', 'Tatap muka di Banda Aceh + Pengumuman Juara');

alter table jadwal_kegiatan enable row level security;
create policy "publik_baca_jadwal" on jadwal_kegiatan for select using (true);
create policy "provinsi_kelola_jadwal" on jadwal_kegiatan for all using (my_role() = 'admin_provinsi');

-- Fungsi publik (anon) utk cek status & jendela waktu pendaftaran, tanpa
-- perlu expose seluruh tabel app_settings (yg berisi bobot nilai dsb) ke publik.
create or replace function get_info_pendaftaran()
returns json as $$
declare
  v_status text;
  v_mulai timestamptz;
  v_tutup timestamptz;
begin
  select (value#>>'{}') into v_status from app_settings where key = 'status_pendaftaran';
  select (value#>>'{}')::timestamptz into v_mulai from app_settings where key = 'tanggal_mulai_pendaftaran';
  select (value#>>'{}')::timestamptz into v_tutup from app_settings where key = 'tanggal_tutup_pendaftaran';

  return json_build_object(
    'status_manual', v_status,
    'tanggal_mulai', v_mulai,
    'tanggal_tutup', v_tutup,
    'sekarang', now(),
    'sedang_buka', (v_status = 'buka' and now() >= v_mulai and now() <= v_tutup)
  );
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function get_info_pendaftaran() to anon, authenticated;

-- ---------------------------------------------------------------------
-- BUCKET STORAGE PUBLIK utk dokumen resmi (Juknis, dst). Boleh dibaca
-- siapa saja (termasuk sblm login), hanya Admin Provinsi yg boleh
-- unggah/ganti/hapus lewat panel admin.html (tab Pengaturan).
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('dokumen', 'dokumen', true, 10485760, array['application/pdf'])
on conflict (id) do nothing;

create policy "publik_baca_dokumen" on storage.objects for select
  using (bucket_id = 'dokumen');

create policy "provinsi_unggah_dokumen" on storage.objects for insert
  with check (bucket_id = 'dokumen' and my_role() = 'admin_provinsi');

create policy "provinsi_ubah_dokumen" on storage.objects for update
  using (bucket_id = 'dokumen' and my_role() = 'admin_provinsi');

create policy "provinsi_hapus_dokumen" on storage.objects for delete
  using (bucket_id = 'dokumen' and my_role() = 'admin_provinsi');

-- ---------------------------------------------------------------------
-- KAB/KOTA & TOKEN CONTOH (UJI COBA) -- terpisah total dari 23 kab/kota
-- sungguhan, supaya Admin Provinsi bisa tes alur registrasi mandiri
-- bolak-balik tanpa mengganggu token peserta asli.
-- ---------------------------------------------------------------------
insert into kabupaten_kota (nama, kode) values
  ('[CONTOH/UJI COBA] Bukan Kab/Kota Sungguhan', 'DEMO')
on conflict (nama) do nothing;

insert into token_registrasi (token, kabkota_id, kategori_id)
select
  'DEMO' || upper(substr(md5(kl.id::text || clock_timestamp()::text || random()::text), 1, 4)),
  (select id from kabupaten_kota where kode = 'DEMO'),
  kl.id
from kategori_lomba kl
where not exists (
  select 1 from token_registrasi t
  where t.kategori_id = kl.id and t.kabkota_id = (select id from kabupaten_kota where kode = 'DEMO')
);

-- Fungsi reset sekali klik: hapus peserta contoh + akun loginnya, kembalikan
-- token DEMO ke status belum_dipakai.
create or replace function reset_data_demo()
returns json as $$
declare
  v_demo_kabkota_id int;
  v_akun_ids uuid[];
  v_jumlah int;
begin
  if my_role() <> 'admin_provinsi' then
    raise exception 'Hanya Admin Provinsi yang boleh melakukan reset data contoh';
  end if;

  select id into v_demo_kabkota_id from kabupaten_kota where kode = 'DEMO';

  select array_agg(akun_id) into v_akun_ids from peserta where kabkota_id = v_demo_kabkota_id and akun_id is not null;
  v_jumlah := coalesce(array_length(v_akun_ids, 1), 0);

  update token_registrasi set status = 'belum_dipakai', peserta_id = null, used_at = null
  where kabkota_id = v_demo_kabkota_id;

  delete from peserta where kabkota_id = v_demo_kabkota_id;

  if v_akun_ids is not null then
    delete from profiles where id = any(v_akun_ids);
    delete from auth.users where id = any(v_akun_ids);
  end if;

  return json_build_object('jumlah_akun_direset', v_jumlah);
end;
$$ language plpgsql security definer set search_path = public;

revoke execute on function reset_data_demo() from public, anon;
grant execute on function reset_data_demo() to authenticated;

-- ---------------------------------------------------------------------
-- BUCKET ASET VISUAL (logo, dst) + PENGATURAN PENANDATANGAN SERTIFIKAT
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('aset', 'aset', true, 5242880, array['image/png','image/jpeg','image/svg+xml'])
on conflict (id) do nothing;

create policy "publik_baca_aset" on storage.objects for select
  using (bucket_id = 'aset');
create policy "provinsi_unggah_aset" on storage.objects for insert
  with check (bucket_id = 'aset' and my_role() = 'admin_provinsi');
create policy "provinsi_ubah_aset" on storage.objects for update
  using (bucket_id = 'aset' and my_role() = 'admin_provinsi');
create policy "provinsi_hapus_aset" on storage.objects for delete
  using (bucket_id = 'aset' and my_role() = 'admin_provinsi');

insert into app_settings (key, value, keterangan) values
  ('sertifikat_nama_penandatangan', '""', 'Nama pejabat penandatangan Sertifikat/Piagam (kosongkan dulu jika belum pasti)'),
  ('sertifikat_jabatan_penandatangan', '""', 'Jabatan pejabat penandatangan Sertifikat/Piagam')
on conflict (key) do nothing;

-- =====================================================================
-- SELESAI. Setelah dijalankan di Supabase SQL Editor:
-- 1) Buat user pertama (admin_provinsi) lewat Supabase Auth, lalu insert
--    manual 1 baris ke tabel `profiles` dengan role='admin_provinsi'.
-- 2) Admin_provinsi login ke admin.html untuk menambah akun kab/kota,
--    pemeriksa berkas, dan dewan juri melalui panel (atau lewat
--    Supabase Auth dashboard + insert ke profiles).
-- 3) Bagikan token dari tabel token_registrasi ke tiap kab/kota supaya
--    peserta bisa daftar akun sendiri lewat registrasi.html.
-- 4) PENTING: fitur "Reset Password Peserta (Tanpa Email)" di admin.html
--    butuh Edge Function bernama "admin-reset-password" yang di-deploy
--    TERPISAH dari file SQL ini (lewat Supabase CLI/Dashboard atau
--    dashboard Functions). Tanpa Edge Function ini, panel token/reset
--    password tetap tampil tapi tombol "Ganti Kata Sandi" akan gagal.
-- =====================================================================
