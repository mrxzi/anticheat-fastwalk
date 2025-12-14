# Dokumentasi Anti-Cheat Speed Hack / Fast Walk

**Dibuat oleh:** Jaden  
**Anti-Cheat System untuk SA-MP**

## 📋 Deskripsi
Anti-cheat ini dirancang untuk mendeteksi dan mengeluarkan player yang menggunakan speed hack atau fast walk cheat. Sistem ini menggunakan deteksi real-time melalui `OnPlayerUpdate` dan timer backup untuk memastikan akurasi deteksi.

## 🚀 Instalasi

### 1. Include File
File `speed-hack.pwn` sudah otomatis ter-include jika Anda menggunakan sistem include yang terorganisir. Pastikan file ini ada di folder:
```
gamemodes/SERVER/anticheat/speed-hack.
tergantung gamodes kalian ya
```

### 2. Dependencies
File ini membutuhkan:
- `<a_samp>` - SA-MP standard includes
- `<YSI\y_hooks>` - YSI hooks system
- Variabel global: `AccountData[playerid][pSpawned]`, `AccountData[playerid][pFreeze]`
- Fungsi: `IsPlayerInWater()`, `IsPlayerInEvent()`, `SendAdminMessage()`, `ReturnName()`, `GetPlayerNameEx()`, `KickEx()`, `ShowTDN()`

## ⚙️ Konfigurasi

### Threshold Speed (Baris 23-24)
```pawn
#define MAX_ONFOOT_SPEED 42.0  // Threshold deteksi (km/h)
#define EXTREME_SPEED 55.0      // Langsung kick jika melebihi (km/h)
```

**Penjelasan:**
- **MAX_ONFOOT_SPEED (42.0 km/h)**: Speed minimum untuk mulai menghitung violations
  - Lari normal: ~15-22 km/h
  - Sprint maksimal: ~22 km/h
  - Threshold ini sudah sangat tinggi untuk menghindari false positive
  
- **EXTREME_SPEED (55.0 km/h)**: Speed yang langsung di-kick tanpa hitungan violations
  - Pasti speed hack, tidak mungkin dicapai secara normal

### Jumlah Violations (Baris 276 & 408)
```pawn
if(playerData[playerid][speedViolations] >= 15)
```
- **15 violations**: Jumlah pelanggaran berturut-turut sebelum di-kick
- Dapat disesuaikan sesuai kebutuhan (semakin tinggi = semakin toleran)

### Cooldown Setelah Lompat (Baris 103)
```pawn
if(playerData[playerid][wasJumping] && (GetTickCount() - playerData[playerid][lastJumpTime]) < 2500)
```
- **2500ms (2.5 detik)**: Waktu cooldown setelah lompat
- Sistem akan skip speed check selama cooldown untuk menghindari false positive

## 🔧 Cara Kerja

### 1. Deteksi Speed
Sistem menggunakan 2 metode deteksi:
- **Position-based**: Menghitung jarak perpindahan dalam waktu tertentu
- **Velocity-based**: Menggunakan `GetPlayerVelocity()` sebagai backup

Sistem akan menggunakan nilai **tertinggi** dari kedua metode untuk akurasi maksimal.

### 2. Deteksi Lompat
Sistem mendeteksi lompat melalui:
- **Velocity Z**: Pergerakan vertikal (naik/turun)
- **Animation Index**: Animasi lompat (1195, 1196, 1197, 1198, 1231, 1062, 1063)
- **Perubahan Posisi Z**: Perubahan tinggi posisi > 0.05 meter

### 3. Sistem Violations
- Jika speed > `MAX_ONFOOT_SPEED` tapi < `EXTREME_SPEED`: Violations +1
- Jika speed > `EXTREME_SPEED`: Langsung kick (tanpa violations)
- Jika speed normal: Violations -2 (reset agresif)
- Kick jika violations >= 15

### 4. Skip Conditions
Sistem akan **skip** speed check jika:
- Player tidak on foot atau belum spawn
- Player di air (water)
- Player freeze
- Player surfing vehicle (sedang ditarik)
- Player dalam event
- Player sedang lompat atau baru saja lompat (cooldown 2.5 detik)

## 📊 Flow Diagram

```
OnPlayerUpdate / CheckPlayerSpeedTimer
    ↓
Cek: On foot & Spawned?
    ↓ Ya
Cek: Skip conditions? (water, freeze, event, etc)
    ↓ Tidak
Hitung Speed (position + velocity)
    ↓
Cek: Speed < 1.0 km/h?
    ↓ Tidak
Cek: Sedang lompat atau baru lompat?
    ↓ Tidak
Cek: Speed > MAX_ONFOOT_SPEED (42 km/h)?
    ↓ Ya
Cek: Speed > EXTREME_SPEED (55 km/h)?
    ↓ Ya → Kick Langsung
    ↓ Tidak
Violations +1
    ↓
Cek: Violations >= 15?
    ↓ Ya → Kick
    ↓ Tidak → Continue
```

## 🛠️ Customization

### Mengubah Threshold
Jika ingin lebih ketat atau lebih longgar, edit baris 23-24:
```pawn
// Lebih ketat (deteksi lebih awal)
#define MAX_ONFOOT_SPEED 35.0
#define EXTREME_SPEED 45.0

// Lebih longgar (hanya deteksi speed hack ekstrem)
#define MAX_ONFOOT_SPEED 50.0
#define EXTREME_SPEED 65.0
```

### Mengubah Jumlah Violations
Edit baris 276 dan 408:
```pawn
// Lebih ketat (kick lebih cepat)
if(playerData[playerid][speedViolations] >= 10)

// Lebih longgar (butuh lebih banyak violations)
if(playerData[playerid][speedViolations] >= 20)
```

### Mengubah Cooldown Lompat
Edit baris 103:
```pawn
// Lebih pendek (1.5 detik)
if(playerData[playerid][wasJumping] && (GetTickCount() - playerData[playerid][lastJumpTime]) < 1500)

// Lebih panjang (3 detik)
if(playerData[playerid][wasJumping] && (GetTickCount() - playerData[playerid][lastJumpTime]) < 3000)
```

## 🐛 Troubleshooting

### Player Normal Terkena Kick
**Solusi:**
1. Naikkan `MAX_ONFOOT_SPEED` (misalnya ke 45-50 km/h)
2. Naikkan jumlah violations (misalnya ke 20)
3. Perpanjang cooldown lompat (misalnya ke 3000ms)

### Speed Hack Tidak Terdeteksi
**Solusi:**
1. Turunkan `MAX_ONFOOT_SPEED` (misalnya ke 35-38 km/h)
2. Turunkan jumlah violations (misalnya ke 10)
3. Pastikan timer backup aktif (200ms interval)

### False Positive Saat Lompat
**Solusi:**
1. Perpanjang cooldown lompat (misalnya ke 3000ms)
2. Periksa deteksi lompat di fungsi `IsPlayerInJumpState()`
3. Pastikan threshold velocity Z sudah tepat (0.005)

## 📝 Catatan Penting

1. **Admin juga akan terdeteksi** jika menggunakan speed hack (tidak ada bypass untuk admin)
2. **Timer backup** berjalan setiap 200ms untuk memastikan deteksi tidak terlewat
3. **Reset violations** sangat agresif (-2 per check) untuk mencegah akumulasi pada player normal
4. **Sistem dual detection** (position + velocity) untuk akurasi maksimal

## 📞 Support

Jika ada masalah atau pertanyaan:
- @saintyjin discord
---

**Versi:** 1.0  
**Dibuat oleh:** Jaden    
**Kompatibilitas:** SA-MP 0.3.7+, Pawn Compiler 3.10.7+
