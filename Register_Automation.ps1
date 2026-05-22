# This script registers Skport_Arknights_AutoCheckin.ps1 to run at system startup and daily.

# ── Settings ──────────────────────────────────────────────────────────
$ScriptName = "Skport_Arknights_AutoCheckin.ps1"
$AutoCheckinTime = "00:00"  # Format: HH:mm (24-hour clock)
# ──────────────────────────────────────────────────────────────────────

# ── Auto-Elevate to Administrator (Windows Only) ──────────────────────
if ($IsWindows -or $env:OS -eq "Windows_NT") {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "🛡️  Standard user detected. Requesting Administrator privileges..." -ForegroundColor Yellow
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        try {
            Start-Process (Get-Process -Id $PID).Path -ArgumentList $arguments -Verb RunAs -ErrorAction Stop
            exit
        }
        catch {
            Write-Host "❌ Failed to elevate: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Please right-click and 'Run as Administrator' manually." -ForegroundColor White
            Pause
            exit 1
        }
    }
}

$ScriptPath = Join-Path $PSScriptRoot $ScriptName

if (!(Test-Path $ScriptPath)) {
    Write-Host "❌ Error: $ScriptName not found in $PSScriptRoot" -ForegroundColor Red
    Pause
    exit 1
}

# Parse time for different platforms
$timeParts = $AutoCheckinTime -split ":"
$hour = [int]$timeParts[0]
$minute = [int]$timeParts[1]
$winTime = "$($hour.ToString('00')):$($minute.ToString('00'))"

# Get the path to the PowerShell executable
$PwshExe = (Get-Process -Id $PID).Path

Write-Host "🚀 Registering Automation for: $ScriptPath" -ForegroundColor Cyan
Write-Host "   Schedule: Startup & Daily at $AutoCheckinTime" -ForegroundColor DarkGray

# ── Windows (Task Scheduler) ──────────────────────────────────────────
if ($IsWindows -or $env:OS -eq "Windows_NT") {
    $TaskName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptName)
    $Action = New-ScheduledTaskAction -Execute $PwshExe -Argument "-NoProfile -WindowStyle Hidden -File `"$ScriptPath`""
    
    # Trigger 1: At Logon with 1 minute delay
    $T1 = New-ScheduledTaskTrigger -AtLogOn
    $T1.Delay = "PT1M"
    # Trigger 2: Daily at the specified time
    $T2 = New-ScheduledTaskTrigger -Daily -At $winTime

    try {
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $T1, $T2 -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) -Force | Out-Null
        Write-Host "✅ Windows Task Scheduler: Registered '$TaskName'" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Windows: Failed to register task. (Error: $($_.Exception.Message))" -ForegroundColor Red
    }
}

# ── Linux (Crontab) ───────────────────────────────────────────────────
elseif ($IsLinux) {
    $CronDaily = "$minute $hour * * * `"$PwshExe`" -File `"$ScriptPath`" > /dev/null 2>&1"
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
    }
    finally {
        Remove-Item $TempFile
    }
}

# ── macOS (LaunchAgent) ────────────────────────────────────────────────
elseif ($IsMacOS) {
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptName)
    $Label = "com.user.$($BaseName.ToLower().Replace('_', '.'))"
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
        <integer>$hour</integer>
        <key>Minute</key>
        <integer>$minute</integer>
    </dict>
</dict>
</plist>
"@
    try {
        $PlistContent | Out-File $PlistPath -Encoding UTF8
        & launchctl unload $PlistPath 2>$null
        & launchctl load $PlistPath
        Write-Host "✅ macOS LaunchAgent: Registered at $PlistPath" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ macOS: Failed to create LaunchAgent." -ForegroundColor Red
    }
}

Write-Host "✨ Automation setup complete!" -ForegroundColor Cyan
Pause
