# hw-mon

Alat cek spesifikasi hardware Windows secara detail — langsung dari terminal PowerShell/cmd, tanpa software tambahan.

Menampilkan: spesifikasi sistem, CPU, RAM, GPU, storage (termasuk health/wear), dan **kesehatan baterai** (wear level, health, cycle count) — plus power-on hours (POH) SSD/HDD.

## Cara Pakai

### Jalankan Online (Zero-Install)

Paling cepat — **auto jalankan sebagai Administrator** (keluar UAC prompt sekali di klik OK), tanpa clone, tanpa install apa pun.

**Cara A — pakai file runner:** download [`hw-mon-online.cmd`](https://raw.githubusercontent.com/agusedyc/hw-mon/main/hw-mon-online.cmd) (klik kanan → *Save link as*), simpan di mana pun, lalu **double-click**. Window baru terbuka, isi UAC, selesai.

**Cara B — copy-paste di terminal (cmd ATAU PowerShell), Enter:**

```
curl.exe -Ls https://raw.githubusercontent.com/agusedyc/hw-mon/main/hw-mon.ps1 | powershell -NoProfile -ExecutionPolicy Bypass -Command -
```

- Jalan tanpa clone, tanpa download, tanpa install apa pun.
- Bisa dijalankan dari cmd klasik maupun PowerShell window — baris yang sama.
- Semua section jalan: sistem, CPU, RAM, GPU, storage, battery.

**Bagian yang butuh Administrator (POH SSD/HDD NVMe):** cara A otomatis elevate → bisa membaca power-on hours langsung. Cara B kalau mau POH, buka prompt **as Administrator** (klik kanan → *Run as administrator*) lalu paste ulang baris di atas. Semua section lain tetap jalan tanpa admin.

> ⚠️ Perhatian: menjalankan kode dari internet tanpa meninjaunya lebih dulu berisiko. Kalau mau paling aman, gunakan cara clone di bawah — baca kodenya dulu, lalu jalankan.

### Clone + jalankan

```
git clone https://github.com/agusedyc/hw-mon.git
cd hw-mon
hw-mon.cmd
```

- **Double-click `hw-mon.cmd`** juga bisa.
- `hw-mon.cmd` otomatis install `smartmontools` (via winget) kalau belum ada, biar POH SSD/HDD kebaca.

### 1-liner script lokal (opsional)

```
powershell -ExecutionPolicy Bypass -File .\hw-mon.ps1
```

> Catatan: cara ini **tidak** auto-install smartmontools. Kalau `smartctl` belum ada, POH dilewati.

## Persyaratan

| Kebutuhan | Versi |
|---|---|
| Windows | 10 / 11 |
| PowerShell | 5.1+ (bawaan Windows) |
| winget | Windows 10 1809+ / 11 (untuk auto-install smartctl) |
| curl.exe | Windows 10 1803+ (bawaan, untuk cara online) |

Semua data dibaca via WMI/CIM Windows — **tidak butuh admin**, langsung jalan.

## Output

Script mencetak section warna ke terminal:

| Section | Info yang ditampilkan |
|---|---|
| SYSTEM | Manufacturer/model, OS, arsitektur, uptime |
| CPU | Nama, core/thread, clock, L2/L3 cache |
| MEMORY | Total RAM, per-slot (kapasitas, speed, DDR type), batas max slot |
| MOTHERBOARD | Manufacturer, model |
| GPU | Nama, VRAM, versi driver |
| STORAGE | Media type (SSD/HDD), kapasitas, bus, health, wear, temp, errors, **POH** |
| BATTERY | Nama, manufacturer, kapasitas desain vs full-charge, **wear level**, **health %**, **cycle count**, status charge |

### Baterai

Data baterai diambil dari `powercfg /batteryreport` (bukan WMI raw):

```
NAME                 : AP19B5L
MANUFACTURER         : PANASONIC
SERIAL NUMBER        : 43513
CHEMISTRY            : LION
DESIGN CAPACITY      : 52,976 mWh / 53.0 Wh
FULL CHARGED (now)   : 39,316 mWh / 39.3 Wh
WEAR LEVEL           : 25.8 % (health 74.2 %)
CYCLE COUNT          : 144
```

- **Wear Level** = seberapa banyak kapasitas baterai turun dari desain (`1 - full/design` × 100%)
- **Health %** = kapasitas tersisa proyeksi (>80% normal, <80% mulai aus)
- **Cycle Count** = jumlah siklus charge penuh

### POH (Power-On Hours) Storage

Power-on hours butuh `smartctl` dari **smartmontools**, dan untuk NVMe butuh hak admin. Alurnya:

1. Cara **online**: buka cmd as Administrator, paste command online. Script deteksi `smartctl`; kalau belum ada, arahkan ke install.
2. Cara **clone**: `hw-mon.cmd` cek `smartctl` → install otomatis via winget. Untuk NVMe tetap perlu cmd as Administrator.
3. Kalau `smartctl` terpasang & jalan, script parse jam `Power On Hours` tiap disk → tampil dalam jam + hari.

Install manual kalau winget tak tersedia:
```
winget install --id smartmontools.smartmontools
```

## Contoh Output Penuh

```
SYSTEM
  Manufacturer / Model            : Acer TravelMate P214
  OS                              : Microsoft Windows 11 Pro (26200)
  OS Uptime                       : 0d 6h 34m

CPU
  Name                            : 11th Gen Intel(R) Core(TM) i7-1165G7
  Cores / Threads                 : 4 / 8
  Max Clock                       : 2.8 GHz

MEMORY
  Total RAM                       : 16.0 GB
  Slot Controller0-ChannelA-DIMM0 : 8.0 GB, 3200 MHz, DDR4
  Max Installed                   : 32.0 GB

STORAGE
  [eui.00A07501] NVMe Micron_2450_MTFDKBA512TFK
    Media Type                    : SSD
    Capacity                      : 476.9 GB
    Health                        : Healthy / OK

BATTERY
  CHARGING                        : On AC (charge complete)
  CHARGE REMAINING                : 100 %
  DESIGN CAPACITY                 : 52,976 mWh / 53.0 Wh
  FULL CHARGED (now)              : 39,316 mWh / 39.3 Wh
  WEAR LEVEL                      : 25.8 % (health 74.2 %)
  CYCLE COUNT                     : 144
```

## Struktur File

```
hw-mon/
├── hw-mon.ps1           # script utama
├── hw-mon.cmd           # wrapper — auto-install smartctl + jalankan
├── hw-mon-online.cmd    # zero-install runner — auto-admin + jalankan online
└── README.md
```
