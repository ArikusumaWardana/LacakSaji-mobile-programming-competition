# LacakSaji

Aplikasi mobile Android berbasis Flutter untuk pengawasan keamanan pangan dan pengendalian susut pangan (*food waste*) pada rantai distribusi Program Makan Bergizi Gratis (MBG), dirancang selaras dengan Peraturan Badan Gizi Nasional (Perbagi) No. 4 Tahun 2026.

## Ringkasan Proyek

LacakSaji berfungsi sebagai gerbang pencegahan dini (*pre-consumption gate*) antara dapur penyedia (Satuan Pelayanan Pemenuhan Gizi / SPPG) dan sekolah penerima. Aplikasi ini memastikan makanan yang sampai ke siswa masih berada dalam batas aman waktu-suhu, lolos uji organoleptik, memiliki arsip sampel 2x24 jam, serta mampu memicu peringatan darurat lintas sekolah secara cepat apabila ditemukan indikasi kerusakan pangan.

## Fitur Utama

- **Paspor QR Kriptografis Ed25519 (Offline-Verifiable):** Mengunci stempel waktu pengemasan (`sealed_at`) dari dapur dengan tanda tangan digital asimetris untuk mencegah manipulasi waktu (*anti-backdating*) dan tetap dapat diverifikasi saat sekolah tidak memiliki koneksi internet.
- **Danger-Zone Clock Berbasis Risiko dan Cuaca BMKG:** Menghitung batas aman distribusi secara dinamis berdasarkan kategori risiko menu (`HIGH`, `MEDIUM`, `LOW`), durasi perjalanan, dan data suhu wilayah kelurahan (`adm4`) dari API publik BMKG lengkap dengan *cache* dan *fallback* luring.
- **Audit Organoleptik Hibrida 3-Lapis:** Menggabungkan inferensi cepat *on-device* (TFLite INT8), analisis lanjutan *cloud* (Gemini Flash melalui Supabase Edge Function saat daring), serta *checklist* organoleptik manual oleh guru/PIC sekolah.
- **Brankas Bank Sampel 2x24 Jam:** Mencatat penyimpanan 1 porsi sampel arsip (< 5 derajat Celcius) beserta kode label unik dan pengingat lokal 48 jam sesuai regulasi uji laboratorium.
- **Cluster Alert Dual-Channel dan Laporan KLB 1-Ketuk:** Menyiarkan peringatan darurat *real-time* (Supabase Realtime dan FCM High-Priority) ke seluruh sekolah lain yang dipasok dapur SPPG yang sama, sekaligus menghasilkan PDF Berita Acara KLB untuk dikirim ke Puskesmas terdekat tanpa mengharuskan Puskesmas memasang aplikasi.
- **Plate-Waste Loop:** Memindai sisa makanan di ompreng siswa untuk mengevaluasi porsi yang tidak termakan dan membantu dapur SPPG mengurangi *food waste* harian.

## Aktor Pengguna

- **Petugas Dapur (SPPG):** Aktivasi akun berbasis daftar resmi (*whitelist*), menyetujui tautan sekolah binaan, menerbitkan QR segel *batch* harian, memantau distribusi, dan meninjau analitik sisa pangan.
- **Guru / PIC Sekolah:** Mendaftar dengan NPSN, memindai QR segel *batch*, menjalankan uji organoleptik hibrida, mencatat bank sampel 48 jam, memindai sisa makanan, serta memicu *Cluster Alert* dan mengirim PDF KLB ke Puskesmas.
- **Kurir dan Puskesmas (Non-Login):** Kurir menunjukkan kartu surat jalan/label QR, sedangkan Puskesmas menerima ringkasan darurat dan PDF Berita Acara KLB langsung melalui WhatsApp atau Email.
- **Pengawas BGN / Dinkes:** Akses *read-only* untuk pemantauan lintas dapur dan sekolah.

## Teknologi yang Digunakan

- **Frontend:** Flutter (Material Design 3), `go_router`, `flutter_riverpod`
- **Offline-First Storage & Sync:** `drift` (SQLite), `workmanager`, `connectivity_plus`
- **Kriptografi & QR:** `cryptography` (Ed25519), `qr_flutter`, `mobile_scanner`
- **Edge AI & Vision:** `tflite_flutter` (INT8 *on-device*), Gemini Flash API (via Supabase Edge Function)
- **Backend & Notifikasi:** Supabase (Auth, Postgres, Realtime, Storage, Edge Functions), Firebase Cloud Messaging (FCM), `flutter_local_notifications`
- **Data Cuaca & Utilitas:** API Publik BMKG (`adm4`), `geolocator`, `pdf`, `share_plus`, `url_launcher`
