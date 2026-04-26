# =====================================================================
# Script: Enable-WinUpdate.ps1
# Deskripsi: Menghidupkan kembali Windows Update (Win 7, 10, 11)
# =====================================================================

# 1. Meminta Hak Akses Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Meminta hak akses Administrator..."
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Mulai menghidupkan kembali Windows Update..." -ForegroundColor Cyan

# 2. Mengembalikan Startup Type Layanan via Registry
# wuauserv = 3 (Manual), BITS = 3 (Manual), dosvc = 3 (Manual), UsoSvc = 2 (Auto), WaaSMedicSvc = 3 (Manual)
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

# 4. Menghidupkan Scheduled Tasks (Jika menggunakan Windows 8/10/11)
if (Get-Command "Enable-ScheduledTask" -ErrorAction SilentlyContinue) {
    $taskPaths = @("\Microsoft\Windows\WindowsUpdate\", "\Microsoft\Windows\UpdateOrchestrator\")
    foreach ($path in $taskPaths) {
        try {
            Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue | Enable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Scheduled tasks di $path berhasil diaktifkan kembali." -ForegroundColor Green
        } catch {}
    }
}

# 5. Menjalankan Layanan Utama
try {
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    Write-Host "Layanan Windows Update (wuauserv) berhasil dijalankan." -ForegroundColor Green
} catch {}

Write-Host "`nPROSES SELESAI. Windows Update telah dihidupkan kembali!" -ForegroundColor Green
Write-Host "Silakan Restart komputer Anda jika diperlukan." -ForegroundColor Yellow
Pause