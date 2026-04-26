# =====================================================================
# Script: Enable-WinUpdate.ps1
# Deskripsi: Menghidupkan kembali Windows Update dari Kondisi Ekstrem
# Kompatibel: Windows 7, 10, 11 (Semua Versi)
# =====================================================================

# 1. Meminta Hak Akses Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Meminta hak akses Administrator..."
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Mulai menghidupkan kembali Windows Update..." -ForegroundColor Cyan

# 2. Mengembalikan Startup Type Layanan via Registry
$services = @{
    "wuauserv" = 3;
    "BITS" = 3;
    "dosvc" = 3;
    "UsoSvc" = 2;
    "WaaSMedicSvc" = 3
}

foreach ($svc in $services.Keys) {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
    if (Test-Path $regPath) {
        try {
            Set-ItemProperty -Path $regPath -Name "Start" -Value $services[$svc] -ErrorAction SilentlyContinue
            Write-Host "Startup layanan $svc dikembalikan ke default." -ForegroundColor Green
        } catch {
            Write-Host "Gagal memodifikasi registry untuk $svc." -ForegroundColor Red
        }
    }
}

# 3. Menghapus Group Policy NoAutoUpdate
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (Test-Path $policyPath) {
    Remove-ItemProperty -Path $policyPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
    Write-Host "Group Policy NoAutoUpdate berhasil dihapus." -ForegroundColor Green
}

# 4. Menghidupkan Scheduled Tasks
if (Get-Command "Enable-ScheduledTask" -ErrorAction SilentlyContinue) {
    $taskPaths = @("\Microsoft\Windows\WindowsUpdate\", "\Microsoft\Windows\UpdateOrchestrator\")
    foreach ($path in $taskPaths) {
        try {
            Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue | Enable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Scheduled tasks di $path berhasil diaktifkan kembali." -ForegroundColor Green
        } catch {}
    }
}

# ======================= REVERT EKSTREM =======================

# 5. Memulihkan File Eksekusi
$executables = @("usoclient.exe", "wuauclt.exe", "waasmedic.exe", "sihclient.exe", "mousocoreworker.exe")
$sys32 = "$env:SystemRoot\System32"

Write-Host "Memulihkan eksekutor Update otomatis..." -ForegroundColor Cyan
foreach ($exe in $executables) {
    $bak = "$sys32\$exe.bak"
    $target = "$sys32\$exe"
    if (Test-Path $bak) {
        try {
            Rename-Item -Path $bak -NewName $exe -Force -ErrorAction SilentlyContinue
            Write-Host "  -> Berhasil memulihkan: $exe" -ForegroundColor Green
        } catch {
            Write-Host "  -> Gagal memulihkan $exe." -ForegroundColor Yellow
        }
    }
}

# 6. Memulihkan File Hosts
Write-Host "Membuka jalur internet ke server Windows Update..." -ForegroundColor Cyan
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
try {
    $hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue
    if ($hostsContent) {
        $newHosts = $hostsContent | Where-Object { $_ -notmatch "# Blocked by Disable-WinUpdate" }
        Set-Content -Path $hostsPath -Value $newHosts -Force
        Write-Host "  -> Server Windows Update dipulihkan dari file Hosts." -ForegroundColor Green
    }
} catch {
    Write-Host "  -> Gagal memodifikasi file Hosts." -ForegroundColor Yellow
}

# 7. Memulihkan Menu Windows Update di Settings
$uxPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (Test-Path $uxPath) {
    Remove-ItemProperty -Path $uxPath -Name "SettingsPageVisibility" -ErrorAction SilentlyContinue
    Write-Host "Menu Windows Update kembali dimunculkan di pengaturan OS." -ForegroundColor Green
}

# 8. Menjalankan Layanan Utama
try {
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    Write-Host "Layanan Windows Update (wuauserv) berhasil dijalankan." -ForegroundColor Green
} catch {}

Write-Host "`nPROSES SELESAI. Windows Update telah normal kembali!" -ForegroundColor Green
Write-Host "Silakan Restart komputer Anda agar efeknya maksimal." -ForegroundColor Yellow
Pause