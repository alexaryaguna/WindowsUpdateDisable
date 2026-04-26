# =====================================================================
# Script: Disable-WinUpdate.ps1
# Deskripsi: Mematikan Windows Update secara permanen (Win 7, 10, 11)
# =====================================================================

# 1. Meminta Hak Akses Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Meminta hak akses Administrator..."
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Mulai menonaktifkan Windows Update..." -ForegroundColor Cyan

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

Write-Host "`nPROSES SELESAI. Windows Update telah dimatikan!" -ForegroundColor Green
Write-Host "Silakan Restart komputer Anda agar efeknya maksimal." -ForegroundColor Yellow
Pause