# Claude Code SEO Skills Installer for Windows
# Usage: irm https://raw.githubusercontent.com/rachid-log/claude-seo-skills/main/install.ps1 | iex

param(
    [string]$WordPressUrl = "",
    [string]$WordPressApiKey = "",
    [switch]$SkipPrompts
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Claude Code SEO Skills Installer" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Helper to refresh PATH in current session
function Refresh-SessionPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"

    $programNode = Join-Path $env:ProgramFiles "nodejs"
    if (Test-Path $programNode) {
        $env:Path = "$programNode;$env:Path"
    }

    $npmGlobal = Join-Path $env:APPDATA "npm"
    if (Test-Path $npmGlobal) {
        $env:Path = "$npmGlobal;$env:Path"
    }
}

# 1. Hardware-Locked Telemetry & Registration
$userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }

$rawHwid = $null
try {
    $rawHwid = (Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID
} catch { }

if (-not $rawHwid) {
    try {
        $rawHwid = (Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID
    } catch { }
}

if (-not $rawHwid) {
    $rawHwid = "FALLBACK-" + $env:COMPUTERNAME
}

$hwHash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($rawHwid))) -replace '-'
$token = ($hwHash.Substring(0,16) -replace '(.{4})', '$1-').TrimEnd('-')
$sessionId = [Guid]::NewGuid().ToString('N')
$userName = if ($env:USERNAME) { $env:USERNAME } else { "user" }
$computerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { "PC" }

Write-Host "[*] Device ID: $token" -ForegroundColor Yellow
Write-Host "[*] Contacting authorization gateway..." -ForegroundColor Cyan

$gatewayBase = "https://n8n.srv1089640.hstgr.cloud/webhook/claude-skills-auth"
$requestUrl = "${gatewayBase}?action=request&session=$sessionId&token=$token&username=$userName&computer=$computerName"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    $reqRes = Invoke-RestMethod -Uri $requestUrl -Method GET
} catch {
    Write-Host "[-] Unable to contact license server: $($_.Exception.Message)" -ForegroundColor Red
    return
}

Write-Host "[*] Request sent. Waiting for administrator approval" -NoNewline -ForegroundColor Yellow

# Polling for approval (up to 5 minutes)
$approved = $false
$maxSeconds = 300
$elapsed = 0

while ($elapsed -lt $maxSeconds) {
    Start-Sleep -Seconds 4
    $elapsed += 4
    try {
        $checkUrl = "${gatewayBase}?action=check&session=$sessionId"
        $statusRes = Invoke-RestMethod -Uri $checkUrl -Method GET
        if ($statusRes.status -eq "approved") {
            $approved = $true
            break
        } elseif ($statusRes.status -eq "rejected") {
            Write-Host "`n[-] Authorization rejected by administrator." -ForegroundColor Red
            return
        }
    } catch {
        # ignore transient network errors during poll
    }
    Write-Host "." -NoNewline -ForegroundColor DarkGray
}

if (-not $approved) {
    Write-Host "`n[-] Authorization request timed out. Please contact administrator." -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "[+] Authorization granted! Proceeding with installation..." -ForegroundColor Green
Write-Host ""

# Helper to detect interactive terminal
$canPrompt = -not $SkipPrompts -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected

# 2. Check & Install Node.js
Refresh-SessionPath

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Node.js not detected." -ForegroundColor Yellow
    $installNode = "y"
    if ($canPrompt) {
        $installNode = Read-Host "Would you like to auto-install Node.js LTS now? (Y/n)"
    }
    if ($installNode -notmatch "^[nN]") {
        $nodeInstalled = $false

        # Attempt 1: winget
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "[*] Attempting installation via winget..." -ForegroundColor Cyan
            try {
                winget install OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
                Refresh-SessionPath
                if (Get-Command node -ErrorAction SilentlyContinue) { $nodeInstalled = $true }
            } catch { }
        }

        # Attempt 2: Direct official MSI download fallback
        if (-not $nodeInstalled) {
            Write-Host "[*] Downloading official Node.js LTS installer from nodejs.org..." -ForegroundColor Cyan
            $nodeMsi = Join-Path ([System.IO.Path]::GetTempPath()) "node-lts-setup.msi"
            try {
                Invoke-WebRequest -Uri "https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi" -OutFile $nodeMsi
                Write-Host "[*] Running Node.js silent installation (this takes ~30 seconds)..." -ForegroundColor Cyan
                $msiProcess = Start-Process msiexec.exe -ArgumentList "/i `"$nodeMsi`" /qn /norestart" -Wait -PassThru
                Refresh-SessionPath
                if (Get-Command node -ErrorAction SilentlyContinue) { $nodeInstalled = $true }
            } catch {
                Write-Host "[-] MSI download/install error: $($_.Exception.Message)" -ForegroundColor Red
            } finally {
                if (Test-Path $nodeMsi) { Remove-Item -Force $nodeMsi -ErrorAction SilentlyContinue }
            }
        }

        if (-not $nodeInstalled) {
            Write-Host "[-] Could not automatically install Node.js." -ForegroundColor Red
            Write-Host "[-] Please download and run the installer from: https://nodejs.org" -ForegroundColor Yellow
            Write-Host "[-] After installation, close this window, open a fresh PowerShell, and re-run this command." -ForegroundColor Yellow
            return
        }
    } else {
        Write-Host "[-] Node.js is required. Please install from https://nodejs.org and re-run." -ForegroundColor Red
        return
    }
}

Refresh-SessionPath
$nodeVer = (node -v).Trim()
Write-Host "[+] Node.js detected: $nodeVer" -ForegroundColor Green

# 3. Check & Install Claude Code CLI
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Claude Code CLI not found. Installing globally via npm..." -ForegroundColor Cyan
    try {
        npm install -g @anthropic-ai/claude-code
        Refresh-SessionPath
        if (Get-Command claude -ErrorAction SilentlyContinue) {
            Write-Host "[+] Claude Code installed successfully." -ForegroundColor Green
        } else {
            Write-Host "[!] Claude Code installed via npm. If 'claude' is not recognized immediately, restart PowerShell after installation." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[-] Failed to install Claude Code CLI: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "[+] Claude Code CLI is already installed." -ForegroundColor Green
}

# 4. Setup Destination Directory
$skillsDest = Join-Path $userHome ".claude\skills"

if (-not (Test-Path $skillsDest)) {
    New-Item -ItemType Directory -Force -Path $skillsDest | Out-Null
}

Write-Host "[*] Target directory: $skillsDest" -ForegroundColor Cyan

# 5. Acquire and Extract Skills
$localSkillsPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot "skills" } else { $null }

if ($localSkillsPath -and (Test-Path $localSkillsPath)) {
    Write-Host "[*] Installing skills from local repository..." -ForegroundColor Cyan
    Get-ChildItem -Directory $localSkillsPath | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $skillsDest -Recurse -Force
        Write-Host "  [+] Installed: $($_.Name)" -ForegroundColor Green
    }
} else {
    Write-Host "[*] Downloading skills from GitHub (rachid-log/claude-seo-skills)..." -ForegroundColor Cyan
    $repoZipUrl = "https://github.com/rachid-log/claude-seo-skills/archive/refs/heads/main.zip"
    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "claude-seo-skills-$([Guid]::NewGuid().ToString('N')).zip"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "claude-seo-skills-extract-$([Guid]::NewGuid().ToString('N'))"

    try {
        Invoke-RestMethod -Uri $repoZipUrl -OutFile $tempZip

        Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
        $extractedSkills = Join-Path $tempDir "claude-seo-skills-main\skills"

        if (Test-Path $extractedSkills) {
            Get-ChildItem -Directory $extractedSkills | ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $skillsDest -Recurse -Force
                Write-Host "  [+] Installed: $($_.Name)" -ForegroundColor Green
            }
        } else {
            throw "Skills folder not found in downloaded archive."
        }
    } catch {
        Write-Host "[-] Download failed: $($_.Exception.Message)" -ForegroundColor Red
        return
    } finally {
        if (Test-Path $tempZip) { Remove-Item -Force $tempZip -ErrorAction SilentlyContinue }
        if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
    }
}

# 6. Optional Royal MCP Setup
$targetWpUrl = $WordPressUrl
$targetApiKey = $WordPressApiKey

if (-not $targetWpUrl -and $canPrompt) {
    Write-Host ""
    $connectWp = Read-Host "Would you like to connect a WordPress site via Royal MCP? (y/N)"
    if ($connectWp -match "^[yY]") {
        $targetWpUrl = Read-Host "Enter your WordPress site URL (e.g. https://example.com)"
        $targetApiKey = Read-Host "Enter your WordPress API Key (leave empty for OAuth)"
    }
}

if ($targetWpUrl) {
    $cleanUrl = $targetWpUrl.Trim().TrimEnd('/')
    # Normalize URL: if user passed endpoint directly or domain only
    if ($cleanUrl -match "/wp-json/royal-mcp/v1/mcp$") {
        $mcpEndpoint = $cleanUrl
    } elseif ($cleanUrl -match "^https?://") {
        $mcpEndpoint = "$cleanUrl/wp-json/royal-mcp/v1/mcp"
    } else {
        $mcpEndpoint = "https://$cleanUrl/wp-json/royal-mcp/v1/mcp"
    }

    Write-Host "[*] Registering Royal MCP with Claude Code ($mcpEndpoint)..." -ForegroundColor Cyan
    try {
        Refresh-SessionPath
        if (Get-Command claude -ErrorAction SilentlyContinue) {
            if ($targetApiKey -and $targetApiKey.Trim()) {
                claude mcp add --transport http royal-wordpress $mcpEndpoint --header "Authorization: Bearer $($targetApiKey.Trim())"
            } else {
                claude mcp add --transport http royal-wordpress $mcpEndpoint
            }
            Write-Host "[+] Royal MCP registered successfully." -ForegroundColor Green
        } else {
            Write-Host "[!] Claude command not in current session yet. Run manually once you restart PowerShell:" -ForegroundColor Yellow
            if ($targetApiKey -and $targetApiKey.Trim()) {
                Write-Host "    claude mcp add --transport http royal-wordpress $mcpEndpoint --header `"Authorization: Bearer $($targetApiKey.Trim())`""
            } else {
                Write-Host "    claude mcp add --transport http royal-wordpress $mcpEndpoint"
            }
        }
    } catch {
        Write-Host "[-] Failed to register MCP automatically. Run manually:" -ForegroundColor Yellow
        Write-Host "    claude mcp add --transport http royal-wordpress $mcpEndpoint"
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Skills installed to: $skillsDest"
Write-Host "Tip: Restart PowerShell once so 'claude' is recognized globally." -ForegroundColor Cyan
Write-Host "Run 'claude' in any project to use your SEO skills."
Write-Host ""
