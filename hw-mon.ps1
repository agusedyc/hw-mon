#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# Auto-elevate to Administrator
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $tmp = Join-Path $env:TEMP ('hw-mon-' + [guid]::NewGuid().ToString('N') + '.ps1')
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/agusedyc/hw-mon/main/hw-mon.ps1' -OutFile $tmp -UseBasicParsing
    Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File', ('"' + $tmp + '"'))
    exit
}

$wce = $host.UI.RawUI.WindowSize.Width
if (-not $wce -or $wce -lt 40) { $wce = 100 }

function Section($title) {
    Write-Host ''
    Write-Host ('=' * $wce) -ForegroundColor DarkGray
    Write-Host "  $title" -ForegroundColor Yellow
    Write-Host ('=' * $wce) -ForegroundColor DarkGray
}
function KV($k, $v) {
    $line = "  {0,-32}: {1}" -f $k, $v
    Write-Host $line
}
function GB($v) { '{0:N1} GB' -f ($v / 1GB) }
function MemType($t) { switch ($t) { 20 { 'DDR' } 21 { 'DDR2' } 24 { 'DDR3' } 26 { 'DDR4' } 34 { 'DDR5' } 27 { 'LPDDR' } 28 { 'LPDDR2' } 29 { 'LPDDR3' } 30 { 'LPDDR4' } 35 { 'LPDDR5' } default { $t } } }

# ---------- System ----------
Section 'SYSTEM'
$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
KV 'Manufacturer / Model' "$($cs.Manufacturer) $($cs.Model)"
KV 'System Type' $cs.SystemType
KV 'OS' "$($os.Caption) ($($os.BuildNumber))"
KV 'Architecture' $os.OSArchitecture
KV 'OS Uptime' ((Get-Date) - $os.LastBootUpTime | ForEach-Object { '{0}d {1}h {2}m' -f $_.Days, $_.Hours, $_.Minutes })

# ---------- CPU ----------
Section 'CPU'
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
KV 'Name' $cpu.Name.Trim()
KV 'Cores / Threads' "$($cpu.NumberOfCores) / $($cpu.NumberOfLogicalProcessors)"
KV 'Max Clock' ('{0:N1} GHz' -f ($cpu.MaxClockSpeed / 1000))
KV 'L2 Cache' ('{0:N0} KB' -f $cpu.L2CacheSize)
KV 'L3 Cache' ('{0:N0} KB' -f $cpu.L3CacheSize)

# ---------- Memory ----------
Section 'MEMORY'
$mem = Get-CimInstance Win32_PhysicalMemory
if ($mem) {
    $tot = ($mem | Measure-Object Capacity -Sum).Sum
    KV 'Total RAM' (GB $tot)
    $mem | ForEach-Object {
        KV ('Slot {0}' -f $_.DeviceLocator) ('{0}, {1} MHz, {2}' -f (GB $_.Capacity), $_.ConfiguredClockSpeed, (MemType $_.SMBIOSMemoryType))
    }
    $slots = Get-CimInstance Win32_PhysicalMemoryArray
    if ($slots) { KV 'Max Installed' ('{0:N1} GB' -f ($slots.MaxCapacity / 1MB)) }
} else {
    KV 'Total RAM' (GB (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory)
}

# ---------- Motherboard ----------
Section 'MOTHERBOARD'
$mb = Get-CimInstance Win32_BaseBoard
KV 'Manufacturer' $mb.Manufacturer
KV 'Model' $mb.Product

# ---------- Graphics ----------
Section 'GPU'
$gpu = Get-CimInstance Win32_VideoController
$gpu | ForEach-Object {
    KV $_.Name (GB $_.AdapterRAM)
    KV '  Driver' $_.DriverVersion
}

# ---------- Storage ----------
Section 'STORAGE'
$disks = Get-PhysicalDisk
foreach ($d in $disks) {
    Write-Host ('  [{0}] {1}' -f $d.UniqueId.Substring(0,[Math]::Min(12,$d.UniqueId.Length)), $d.FriendlyName) -ForegroundColor Cyan
    KV '  Media Type' $d.MediaType
    KV '  Bus / Interface' "$($d.BusType) / $($d.InterfaceType)"
    KV '  Capacity' (GB $d.Size)
    KV '  Health' "$($d.HealthStatus) / $($d.OperationalStatus)"
    $d | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Wear) { KV '  SSD Wear' ('{0:N1} %' -f $_.Wear) }
        if ($_.Temperature) { KV '  Temp' ('{0:N0} C' -f $_.Temperature) }
        if ($_.PowerOnHours) { KV '  Power-On Hours' ('{0:n0} jam ({1} hari)' -f $_.PowerOnHours, [int]($_.PowerOnHours/24)) }
        KV '  Read Errors' $_.ReadErrorsTotal
        KV '  Write Errors' $_.WriteErrorsTotal
    }
}

# ---------- Battery ----------
Section 'BATTERY'
$bat = Get-CimInstance Win32_Battery
if ($bat) {
    KV 'Charging' $(switch ($bat.BatteryStatus) { 1 { 'Discharging' } 2 { 'On AC (charge complete)' } 3 { 'Charging' } 4 { 'On AC (charge low)' } 5 { 'On AC (not charging)' } 6 { 'Unknown' } default { $bat.BatteryStatus } })
    KV 'Charge Remaining' ('{0} %' -f $bat.EstimatedChargeRemaining)
    if ($bat.BatteryStatus -ne 2 -and $bat.EstimatedRunTime -gt 0) {
        KV 'Est. Run Time' ('{0:N1} h' -f ($bat.EstimatedRunTime / 60))
    }

    $rep = Join-Path $env:TEMP ('batrep_' + [guid]::NewGuid().ToString('N') + '.html')
    try {
        & powercfg /batteryreport /output $rep 2>$null | Out-Null
        $h = Get-Content $rep -Raw
        $m = [regex]::Match($h, '(?s)<div class="explanation">\s*Information about each currently installed battery\s*</div>(.*?</table>)', 'IgnoreCase')
        if ($m.Success) {
            $tbl = $m.Groups[1].Value
            $labels = [regex]::Matches($tbl, '<span class="label">(.*?)</span></td><td>([\s\S]*?)</td>', 'IgnoreCase')
            $d = @{}
            foreach ($l in $labels) { $d[$l.Groups[1].Value.Trim()] = $l.Groups[2].Value.Trim() }

            $designedRaw = if ($d['DESIGN CAPACITY']) { [double]([regex]::Match($d['DESIGN CAPACITY'], '([\d.,]+)').Groups[1].Value.Replace(',','')) } else { $null }
            $fullRaw = if ($d['FULL CHARGE CAPACITY']) { [double]([regex]::Match($d['FULL CHARGE CAPACITY'], '([\d.,]+)').Groups[1].Value.Replace(',','')) } else { $null }
            $designed = if ($designedRaw) { $designedRaw * 1000 } else { $null }
            $full = if ($fullRaw) { $fullRaw * 1000 } else { $null }

            if ($d['NAME']) { KV 'Name' $d['NAME'] }
            if ($d['MANUFACTURER']) { KV 'Manufacturer' $d['MANUFACTURER'] }
            if ($d['SERIAL NUMBER']) { KV 'Serial Number' $d['SERIAL NUMBER'] }
            if ($d['CHEMISTRY']) { KV 'Chemistry' $d['CHEMISTRY'] }
            if ($designed) { KV 'Designed Capacity' ('{0:N0} mWh / {1:N1} Wh' -f $designed, ($designed/1000)) }
            if ($full) { KV 'Full Charged (now)' ('{0:N0} mWh / {1:N1} Wh' -f $full, ($full/1000)) }
            if ($full -and $designed -and $designed -gt 0) {
                $wear = (1 - ($full / $designed)) * 100
                KV 'Wear Level' ('{0:N1} % (health {1:N1} %)' -f $wear, (100 - $wear))
                $color = if ($wear -lt 20) { 'Green' } elseif ($wear -lt 50) { 'Yellow' } else { 'Red' }
                Write-Host ('  {0,-32}: {1}' -f 'Battery Health', ('{0:N1} %' -f (100-$wear))) -ForegroundColor $color
            }
            if ($d['CYCLE COUNT']) { KV 'Cycle Count' $d['CYCLE COUNT'] }
        }
    } catch { }
    finally { if (Test-Path $rep) { Remove-Item $rep -Force -ErrorAction SilentlyContinue } }
} else {
    KV 'Battery' 'Tidak ada baterai terdeteksi'
}

Write-Host ''
Write-Host 'Selesai.' -ForegroundColor DarkGray

Read-Host 'Tekan Enter untuk menutup...'

