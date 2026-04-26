# =====================================================================
# Script: Disable-WinUpdate.ps1
# Deskripsi: Mematikan Windows Update secara PERMANEN (Titan-Tier)
# Kompatibel: Windows 7, 10, 11 (Semua Versi)
# =====================================================================

# 1. Meminta Hak Akses Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Meminta hak akses Administrator..."
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Mulai menonaktifkan Windows Update secara Titan-Tier..." -ForegroundColor Cyan

# 2. [TITAN-TIER] Ghost Download Wiper (Menghapus antrean unduhan BITS)
Write-Host "Menghapus sisa antrean unduhan update di latar belakang..." -ForegroundColor Cyan
try {
    & bitsadmin.exe /reset /allusers | Out-Null
    Write-Host "  -> Antrean unduhan (pending update) berhasil dihancurkan." -ForegroundColor Green
} catch {}

# 3. Hentikan & Matikan Layanan Windows Update + Hapus Auto-Restart
$services = @("wuauserv", "BITS", "dosvc", "UsoSvc", "WaaSMedicSvc")
foreach ($svc in $services) {
    try { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue } catch {}
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
    if (Test-Path $regPath) {
        try {
            Set-ItemProperty -Path $regPath -Name "Start" -Value 4 -ErrorAction SilentlyContinue
            & sc.exe failure $svc reset= 0 actions= "" | Out-Null
            Write-Host "Startup & Auto-Recovery layanan $svc dimatikan." -ForegroundColor Green
        } catch {}
    }
}

# 4. Kunci Folder Download (SoftwareDistribution)
Write-Host "Mengunci Gudang Download Update (SoftwareDistribution)..." -ForegroundColor Cyan
$sdPath = "$env:SystemRoot\SoftwareDistribution"
if (Test-Path $sdPath) {
    if ((Get-Item $sdPath) -is [System.IO.DirectoryInfo]) {
        try { Remove-Item -Path $sdPath -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
}
if (!(Test-Path $sdPath)) {
    try {
        New-Item -ItemType File -Path $sdPath -Force | Out-Null
        icacls.exe $sdPath /deny "Everyone:(W,WEA,WA)" /q | Out-Null
        icacls.exe $sdPath /deny "NT AUTHORITY\SYSTEM:(W,WEA,WA)" /q | Out-Null
        Write-Host "  -> Gudang Download berhasil dihancurkan & dikunci." -ForegroundColor Green
    } catch {}
}

# 5. Terapkan Group Policy & WSUS Blackhole
Write-Host "Menerapkan Group Policy & WSUS Blackhole..." -ForegroundColor Cyan
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$auPath = "$wuPath\AU"
if (!(Test-Path $wuPath)) { New-Item -Path $wuPath -Force | Out-Null }
if (!(Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }

Set-ItemProperty -Path $auPath -Name "NoAutoUpdate" -Value 1 -ErrorAction SilentlyContinue
Set-ItemProperty -Path $wuPath -Name "WUServer" -Value "http://127.0.0.1" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $wuPath -Name "WUStatusServer" -Value "http://127.0.0.1" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $wuPath -Name "UpdateServiceUrlAlternate" -Value "http://127.0.0.1" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $auPath -Name "UseWUServer" -Value 1 -ErrorAction SilentlyContinue
Write-Host "  -> Server update berhasil dibelokkan ke Blackhole (127.0.0.1)." -ForegroundColor Green

# 6. Mematikan Scheduled Tasks
if (Get-Command "Disable-ScheduledTask" -ErrorAction SilentlyContinue) {
    $taskPaths = @("\Microsoft\Windows\WindowsUpdate\", "\Microsoft\Windows\UpdateOrchestrator\")
    foreach ($path in $taskPaths) {
        try { Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null } catch {}
    }
}

# 7. Take Ownership, Rename Executables & [TITAN-TIER] Update Assistant Killer
Write-Host "Memblokir eksekutor & Menerapkan Firewall Block..." -ForegroundColor Cyan
$executables = @("usoclient.exe", "wuauclt.exe", "waasmedic.exe", "sihclient.exe", "mousocoreworker.exe")
$sys32 = "$env:SystemRoot\System32"

foreach ($exe in $executables) {
    $target = "$sys32\$exe"
    if (Test-Path $target) {
        takeown.exe /F $target /A /runas | Out-Null
        icacls.exe $target /grant "Administrators:F" /q | Out-Null
        try { Rename-Item -Path $target -NewName "$exe.bak" -Force -ErrorAction SilentlyContinue } catch {}
    }
    $fwTarget = if (Test-Path "$target.bak") { "$target.bak" } else { $target }
    try {
        netsh advfirewall firewall delete rule name="Block WinUpdate $exe" | Out-Null
        netsh advfirewall firewall add rule name="Block WinUpdate $exe" dir=out action=block program="$fwTarget" enable=yes profile=any | Out-Null
    } catch {}
}

# [TITAN-TIER] Update Assistant Killer
$upgraderPaths = @("$env:SystemDrive\Windows10Upgrade", "$env:SystemDrive\WindowsUpdate")
foreach ($dir in $upgraderPaths) {
    $app = "$dir\Windows10UpgraderApp.exe"
    if (Test-Path $app) {
        takeown.exe /F $app /A /runas | Out-Null
        icacls.exe $app /grant "Administrators:F" /q | Out-Null
        try { Rename-Item -Path $app -NewName "Windows10UpgraderApp.exe.bak" -Force -ErrorAction SilentlyContinue } catch {}
        Write-Host "  -> Pemaksa Update (Windows Update Assistant) berhasil diblokir." -ForegroundColor Green
    }
}

# 8. Memblokir Server via File Hosts
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$blockDomains = @("v4.windowsupdate.microsoft.com", "v10.events.data.microsoft.com", "v10.vortex-win.data.microsoft.com", "settings-win.data.microsoft.com", "windowsupdate.microsoft.com", "update.microsoft.com", "sls.update.microsoft.com.akadns.net", "fe2.update.microsoft.com.akadns.net")
try {
    $hostsContent = Get-Content $hostsPath -Raw -ErrorAction SilentlyContinue
    foreach ($domain in $blockDomains) {
        if ($hostsContent -notmatch $domain) { Add-Content -Path $hostsPath -Value "0.0.0.0 $domain # Blocked by Disable-WinUpdate" -Force }
    }
} catch {}

# 9. [TITAN-TIER] Hilangkan Tombol "Update and Restart" di Start Menu & Settings UI
$uxPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (!(Test-Path $uxPath)) { New-Item -Path $uxPath -Force | Out-Null }
Set-ItemProperty -Path $uxPath -Name "SettingsPageVisibility" -Value "hide:windowsupdate" -ErrorAction SilentlyContinue

$auPaths = @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU", "HKCU:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU")
foreach ($p in $auPaths) {
    if (!(Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name "NoAUAsDefaultShutdownOption" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $p -Name "NoAUShutdownOption" -Value 1 -ErrorAction SilentlyContinue
}
Write-Host "Tombol 'Update and Restart' di Start Menu & Settings telah dihilangkan." -ForegroundColor Green

Write-Host "`nPROSES SELESAI. Windows Update telah DIMATIKAN SECARA TITAN-TIER (END-GAME)!" -ForegroundColor Green
Write-Host "Sistem tidak akan pernah bisa update lagi secara otomatis." -ForegroundColor Yellow
Write-Host "Silakan Restart komputer Anda agar efeknya maksimal." -ForegroundColor Yellow
Pause