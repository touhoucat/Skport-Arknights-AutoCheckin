# Skport-Arknights-AutoCheckin ( Windows / Linux / macOS )

# ── Settings ───────────────────────────────────────────
$SK_OAUTH_CRED_KEY = "AAbbCC99Sk0aUtH1XXXCrED8KeY2kI6e" # your skport SK_OAUTH_CRED_KEY in cookie
$uid = "12345678"                                       # your Arknights game ID
$server = "2"                                           # Asia=2 / Americas=3 / Europe=3
$language = "zh_Hant"                                   # english=en / 繁體中文=zh_Hant / 简体中文=zh_Hans / 日本語=ja / 한국어=ko

$telegram_notify = $false
$myTelegramID = ""
$telegramBotToken = ""

$BrowserChoice = "auto" # auto / chrome / edge / <absolute path>
# ──────────────────────────────────────────────────────

$GlobalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$IsLinuxPlatform = $PSVersionTable.PSEdition -eq 'Core' -and $IsLinux
$baseUrl = "https://zonai.skport.com"
$DefaultHeaders = @{
    'Accept'          = '*/*'
    'Accept-Encoding' = 'gzip, deflate, br'
    'Content-Type'    = 'application/json'
    'User-Agent'      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
    'Referer'         = 'https://game.skport.com/'
    'Origin'          = 'https://game.skport.com'
    'platform'        = '3'
    'vName'           = '1.0.0'
    'Sec-Fetch-Dest'  = 'empty'
    'Sec-Fetch-Mode'  = 'cors'
    'Sec-Fetch-Site'  = 'same-site'
}

# ── Helpers ────────────────────────────────────────────
function Send-WsFrame ($Ws, $Json) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Json)
    $Ws.SendAsync([System.ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
}

# ── Token ──────────────────────────────────────────────
function Get-SkToken {
    param ([string] $OAuthKey)

    $loginUrl = "https://game.skport.com/arknights/sign-in?header=0&hg_media=skport"
    $port = Get-Random -Minimum 9000 -Maximum 9999
    $profileDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "CDP_Skport_$port")
    if (Test-Path $profileDir) { Remove-Item $profileDir -Recurse -Force -ErrorAction SilentlyContinue }

    # --- Cross-platform browser path resolution ---
    $searchPaths = [System.Collections.Generic.List[string]]::new()
    if ($BrowserChoice -ne "edge") {
        $searchPaths.Add("C:\Program Files\Google\Chrome\Application\chrome.exe")
        $searchPaths.Add("C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
        $searchPaths.Add("/usr/bin/google-chrome")
        $searchPaths.Add("/usr/bin/chromium")
        $searchPaths.Add("/usr/bin/chromium-browser")
        $searchPaths.Add("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    }
    if ($BrowserChoice -ne "chrome") {
        $searchPaths.Add("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
        $searchPaths.Add("/usr/bin/microsoft-edge")
        $searchPaths.Add("/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge")
    }

    $exe = if ($BrowserChoice -notin @("auto", "chrome", "edge")) {
        $BrowserChoice
    }
    else {
        $searchPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    }

    if ([string]::IsNullOrWhiteSpace($exe) -or !(Test-Path $exe)) {
        return @{ OK = $false; Value = "Browser not found." }
    }

    $engine = if ($exe -match "edge") { "Edge" } else { "Chrome/Chromium" }
    Write-Host "│  🌐 $engine" -ForegroundColor Cyan

    # --- Browser args  ---
    $argList = [System.Collections.Generic.List[string]]@(
        "--headless=new"
        "--remote-debugging-port=$port"
        "--user-data-dir=`"$profileDir`""
        "--incognito"
        "--no-first-run"
        "--no-default-browser-check"
        "--mute-audio"
        "--disable-gpu"
        "--disable-dev-shm-usage"
        "--disable-extensions"
        "--disable-background-networking"
        "--disable-default-apps"
        "--metrics-recording-only"
        "--password-store=basic"
        "--use-mock-keychain"
        "--disable-logging"
        "--log-level=3"
        "about:blank"
    )
    if ($IsLinuxPlatform) {
        $argList.Add("--disable-software-rasterizer")
        $argList.Add("--single-process")
        $argList.Add("--no-zygote")
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new($exe, ($argList -join " "))
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.BeginErrorReadLine()

    # --- Poll CDP ---
    $wsUrl = $null
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 500
        try {
            $targets = Invoke-RestMethod -Uri "http://localhost:$port/json" -TimeoutSec 3 -ErrorAction Stop
            $wsUrl = ($targets | Where-Object { $_.type -eq "page" } | Select-Object -First 1).webSocketDebuggerUrl
            if ($wsUrl) { break }
        }
        catch {}
    }

    if (!$wsUrl) {
        try { Stop-Process $proc.Id -Force -ErrorAction SilentlyContinue; $proc.Dispose() } catch {}
        return @{ OK = $false; Value = "Timeout: CDP unavailable." }
    }

    # --- Extract token via WebSocket ---
    $token = $null; $ws = $null; $cts = $null
    $buf = [byte[]]::new(8192);
    $seg = [System.ArraySegment[byte]]::new($buf)
    try {
        $ws = [System.Net.WebSockets.ClientWebSocket]::new()
        $cts = [System.Threading.CancellationTokenSource]::new()
        $ws.ConnectAsync([uri]$wsUrl, $cts.Token).Wait()

        Send-WsFrame $ws "{`"id`":1,`"method`":`"Network.setCookie`",`"params`":{`"name`":`"SK_OAUTH_CRED_KEY`",`"value`":`"$OAuthKey`",`"domain`":`".skport.com`",`"path`":`"/`"}}"
        Start-Sleep -Milliseconds 500
        Send-WsFrame $ws "{`"id`":2,`"method`":`"Page.navigate`",`"params`":{`"url`":`"$loginUrl`"}}"

        for ($i = 0; $i -lt 60; $i++) {
            Start-Sleep -Milliseconds 500
            $id = 100 + $i
            Send-WsFrame $ws "{`"id`":$id,`"method`":`"Runtime.evaluate`",`"params`":{`"expression`":`"localStorage.getItem('SK_TOKEN_CACHE_KEY')`",`"returnByValue`":true}}"

            $deadline = [DateTime]::UtcNow.AddMilliseconds(1500)
            while ([DateTime]::UtcNow -lt $deadline) {
                $ms = [System.IO.MemoryStream]::new()
                try {
                    do {
                        $t = $ws.ReceiveAsync($seg, $cts.Token)
                        if (!$t.Wait(500)) { break }
                        $ms.Write($buf, 0, $t.Result.Count)
                    } while (!$t.Result.EndOfMessage)
                    if ($ms.Length -gt 0) {
                        $frame = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
                        if ($frame -match "`"id`":$id") {
                            if ($frame -notmatch "`"value`":null" -and $frame -notmatch "SecurityError") { $token = $frame }
                            break
                        }
                    }
                    else { break }
                }
                catch { break } finally { $ms.Dispose() }
            }
            if ($token) { break }
        }
        if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "done", $cts.Token).Wait()
        }
    }
    catch { $token = $null }
    finally { if ($ws) { $ws.Dispose() }; if ($cts) { $cts.Dispose() } }

    try { Stop-Process $proc.Id -Force -ErrorAction SilentlyContinue; $proc.Dispose() } catch {}
    Start-Sleep -Milliseconds 200
    Remove-Item $profileDir -Recurse -Force -ErrorAction SilentlyContinue

    if ($token) {
        try {
            $val = ($token | ConvertFrom-Json).result.result.value
            if (![string]::IsNullOrWhiteSpace($val)) { return @{ OK = $true; Value = $val } }
        }
        catch {}
    }
    return @{ OK = $false; Value = "Token not found (credentials may be expired)." }
}

# ── Signature ──────────────────────────────────────────
function New-SkportSignature ($Body, $Headers, $Token) {
    $raw = "/api/v1/game/attendance" + $Body + $Headers["timestamp"] + ([ordered]@{ platform = $Headers["platform"]; timestamp = $Headers["timestamp"]; dId = ""; vName = $Headers["vName"] } | ConvertTo-Json -Compress)

    $hmac = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($Token))
    try { $hex = [System.BitConverter]::ToString($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($raw))).Replace("-", "").ToLower() }
    finally { $hmac.Dispose() }

    $md5 = [System.Security.Cryptography.MD5]::Create()
    try { return [System.BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hex))).Replace("-", "").ToLower() }
    finally { $md5.Dispose() }
}

# ══ Main ════════════════════════════════════════════════
Write-Host "╔══════════════════════════════╗" -ForegroundColor DarkCyan
Write-Host "║   Skport Auto Sign-in Bot    ║" -ForegroundColor DarkCyan
Write-Host "╚══════════════════════════════╝" -ForegroundColor DarkCyan
Write-Host "┌─ 🤖 UID: $uid" -ForegroundColor DarkCyan

$tk = Get-SkToken -OAuthKey $SK_OAUTH_CRED_KEY

if (-not $tk.OK) {
    $result = "❌ [$uid]: $($tk.Value)"
    Write-Host "└─ $result" -ForegroundColor Red
}
else {
    Write-Host "│  🔑 $($tk.Value)" -ForegroundColor DarkYellow

    $ts = [Math]::Floor([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).ToString()
    $body = "{`"uid`":`"$uid`"}"
    $headers = $DefaultHeaders.Clone()
    $headers["cred"] = $SK_OAUTH_CRED_KEY
    $headers["sk-game-role"] = "3_$($uid)_$server"
    $headers["sk-language"] = $language
    $headers["timestamp"] = $ts
    $headers["sign"] = New-SkportSignature -Body $body -Headers $headers -Token $tk.Value

    try {
        $resp = Invoke-RestMethod "$baseUrl/api/v1/game/attendance" -Method Post -Headers $headers -Body $body -TimeoutSec 10 -ErrorAction Stop
        $ok = $resp.code -ne 10000
        $msg = if ($resp.code -eq 10000) { "Token expired after refresh!" } else { $resp.message }
    }
    catch {
        $ok = $false; $msg = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try { $j = $_.ErrorDetails.Message | ConvertFrom-Json; if ($j.message) { $msg = $j.message } } catch {}
        }
    }

    $result = "$(if ($ok) { '✅' } else { '❌' }) [$uid]: $msg"
    Write-Host "└─ $result" -ForegroundColor $(if ($ok) { "Green" } else { "Red" })
}

if ($telegram_notify -and $telegramBotToken -and $myTelegramID) {
    $tgBody = @{ chat_id = $myTelegramID; text = $result; parse_mode = "HTML" } | ConvertTo-Json -Depth 2 -Compress
    try { Invoke-RestMethod "https://api.telegram.org/bot$telegramBotToken/sendMessage" -Method Post -Body $tgBody -ContentType "application/json" -TimeoutSec 10 | Out-Null } catch {}
}

Write-Host "   ⏱️ Done: $([math]::Round($GlobalStopwatch.Elapsed.TotalSeconds, 1))s" -ForegroundColor DarkGray
