# =====================================================================
# Script: Disable-WinUpdate.ps1
# Deskripsi: Mematikan Windows Update secara PERMANEN (Ekstrem) 
# Kompatibel: Windows 7, 10, 11 (Semua Versi)
# =====================================================================

# 1. Meminta Hak Akses Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Meminta hak akses Administrator..."
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Mulai menonaktifkan Windows Update secara Ekstrem..." -ForegroundColor Cyan

# 2. Daftar layanan yang akan dimatikan (Kompatibel lintas versi OS)
$services = @("wuauserv", "BITS", "dosvc", "UsoSvc", "WaaSMedicSvc")

foreach ($svc in $services) {
    # Hentikan layanan jika sedang berjalan
    try {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Write-Host "Layanan $svc berhasil dihentikan." -ForegroundColor Green
    } catch {}

    # Matikan layanan via Registry (Cara paling powerful & kompatibel dari Win 7 - 11)
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
    if (Test-Path $regPath) {
        try {
            Set-ItemProperty -Path $regPath -Name "Start" -Value 4 -ErrorAction SilentlyContinue
            Write-Host "Startup layanan $svc di-set menjadi Disabled." -ForegroundColor Green
        } catch {
            Write-Host "Gagal memodifikasi registry untuk $svc (Mungkin butuh akses TrustedInstaller)." -ForegroundColor Red
        }
    }
}

# 3. Menerapkan Group Policy untuk mematikan Auto Update
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (!(Test-Path $policyPath)) {
    New-Item -Path $policyPath -Force | Out-Null
}
Set-ItemProperty -Path $policyPath -Name "NoAutoUpdate" -Value 1 -ErrorAction SilentlyContinue
Write-Host "Group Policy NoAutoUpdate berhasil diaktifkan." -ForegroundColor Green

# 4. Mematikan Scheduled Tasks (Jika menggunakan Windows 8/10/11)
if (Get-Command "Disable-ScheduledTask" -ErrorAction SilentlyContinue) {
    $taskPaths = @("\Microsoft\Windows\WindowsUpdate\", "\Microsoft\Windows\UpdateOrchestrator\")
    foreach ($path in $taskPaths) {
        try {
            Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Scheduled tasks di $path berhasil dinonaktifkan." -ForegroundColor Green
        } catch {}
    }
} else {
    Write-Host "OS versi lama terdeteksi (Win 7). Melewati langkah Scheduled Tasks." -ForegroundColor Yellow
}

# ======================= UPGRADE EKSTREM =======================

# 5. Take Ownership dan Rename Executables (Mencegah Self-Healing)
$executables = @("usoclient.exe", "wuauclt.exe", "waasmedic.exe", "sihclient.exe", "mousocoreworker.exe")
$sys32 = "$env:SystemRoot\System32"

Write-Host "Memblokir eksekutor Update otomatis (Nuclear Option)..." -ForegroundColor Cyan
foreach ($exe in $executables) {
    $target = "$sys32\$exe"
    if (Test-Path $target) {
        # Ambil alih kepemilikan dari TrustedInstaller
        takeown.exe /F $target /A | Out-Null
        icacls.exe $target /grant "Administrators:F" /q | Out-Null
        try {
            Rename-Item -Path $target -NewName "$exe.bak" -Force -ErrorAction SilentlyContinue
            Write-Host "  -> Berhasil memblokir (rename): $exe" -ForegroundColor Green
        } catch {
            Write-Host "  -> Gagal memblokir $exe (Mungkin sedang berjalan)." -ForegroundColor Yellow
        }
    }
}

# 6. Memblokir Server Windows Update via File Hosts
Write-Host "Memblokir jalur internet ke server Windows Update..." -ForegroundColor Cyan
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$blockDomains = @(
    "v4.windowsupdate.microsoft.com",
    "v10.events.data.microsoft.com",
    "v10.vortex-win.data.microsoft.com",
    "settings-win.data.microsoft.com",
    "windowsupdate.microsoft.com",
    "update.microsoft.com"
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
    if ($hostsModified) { Write-Host "  -> Server Windows Update diblokir via file Hosts." -ForegroundColor Green }
} catch {
    Write-Host "  -> Gagal memodifikasi file Hosts." -ForegroundColor Yellow
}

# 7. Sembunyikan Menu Windows Update dari Settings
$uxPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (!(Test-Path $uxPath)) { New-Item -Path $uxPath -Force | Out-Null }
Set-ItemProperty -Path $uxPath -Name "SettingsPageVisibility" -Value "hide:windowsupdate" -ErrorAction SilentlyContinue
Write-Host "Menu Windows Update disembunyikan dari pengaturan OS." -ForegroundColor Green

Write-Host "`nPROSES SELESAI. Windows Update telah DIMATIKAN SECARA EKSTREM!" -ForegroundColor Green
Write-Host "Silakan Restart komputer Anda agar efeknya maksimal." -ForegroundColor Yellow
Pause