# =====================================================================
# Script: Enable-WinUpdate.ps1
# Deskripsi: Menghidupkan kembali Windows Update (Revert Cosmic-Tier)
# Kompatibel: Windows 7, 10, 11 (Semua Versi)
# =====================================================================

# 1. Meminta Hak Akses Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Meminta hak akses Administrator..."
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Mulai menghidupkan kembali Windows Update..." -ForegroundColor Cyan

# 2. Buka Kunci Folder Download (SoftwareDistribution)
$sdPath = "$env:SystemRoot\SoftwareDistribution"
if (Test-Path $sdPath) {
    if ((Get-Item $sdPath) -is [System.IO.FileInfo]) {
        try {
            icacls.exe $sdPath /reset /q | Out-Null
            Remove-Item -Path $sdPath -Force -ErrorAction SilentlyContinue
        } catch {}
    }
}

# 3. Mengembalikan Startup & Recovery Layanan
$services = @{"wuauserv" = 3; "BITS" = 3; "dosvc" = 3; "UsoSvc" = 2; "WaaSMedicSvc" = 3}
foreach ($svc in $services.Keys) {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
    if (Test-Path $regPath) {
        try {
            Set-ItemProperty -Path $regPath -Name "Start" -Value $services[$svc] -ErrorAction SilentlyContinue
            & sc.exe failure $svc reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null
        } catch {}
    }
}

# 4. Menghapus WSUS Blackhole, Group Policy & [COSMIC-TIER] Silencer
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$auPath = "$wuPath\AU"
if (Test-Path $wuPath) {
    Remove-ItemProperty -Path $wuPath -Name "WUServer" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $wuPath -Name "WUStatusServer" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $wuPath -Name "UpdateServiceUrlAlternate" -ErrorAction SilentlyContinue
    # Revert Notification Silencer
    Remove-ItemProperty -Path $wuPath -Name "SetDisableUXWUAccess" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $wuPath -Name "DisableWindowsUpdateAccess" -ErrorAction SilentlyContinue
}
if (Test-Path $auPath) {
    Remove-ItemProperty -Path $auPath -Name "UseWUServer" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $auPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
}

# 5. [COSMIC-TIER] Menghidupkan Auto-Update Microsoft Store
$storePath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"
if (Test-Path $storePath) { Remove-ItemProperty -Path $storePath -Name "AutoDownload" -ErrorAction SilentlyContinue }

# 6. Menghidupkan Scheduled Tasks
if (Get-Command "Enable-ScheduledTask" -ErrorAction SilentlyContinue) {
    $taskPaths = @("\Microsoft\Windows\WindowsUpdate\", "\Microsoft\Windows\UpdateOrchestrator\")
    foreach ($path in $taskPaths) {
        try { Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue | Enable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null } catch {}
    }
}

# 7. Memulihkan Executables, Firewall, & Update Assistant
$executables = @("usoclient.exe", "wuauclt.exe", "waasmedic.exe", "sihclient.exe", "mousocoreworker.exe")
$sys32 = "$env:SystemRoot\System32"
foreach ($exe in $executables) {
    $bak = "$sys32\$exe.bak"
    if (Test-Path $bak) { try { Rename-Item -Path $bak -NewName $exe -Force -ErrorAction SilentlyContinue } catch {} }
    try { netsh advfirewall firewall delete rule name="Block WinUpdate $exe" | Out-Null } catch {}
}

$upgraderPaths = @("$env:SystemDrive\Windows10Upgrade", "$env:SystemDrive\WindowsUpdate")
foreach ($dir in $upgraderPaths) {
    $bak = "$dir\Windows10UpgraderApp.exe.bak"
    if (Test-Path $bak) { try { Rename-Item -Path $bak -NewName "Windows10UpgraderApp.exe" -Force -ErrorAction SilentlyContinue } catch {} }
}

# 8. Memulihkan File Hosts
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
try {
    $hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue
    if ($hostsContent) {
        $newHosts = $hostsContent | Where-Object { $_ -notmatch "# Blocked by Disable-WinUpdate" }
        Set-Content -Path $hostsPath -Value $newHosts -Force
    }
} catch {}

# 9. Munculkan Kembali Tombol "Update and Restart" & Settings UI
$uxPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (Test-Path $uxPath) { Remove-ItemProperty -Path $uxPath -Name "SettingsPageVisibility" -ErrorAction SilentlyContinue }

$auPaths = @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU", "HKCU:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU")
foreach ($p in $auPaths) {
    if (Test-Path $p) {
        Remove-ItemProperty -Path $p -Name "NoAUAsDefaultShutdownOption" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $p -Name "NoAUShutdownOption" -ErrorAction SilentlyContinue
    }
}

# 10. Menjalankan Layanan Utama
try { Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue } catch {}

Write-Host "`nPROSES SELESAI. Windows Update telah normal kembali 100%!" -ForegroundColor Green
Write-Host "Silakan Restart komputer Anda agar sistem merefresh konfigurasinya." -ForegroundColor Yellow
Pause