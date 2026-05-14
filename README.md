# Skport-Arknights-AutoCheckin

> [!NOTE]
> This script is specifically designed for **Arknights (明日方舟)**.
>
> It is **NOT** compatible with Arknights: Endfield (終末地).

A cross-platform (Windows / Linux / macOS) PowerShell script to automate the daily check-in for Arknights via the Skport platform. It uses a headless browser and Chrome DevTools Protocol (CDP) to handle authentication efficiently.

## ✨ Features

- **Cross-Platform**: Works on Windows, Linux, and macOS (requires PowerShell).
- **Headless Operation**: Runs in the background without opening a browser window.
- **Smart Authentication**: Extracts tokens directly from local storage using CDP.
- **Notifications**: Optional Telegram bot integration for daily status reports.

## 📋 Requirements

1. **PowerShell 7.0+** (Recommended) or **Windows PowerShell 5.1** (usually built-in)
2. **Chromium-based Browser**: Google Chrome or Microsoft Edge installed.

> [!IMPORTANT]
> **Encoding Note for Windows PowerShell 5.1**:
> If you are using Windows PowerShell 5.1, the script file **must** be saved with **UTF-8 with BOM** encoding. This is required for the script to correctly interpret special characters (like Emojis and symbols) used in the code.

## ⚙️ Configuration

Open `Skport_Arknights_AutoCheckin.ps1` and edit the following settings at the top of the file:

```powershell
# --- Required ---
$SK_OAUTH_CRED_KEY = "your_key_here" # Found in your browser cookies for skport.com
$uid               = "12345678"      # Your Arknights Game ID
$server            = "2"             # Asia=2 / Americas=3 / Europe=3
$language          = "zh_Hant"       # english=en / 繁體中文=zh_Hant / 简体中文=zh_Hans / 日本語=ja / 한국어=ko

# --- Optional Telegram Notifications ---
$telegram_notify   = $false          # Set to $true to enable
$myTelegramID      = ""              # Your Telegram Chat ID
$telegramBotToken  = ""              # Your Telegram Bot Token

# --- Browser Selection ---
$BrowserChoice     = "auto"          # auto / chrome / edge / or "C:\path\to\exe"
```

### How to find $SK_OAUTH_CRED_KEY?
1. Login to the [Skport Arknights page](https://game.skport.com/arknights/sign-in).
2. Press `F12` to open Developer Tools.
3. Go to the **Application** tab -> **Cookies** -> `https://game.skport.com`.
4. Copy the value of the cookie named `SK_OAUTH_CRED_KEY`.

## 🚀 Usage

Run the script manually from your terminal:

```powershell
pwsh ./Skport_Arknights_AutoCheckin.ps1
```

## ⏰ Automation

### Windows (Task Scheduler)
Create a task to run `pwsh.exe` with the argument `-File "C:\path\to\Skport_Arknights_AutoCheckin.ps1"`.

### Linux / macOS (Crontab)
Add the following to your crontab (`crontab -e`) to run every day at 09:00:
```bash
0 9 * * * /usr/bin/pwsh /path/to/Skport_Arknights_AutoCheckin.ps1
```

## ⚖️ License

Distributed under the **MIT License**.

## ⚠️ Disclaimer
This tool is for educational purposes only. Use it at your own risk. The author is not responsible for any account bans or issues related to the use of this script.
