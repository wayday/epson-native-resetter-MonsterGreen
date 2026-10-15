# Panduan Lengkap Aplikasi Resetter Epson Native (Flutter)

Aplikasi ini dibuat khusus untuk menyelesaikan masalah gagalnya WebUSB di WebView atau browser dengan mengakses USB controller printer Epson secara **native langsung**.

---

### Mengapa WebUSB Gagal di Browser / WebView?
1. **Kebijakan Keamanan WebView**: Di Android, komponen WebView secara default menonaktifkan API `navigator.usb`.
2. **Klaim Driver Windows (usbprint.sys)**: Di Windows, begitu printer dicolok, sistem operasi langsung mengunci endpoint USB melalui `usbprint.sys` sehingga browser WebUSB dilarang membuka port secara eksklusif (menghasilkan error `SecurityError: Access Denied`).
3. **Solusi Native**: Aplikasi Flutter ini menggunakan **Android USB Host API** (pada HP) dan **libusb** (pada Windows/Linux) yang meminta izin level sistem untuk mengambil alih endpoint printer.

---

### Cara Menjalankan di Android (Kabel OTG) - CARA TERMUDAH
1. **Persyaratan**:
   - HP / Tablet Android dengan fitur OTG.
   - Kabel adapter USB OTG (Type-C ke USB-A Female).
   - Kabel USB bawaan printer Epson (L120, L3110, dll).

2. **Langkah Build APK**:
   ```bash
   # Masuk ke direktori project flutter
   flutter pub get
   flutter build apk --release
   ```
3. **Install APK di HP**:
   - Salin file `build/app/outputs/flutter-apk/app-release.apk` ke HP.
   - Install dan buka aplikasi.
4. **Hubungkan & Reset**:
   - Colok kabel printer ke HP melalui kabel OTG.
   - Akan muncul popup Android: *"Izinkan aplikasi mengakses perangkat USB Epson?"* -> Klik **OK / Selalu Izinkan**.
   - Pilih tipe printer (contoh: **Epson L120**).
   - Klik **Sambungkan USB OTG**.
   - Klik **Check Counter** (akan membaca nilai point, misal 6245 pts / 100%).
   - Klik **Initialize (Reset)** -> Klik Ya.
   - **PENTING**: Matikan printer dengan tombol Power, tunggu 5 detik, lalu hidupkan kembali!
   - Lampu merah printer akan normal dan siap mencetak kembali.

---

### Cara Menjalankan di Windows Desktop
1. Pastikan Flutter Desktop Windows aktif:
   ```bash
   flutter config --enable-windows-desktop
   flutter run -d windows
   ```
2. Jika USB printer ditolak oleh driver Windows biasa, gunakan tool gratis **Zadig** (https://zadig.akeo.ie/) untuk mengganti driver interface printer ke **WinUSB** atau **libusb-win32**.
