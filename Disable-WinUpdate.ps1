# =====================================================================
# Script: Disable-WinUpdate.ps1
# Deskripsi: Mematikan Windows Update secara PERMANEN (God-Tier)
# Kompatibel: Windows 7, 10, 11 (Semua Versi)
# =====================================================================

# 1. Meminta Hak Akses Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Meminta hak akses Administrator..."
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Mulai menonaktifkan Windows Update secara God-Tier..." -ForegroundColor Cyan

# 2. Hentikan & Matikan Layanan Windows Update + Hapus Auto-Restart (FailureActions)
$services = @("wuauserv", "BITS", "dosvc", "UsoSvc", "WaaSMedicSvc")

foreach ($svc in $services) {
    try {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Write-Host "Layanan $svc dihentikan." -ForegroundColor Green
    } catch {}

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
    if (Test-Path $regPath) {
        try {
            # Matikan Startup (Disabled = 4)
            Set-ItemProperty -Path $regPath -Name "Start" -Value 4 -ErrorAction SilentlyContinue
            
            # [GOD-TIER] Matikan Auto-Restart Layanan (Recovery) menggunakan sc.exe
            # Menghapus aksi restart jika layanan crash atau dipaksa mati
            & sc.exe failure $svc reset= 0 actions= "" | Out-Null
            
            Write-Host "Startup & Auto-Recovery layanan $svc dimatikan." -ForegroundColor Green
        } catch {}
    }
}

# 3. [GOD-TIER] Kunci Folder Download (SoftwareDistribution)
Write-Host "Mengunci Gudang Download Update (SoftwareDistribution)..." -ForegroundColor Cyan
$sdPath = "$env:SystemRoot\SoftwareDistribution"
if (Test-Path $sdPath) {
    if ((Get-Item $sdPath) -is [System.IO.DirectoryInfo]) {
        try { Remove-Item -Path $sdPath -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
}
if (!(Test-Path $sdPath)) {
    try {
        # Buat file kosong bernama "SoftwareDistribution" (bukan folder)
        New-Item -ItemType File -Path $sdPath -Force | Out-Null
        # Cabut hak akses tulis (Write) agar sistem tidak bisa menggantinya dengan folder
        icacls.exe $sdPath /deny "Everyone:(W,WEA,WA)" /q | Out-Null
        icacls.exe $sdPath /deny "NT AUTHORITY\SYSTEM:(W,WEA,WA)" /q | Out-Null
        Write-Host "  -> Gudang Download berhasil dihancurkan & dikunci." -ForegroundColor Green
    } catch {
        Write-Host "  -> Gagal mengunci SoftwareDistribution." -ForegroundColor Yellow
    }
} else {
    Write-Host "  -> SoftwareDistribution sudah dikunci sebelumnya." -ForegroundColor Green
}

# 4. Terapkan Group Policy & [GOD-TIER] WSUS Blackhole
Write-Host "Menerapkan Group Policy & WSUS Blackhole..." -ForegroundColor Cyan
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$auPath = "$wuPath\AU"
if (!(Test-Path $wuPath)) { New-Item -Path $wuPath -Force | Out-Null }
if (!(Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }

Set-ItemProperty -Path $auPath -Name "NoAutoUpdate" -Value 1 -ErrorAction SilentlyContinue

# Belokkan server pencarian update ke localhost (127.0.0.1) agar nyasar
Set-ItemProperty -Path $wuPath -Name "WUServer" -Value "http://127.0.0.1" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $wuPath -Name "WUStatusServer" -Value "http://127.0.0.1" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $wuPath -Name "UpdateServiceUrlAlternate" -Value "http://127.0.0.1" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $auPath -Name "UseWUServer" -Value 1 -ErrorAction SilentlyContinue
Write-Host "  -> Server update berhasil dibelokkan ke Blackhole (127.0.0.1)." -ForegroundColor Green

# 5. Mematikan Scheduled Tasks
if (Get-Command "Disable-ScheduledTask" -ErrorAction SilentlyContinue) {
    $taskPaths = @("\Microsoft\Windows\WindowsUpdate\", "\Microsoft\Windows\UpdateOrchestrator\")
    foreach ($path in $taskPaths) {
        try {
            Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }
    Write-Host "Scheduled tasks Windows Update dinonaktifkan." -ForegroundColor Green
}

# 6. Take Ownership & Rename Executables
$executables = @("usoclient.exe", "wuauclt.exe", "waasmedic.exe", "sihclient.exe", "mousocoreworker.exe")
$sys32 = "$env:SystemRoot\System32"

Write-Host "Memblokir eksekutor & Menerapkan Firewall Block..." -ForegroundColor Cyan
foreach ($exe in $executables) {
    $target = "$sys32\$exe"
    
    # Takeown & Rename
    if (Test-Path $target) {
        takeown.exe /F $target /A /runas | Out-Null
        icacls.exe $target /grant "Administrators:F" /q | Out-Null
        try {
            Rename-Item -Path $target -NewName "$exe.bak" -Force -ErrorAction SilentlyContinue
            Write-Host "  -> Berhasil memblokir (rename): $exe" -ForegroundColor Green
        } catch {}
    }
    
    # [GOD-TIER] Tambahkan ke blokir Firewall (jaga-jaga jika file direstore otomatis)
    $fwTarget = if (Test-Path "$target.bak") { "$target.bak" } else { $target }
    try {
        netsh advfirewall firewall delete rule name="Block WinUpdate $exe" | Out-Null
        netsh advfirewall firewall add rule name="Block WinUpdate $exe" dir=out action=block program="$fwTarget" enable=yes profile=any | Out-Null
    } catch {}
}

# 7. Memblokir Server via File Hosts
Write-Host "Memblokir jalur internet tambahan ke server Microsoft..." -ForegroundColor Cyan
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$blockDomains = @(
    "v4.windowsupdate.microsoft.com", "v10.events.data.microsoft.com", 
    "v10.vortex-win.data.microsoft.com", "settings-win.data.microsoft.com", 
    "windowsupdate.microsoft.com", "update.microsoft.com", 
    "sls.update.microsoft.com.akadns.net", "fe2.update.microsoft.com.akadns.net"
)
try {
    $hostsContent = Get-Content $hostsPath -Raw -ErrorAction SilentlyContinue
    $hostsModified = $false
    foreach ($domain in $blockDomains) {
        if ($hostsContent -notmatch $domain) {
            Add-Content -Path $hostsPath -Value "0.0.0.0 $domain # Blocked by Disable-WinUpdate" -Force
            $hostsModified = $true
        }
    }
    if ($hostsModified) { Write-Host "  -> Domain pelacakan diblokir di file Hosts." -ForegroundColor Green }
} catch {}

# 8. Sembunyikan Menu Windows Update dari Settings
$uxPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (!(Test-Path $uxPath)) { New-Item -Path $uxPath -Force | Out-Null }
Set-ItemProperty -Path $uxPath -Name "SettingsPageVisibility" -Value "hide:windowsupdate" -ErrorAction SilentlyContinue
Write-Host "Menu Windows Update disembunyikan dari pengaturan OS." -ForegroundColor Green

Write-Host "`nPROSES SELESAI. Windows Update telah DIMATIKAN SECARA GOD-TIER (ABSOLUT)!" -ForegroundColor Green
Write-Host "Sistem tidak akan pernah bisa update lagi secara otomatis." -ForegroundColor Yellow
Write-Host "Silakan Restart komputer Anda agar efeknya maksimal." -ForegroundColor Yellow
Pause