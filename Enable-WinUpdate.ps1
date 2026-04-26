# =====================================================================
# Script: Enable-WinUpdate.ps1
# Deskripsi: Menghidupkan kembali Windows Update (Revert God-Tier)
# Kompatibel: Windows 7, 10, 11 (Semua Versi)
# =====================================================================

# 1. Meminta Hak Akses Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Meminta hak akses Administrator..."
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Mulai menghidupkan kembali Windows Update (Membersihkan God-Tier)..." -ForegroundColor Cyan

# 2. [REVERT GOD-TIER] Buka Kunci Folder Download (SoftwareDistribution)
Write-Host "Membuka kunci Gudang Download (SoftwareDistribution)..." -ForegroundColor Cyan
$sdPath = "$env:SystemRoot\SoftwareDistribution"
if (Test-Path $sdPath) {
    if ((Get-Item $sdPath) -is [System.IO.FileInfo]) {
        try {
            icacls.exe $sdPath /reset /q | Out-Null
            Remove-Item -Path $sdPath -Force -ErrorAction SilentlyContinue
            Write-Host "  -> Berhasil menghapus file pengunci SoftwareDistribution." -ForegroundColor Green
        } catch {
            Write-Host "  -> Gagal membuka kunci SoftwareDistribution." -ForegroundColor Yellow
        }
    }
}

# 3. Mengembalikan Startup & Recovery Layanan
$services = @{
    "wuauserv" = 3; "BITS" = 3; "dosvc" = 3; "UsoSvc" = 2; "WaaSMedicSvc" = 3
}

foreach ($svc in $services.Keys) {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
    if (Test-Path $regPath) {
        try {
            Set-ItemProperty -Path $regPath -Name "Start" -Value $services[$svc] -ErrorAction SilentlyContinue
            
            # [REVERT GOD-TIER] Mengembalikan Auto-Restart Layanan (Recovery)
            & sc.exe failure $svc reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null
            
            Write-Host "Startup & Recovery layanan $svc dikembalikan ke default." -ForegroundColor Green
        } catch {}
    }
}

# 4. [REVERT GOD-TIER] Menghapus WSUS Blackhole & Group Policy
Write-Host "Menghapus Group Policy & WSUS Blackhole..." -ForegroundColor Cyan
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$auPath = "$wuPath\AU"
if (Test-Path $wuPath) {
    Remove-ItemProperty -Path $wuPath -Name "WUServer" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $wuPath -Name "WUStatusServer" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $wuPath -Name "UpdateServiceUrlAlternate" -ErrorAction SilentlyContinue
}
if (Test-Path $auPath) {
    Remove-ItemProperty -Path $auPath -Name "UseWUServer" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $auPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
}
Write-Host "  -> Rute server update kembali diarahkan ke Microsoft." -ForegroundColor Green

# 5. Menghidupkan Scheduled Tasks
if (Get-Command "Enable-ScheduledTask" -ErrorAction SilentlyContinue) {
    $taskPaths = @("\Microsoft\Windows\WindowsUpdate\", "\Microsoft\Windows\UpdateOrchestrator\")
    foreach ($path in $taskPaths) {
        try {
            Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue | Enable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }
    Write-Host "Scheduled tasks berhasil diaktifkan." -ForegroundColor Green
}

# 6. Memulihkan Executables & [REVERT GOD-TIER] Menghapus Blokir Firewall
$executables = @("usoclient.exe", "wuauclt.exe", "waasmedic.exe", "sihclient.exe", "mousocoreworker.exe")
$sys32 = "$env:SystemRoot\System32"

Write-Host "Memulihkan eksekutor & Menghapus Firewall Block..." -ForegroundColor Cyan
foreach ($exe in $executables) {
    $bak = "$sys32\$exe.bak"
    if (Test-Path $bak) {
        try {
            Rename-Item -Path $bak -NewName $exe -Force -ErrorAction SilentlyContinue
            Write-Host "  -> Berhasil memulihkan: $exe" -ForegroundColor Green
        } catch {}
    }
    
    # Hapus blokir dari firewall
    try {
        netsh advfirewall firewall delete rule name="Block WinUpdate $exe" | Out-Null
    } catch {}
}

# 7. Memulihkan File Hosts
Write-Host "Membuka jalur internet ke server Windows Update..." -ForegroundColor Cyan
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
try {
    $hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue
    if ($hostsContent) {
        $newHosts = $hostsContent | Where-Object { $_ -notmatch "# Blocked by Disable-WinUpdate" }
        Set-Content -Path $hostsPath -Value $newHosts -Force
        Write-Host "  -> File Hosts berhasil dipulihkan." -ForegroundColor Green
    }
} catch {}

# 8. Memulihkan Menu Windows Update di Settings
$uxPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (Test-Path $uxPath) {
    Remove-ItemProperty -Path $uxPath -Name "SettingsPageVisibility" -ErrorAction SilentlyContinue
    Write-Host "Menu Windows Update kembali dimunculkan di pengaturan OS." -ForegroundColor Green
}

# 9. Menjalankan Layanan Utama
try {
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    Write-Host "Layanan Windows Update (wuauserv) berhasil dijalankan." -ForegroundColor Green
} catch {}

Write-Host "`nPROSES SELESAI. Windows Update telah normal kembali 100%!" -ForegroundColor Green
Write-Host "Silakan Restart komputer Anda agar sistem merefresh konfigurasinya." -ForegroundColor Yellow
Pause