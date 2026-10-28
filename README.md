# Nada Local

Pemutar musik lokal Hi-Fi yang ringan, cepat, dan estetis untuk desktop Linux (Wayland/Hyprland & X11).
Merupakan saudara kandung offline dari [Nada Music Player](https://github.com/Zeeynrs/Nada-Music-Player),
ditulis dengan **Python + Qt Quick (QML)** dan ditenagai langsung oleh mesin audio C API **`libmpv`**.

100% offline, tanpa perlu akun Spotify atau login, hemat RAM, dan ramah untuk setup *ricing* desktop Linux.

---

## Fitur Utama

- **Mesin Audio `libmpv` Native (Bit-Perfect)**
  - Mendukung hampir seluruh format audio lokal: `FLAC` (hingga 24-bit/192kHz), `MP3`, `OPUS`, `OGG`, `M4A`, `AAC`, `WAV`, `ALAC`, `WV`, `APE`, dan `DSD`.
  - **Gapless Playback**: Menghilangkan jeda hening antar lagu saat mendengarkan album live atau konsep.
  - **ReplayGain**: Menyamakan kerasnya volume antar lagu atau antar album secara otomatis.
  - **Pemilihan Perangkat Output Audio**: Beralih langsung antara speaker bawaan, headphone, DAC USB, atau output Bluetooth via PipeWire/ALSA.

- **Equalizer 6-Band & Tempo/Pitch DSP Real-Time**
  - Equalizer 6-band aktif (`60Hz`, `150Hz`, `400Hz`, `1kHz`, `2kHz`, `15kHz`) yang memproses aliran audio secara langsung lewat filter `lavfi` di `libmpv`.
  - Dilengkapi kurva respon frekuensi dan indikator penganalisis spektrum frekuensi audio.
  - Pilihan preset equalizer cepat: *Flat*, *Bass Boost*, *Rock*, *Vocal*, dan *Warm Hi-Fi*.
  - Kontrol kecepatan lagu (`0.5×` – `2.0×`) dengan sakelar **Keep Original Pitch**:
    - **Aktif**: Tempo berubah tanpa mengubah nada vokal/instrumen.
    - **Nonaktif**: Kecepatan juga mengubah nada lagu (*gaya nightcore / slowed + reverb*).

- **Tampilan Penuh (Immersive Player) & Estetika Ricing**
  - Sampul album bergelombang (*scalloped cover*) dengan animasi zoom halus saat memutar lagu.
  - **Dual Visualizer Cava** di sekeliling cover:
    - Mode **Capsule Bars**: 72 bilah kapsul radial yang memantul mengikuti ritme audio.
    - Mode **Liquid Wave**: Gelombang aura cair bercahaya (*morphing liquid aura*).
  - Lirik tersinkron bercahaya (*glowing synced lyrics*) dengan penanda baris kapsul bergelombang.
  - Warna aksen dinamis yang diekstrak secara otomatis dari cover album yang sedang diputar.
  - *Wavy seekbar* sinusoidal yang bergerak hidup saat musik berputar.

- **Pustaka Musik Cepat (SQLite Inkremental)**
  - Pemindaian folder musik super cepat (default `~/Music`, mendukung penambahan multi-folder).
  - Ekstraksi metadata & *cover art* otomatis (parser FLAC native, `mutagen`, atau `ffprobe`).
  - Dukungan otomatis untuk membaca dan mengimpor file playlist `.m3u` / `.m3u8`.
  - Buat dan kelola playlist lokal baru langsung dari sidebar.
  - Mendukung *Drag & Drop* file audio langsung ke jendela aplikasi.
  - Menu konteks klik kanan: buka album, buka artis, buka folder file di File Manager, atau salin path file.

- **Lirik Tersinkron Hibrida**
  - **Prioritas 1**: File lirik `.lrc` lokal di folder yang sama dengan file audio.
  - **Prioritas 2**: Tag lirik yang tertanam di metadata file audio (`LYRICS`, `USLT`).
  - **Prioritas 3 (Fallback)**: Mengambil lirik tersinkron otomatis dari database publik [LRCLIB](https://lrclib.net) dan menyimpannya di cache lokal agar dapat diakses offline untuk pemutaran berikutnya.

- **Integrasi Penuh Desktop Linux (MPRIS2)**
  - Kontrol pemutaran lewat `playerctl`, tombol media keyboard, Hyprlock, Swaylock, dan status bar (Waybar, Eww, Polybar).
  - Integrasi Wayland native (`app_id: nada-local`) untuk pengaturan aturan jendela di Hyprland atau Sway.

---

## Distro yang Direkomendasikan & Dependensi

> **Rekomendasi Utama: Arch Linux** (serta turunannya seperti EndeavourOS, CachyOS, Manjaro, Garuda).  
> Seluruh dependensi utama (`pyside6`, `mpv`, `ffmpeg`, `cava`, `python-dbus`) tersedia langsung secara native di repositori resmi Arch tanpa perlu kompilasi tambahan.

### Dependensi Sistem
- `python` (>= 3.10)
- `pyside6` (Qt 6 Quick / QML)
- `mpv` (`libmpv.so.2` untuk pemutaran audio)
- `ffmpeg` (untuk ekstraksi metadata & cover art)
- `python-dbus` (untuk integrasi MPRIS2)
- `cava` (*opsional, untuk visualizer spektrum audio PipeWire*)
- `python-mutagen` (*opsional, untuk ekstraksi tag audio ekstra cepat*)

---

## Cara Instalasi

### Opsi 1: Skrip `./install.sh` (Semua Distro — Direkomendasikan)

Skrip instalasi akan otomatis mendeteksi distro Anda (Arch, Debian/Ubuntu, Fedora, openSUSE), memasang paket dependensi yang diperlukan, membuat launcher di `~/.local/bin/nada-local`, serta mendaftarkan ikon dan menu desktop (`.desktop`):

```bash
git clone https://github.com/Zeeynrs/Nada-LocalVersion.git
cd Nada-LocalVersion
chmod +x install.sh
./install.sh
```

Setelah selesai, Anda bisa langsung menjalankan Nada Local dengan mengetik `nada-local` di terminal atau membukanya lewat menu aplikasi desktop / launcher (Rofi, Wofi, KDE Application Launcher, GNOME, dsb.).

### Opsi 2: Paket Native Arch Linux (`makepkg`)

Bagi pengguna Arch Linux dan turunannya, Anda dapat memasang Nada Local sebagai paket native sistem:

```bash
git clone https://github.com/Zeeynrs/Nada-LocalVersion.git
cd Nada-LocalVersion
makepkg -si
```

### Opsi 3: Menjalankan Langsung Tanpa Install

Anda juga bisa menjalankan Nada Local langsung dari direktori sumbernya:

```bash
python3 run.py
```

Atau langsung memutar file audio tertentu lewat argumen terminal:

```bash
python3 run.py ~/Music/lagu_favorit.flac
```

---

## Pintasan Keyboard (Keyboard Shortcuts)

| Tombol Pintasan | Aksi |
|---|---|
| <kbd>Spasi</kbd> | Putar / Jeda (*Play / Pause*) |
| <kbd>Ctrl</kbd> + <kbd>→</kbd> | Lagu berikutnya |
| <kbd>Ctrl</kbd> + <kbd>←</kbd> | Lagu sebelumnya |
| <kbd>Ctrl</kbd> + <kbd>↑</kbd> | Naikkan volume |
| <kbd>Ctrl</kbd> + <kbd>↓</kbd> | Turunkan volume |
| <kbd>Ctrl</kbd> + <kbd>F</kbd> | Buka halaman Pencarian |
| <kbd>Ctrl</kbd> + <kbd>R</kbd> | Pindai ulang pustaka folder musik |
| <kbd>Ctrl</kbd> + <kbd>L</kbd> | Buka / tutup tampilan penuh (*Immersive Player*) |
| <kbd>Ctrl</kbd> + <kbd>,</kbd> | Buka halaman Pengaturan |
| <kbd>Ctrl</kbd> + <kbd>Q</kbd> | Keluar dari aplikasi |
| <kbd>Esc</kbd> / <kbd>Alt</kbd> + <kbd>←</kbd> | Tutup tampilan penuh / Kembali ke halaman sebelumnya |

---

## Integrasi Hyprland / Window Manager

Nada Local menetapkan nama aplikasi desktop Wayland sebagai `nada-local`. Anda dapat menambahkan aturan jendela pada berkas konfigurasi Hyprland (`~/.config/hypr/hyprland.conf`):

```ini
# Aturan jendela Hyprland untuk Nada Local
windowrulev2 = float, class:^(nada-local)$
windowrulev2 = size 1200 780, class:^(nada-local)$
windowrulev2 = center, class:^(nada-local)$

# Pintasan tombol media keyboard
bind = , XF86AudioPlay, exec, playerctl -p nada_local play-pause
bind = , XF86AudioNext, exec, playerctl -p nada_local next
bind = , XF86AudioPrev, exec, playerctl -p nada_local previous
```

---

## Lokasi Berkas & Cache

- **Konfigurasi & Pengaturan**: `~/.config/nada-local/settings.json`
- **Database Pustaka (SQLite)**: `~/.cache/nada-local/library.db`
- **Cache Sampul Album**: `~/.cache/nada-local/covers/`
- **Cache Lirik Offline**: `~/.cache/nada-local/lyrics/`

Untuk menghapus instalasi sepenuhnya:
```bash
./install.sh --uninstall
```

---

## Lisensi & Kredit

- Dilisensikan di bawah [GNU General Public License v3.0 (GPL-3.0)](LICENSE).
- Ikon bersumber dari [Material Design Icons](https://github.com/google/material-design-icons) (Apache-2.0).
- Dukungan lirik daring didukung oleh basis data publik [LRCLIB](https://lrclib.net).
- Saudara pemutar Spotify daring: [Nada Music Player](https://github.com/Zeeynrs/Nada-Music-Player).
