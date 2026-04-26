# Windows Update Disable (Versi Ekstrem)

Repository ini berisi dua file alat bantu sederhana untuk **mematikan secara paksa (permanen)** dan **menghidupkan kembali** sistem Windows Update di komputer atau laptop Anda.

Sangat cocok digunakan jika Anda merasa terganggu dengan update Windows yang tiba-tiba berjalan sendiri dan membuat internet/komputer menjadi lambat.

## 📁 Penjelasan File

1. **`Disable-WinUpdate.ps1`**
   Gunakan file ini untuk **MEMATIKAN** Windows Update. 
   *(Script ini bekerja sangat kuat: ia akan mematikan layanan, memblokir akses internet ke server Microsoft, dan menyembunyikan tombol Update di pengaturan Anda).*

2. **`Enable-WinUpdate.ps1`**
   Gunakan file ini untuk **MENGHIDUPKAN** kembali Windows Update.
   *(Jika suatu saat Anda butuh update sistem atau download aplikasi dari Microsoft Store, jalankan file ini agar komputer Anda kembali normal 100%).*

---

## 💻 OS (Sistem Operasi) yang Didukung
Bisa digunakan di hampir semua versi Windows, baik yang versi lama maupun versi terbaru (32-bit & 64-bit):
- **Windows 7**
- **Windows 10**
- **Windows 11**

---

## 🚀 Cara Penggunaan (Sangat Mudah!)

Anda tidak perlu mengerti bahasa pemrograman/coding. Cukup ikuti 3 langkah berikut:

1. **Download (Unduh) file** ke komputer/laptop Anda.
2. Cari file yang sudah didownload, **Klik Kanan** pada file tersebut (`Disable-WinUpdate.ps1` atau `Enable-WinUpdate.ps1`).
3. Pilih menu **"Run with PowerShell"**.
4. Jika muncul layar peringatan berwarna biru/kuning dari Windows (meminta izin Admin), klik saja tombol **"Yes"**.
5. Layar hitam (PowerShell) akan muncul. Biarkan proses berjalan sendiri (sekitar 5-10 detik).
6. Jika di layar sudah muncul tulisan hijau **"PROSES SELESAI"**, silakan tekan tombol Enter.
7. **Wajib:** Restart (Matikan dan hidupkan ulang) komputer/laptop Anda agar perubahannya langsung aktif!

---
*Catatan: Segala risiko akibat mematikan sistem keamanan (update) adalah tanggung jawab pengguna masing-masing.*