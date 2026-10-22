# Claude Skills Installer for Windows
# Usage: irm https://raw.githubusercontent.com/rachid-log/claude-seo-skills/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Claude Skills Installer" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

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
Write-Host "[+] Authorization granted! Installing skills..." -ForegroundColor Green
Write-Host ""

# 2. Setup Destination Directory
$skillsDest = Join-Path $userHome ".claude\skills"

if (-not (Test-Path $skillsDest)) {
    New-Item -ItemType Directory -Force -Path $skillsDest | Out-Null
}

Write-Host "[*] Target directory: $skillsDest" -ForegroundColor Cyan

# 3. Acquire and Extract Skills
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

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Skills installed to: $skillsDest"
Write-Host ""
