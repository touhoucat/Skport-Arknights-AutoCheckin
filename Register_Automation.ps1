# Skport-Arknights Automation Register ( Windows / Linux / macOS )
# This script registers Skport_Arknights_AutoCheckin.ps1 to run at system startup and daily at 00:00.

# ── Auto-Elevate to Administrator (Windows Only) ──────────────────────
if ($IsWindows -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "🛡️ Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process (Get-Process -Id $PID).Path -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ScriptName = "Skport_Arknights_AutoCheckin.ps1"
$ScriptPath = Join-Path $PSScriptRoot $ScriptName

if (!(Test-Path $ScriptPath)) {
    Write-Host "❌ Error: $ScriptName not found in $PSScriptRoot" -ForegroundColor Red
    Pause
    exit 1
}

# Get the path to the PowerShell executable
$PwshExe = (Get-Process -Id $PID).Path

Write-Host "🚀 Registering Automation for: $ScriptPath" -ForegroundColor Cyan

# ── Windows (Task Scheduler) ──────────────────────────────────────────
if ($IsWindows -or $env:OS -eq "Windows_NT") {
    $TaskName = "Skport_Arknights_AutoCheckin"
    $Action = New-ScheduledTaskAction -Execute $PwshExe -Argument "-NoProfile -WindowStyle Hidden -File `"$ScriptPath`""
    
    # Trigger 1: At Logon
    $T1 = New-ScheduledTaskTrigger -AtLogOn
    # Trigger 2: Daily at 00:00
    $T2 = New-ScheduledTaskTrigger -Daily -At "12:00 AM"

    try {
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $T1, $T2 -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) -Force | Out-Null
        Write-Host "✅ Windows Task Scheduler: Registered '$TaskName'" -ForegroundColor Green
        Write-Host "   - Runs at logon" -ForegroundColor Gray
        Write-Host "   - Runs daily at 00:00" -ForegroundColor Gray
    } catch {
        Write-Host "❌ Windows: Failed to register task. Please run as Administrator." -ForegroundColor Red
    }
}

# ── Linux (Crontab) ───────────────────────────────────────────────────
elseif ($IsLinux) {
    $CronDaily = "0 0 * * * `"$PwshExe`" -File `"$ScriptPath`" > /dev/null 2>&1"
    $CronReboot = "@reboot `"$PwshExe`" -File `"$ScriptPath`" > /dev/null 2>&1"
    
    $CurrentCron = try { crontab -l 2>$null } catch { "" }
    $NewCron = ($CurrentCron -split "`n" | Where-Object { $_ -notmatch $ScriptName })
    $NewCron += $CronDaily
    $NewCron += $CronReboot
    
    $TempFile = [System.IO.Path]::GetTempFileName()
    $NewCron -join "`n" | Out-File $TempFile -Encoding UTF8
    
    try {
        & crontab $TempFile
        Write-Host "✅ Linux Crontab: Updated." -ForegroundColor Green
        Write-Host "   - Added @reboot and 00:00 schedule" -ForegroundColor Gray
    } finally {
        Remove-Item $TempFile
    }
}

# ── macOS (LaunchAgent) ────────────────────────────────────────────────
elseif ($IsMacOS) {
    $Label = "com.user.arknights.autocheckin"
    $PlistPath = Join-Path $env:HOME "Library/LaunchAgents/$Label.plist"
    
    $PlistContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$Label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PwshExe</string>
        <string>-File</string>
        <string>$ScriptPath</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>0</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
"@
    try {
        $PlistContent | Out-File $PlistPath -Encoding UTF8
        & launchctl unload $PlistPath 2>$null
        & launchctl load $PlistPath
        Write-Host "✅ macOS LaunchAgent: Registered at $PlistPath" -ForegroundColor Green
    } catch {
        Write-Host "❌ macOS: Failed to create LaunchAgent." -ForegroundColor Red
    }
}

Write-Host "✨ Automation setup complete!" -ForegroundColor Cyan
Pause
