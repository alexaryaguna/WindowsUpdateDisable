# Windows Update Disable

Repository ini berisi dua file alat bantu sederhana untuk **mematikan secara paksa (permanen)** dan **menghidupkan kembali** sistem Windows Update di komputer atau laptop Anda.

Sangat cocok digunakan jika Anda merasa terganggu dengan update Windows yang tiba-tiba berjalan sendiri, memakan kuota internet, dan membuat kinerja komputer menjadi lambat.

## 🌟 Fitur Unggulan
Berbeda dengan cara biasa, script ini memblokir Windows dari segala arah agar tidak bisa melakukan update diam-diam:
- **Anti Pemulihan Otomatis (Anti Self-Healing):** Menghapus kemampuan Windows untuk menghidupkan kembali layanan update secara otomatis.
- **Pengunci Gudang Download:** Menghancurkan dan mengunci paksa folder tempat Windows meletakkan file update (`SoftwareDistribution`), sehingga tidak ada ruang untuk mendownload.
- **Blackhole & Firewall Block:** Memutus jalur koneksi internet ke server Microsoft (membuat servernya seolah-olah "nyasar") dan menahannya di Firewall bawaan.
- **Sembunyikan Tombol Update:** Menghilangkan menu Windows Update dari Pengaturan (Settings) dan menghapus tombol "Update and Restart" berwarna oranye di Start Menu.
- **Microsoft Store Auto-Update Blocker:** Mencegah Windows mengunduh pembaruan komponen sistem secara diam-diam melalui jalur belakang aplikasi Microsoft Store.
- **Pembungkam Notifikasi Total:** Menghilangkan semua peringatan, pop-up, tanda seru, dan pesan yang mengganggu terkait hilangnya Windows Update.
- **Aman Dikembalikan 100%:** Jika Anda butuh update lagi, script "Enable" akan membatalkan semua blokade ini tanpa membuat sistem error.

---

## 📁 Penjelasan File

1. **`Disable-WinUpdate.ps1`**
   Gunakan file ini untuk **MEMATIKAN** Windows Update secara total dan permanen. 

2. **`Enable-WinUpdate.ps1`**
   Gunakan file ini untuk **MENGHIDUPKAN** kembali Windows Update.
   *(Gunakan jika suatu saat Anda butuh memperbarui sistem atau ingin mendownload aplikasi dari Microsoft Store).*

---

## 💻 OS (Sistem Operasi) yang Didukung
Bisa digunakan di semua versi Windows (32-bit & 64-bit):
- **Windows 7**
- **Windows 10**
- **Windows 11**

---

## 🚀 Cara Penggunaan (Sangat Mudah!)

Anda tidak perlu mengerti bahasa pemrograman sama sekali. Cukup ikuti langkah berikut:

1. **Download (Unduh) file** dari GitHub ini ke komputer/laptop Anda.
2. Cari file yang sudah didownload, lalu **Klik Kanan** pada file tersebut (`Disable-WinUpdate.ps1` atau `Enable-WinUpdate.ps1`).
3. Pilih menu **"Run with PowerShell"**.
4. Jika muncul layar peringatan (meminta izin Admin / *UAC*), klik tombol **"Yes"**.
5. Layar hitam (PowerShell) akan muncul. Biarkan proses berjalan sendiri.
6. Jika di layar sudah muncul tulisan hijau **"PROSES SELESAI"**, silakan tekan tombol Enter.
7. **Wajib:** Restart (Matikan dan hidupkan ulang) komputer/laptop Anda agar efeknya langsung aktif!

---
*Catatan: Segala risiko akibat mematikan pembaruan keamanan OS adalah tanggung jawab pengguna masing-masing.*