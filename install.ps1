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

# Helper to detect interactive terminal
$canPrompt = -not $SkipPrompts -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected

# 1. Check Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Node.js not detected." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $installNode = "y"
        if ($canPrompt) {
            $installNode = Read-Host "Would you like to install Node.js via winget now? (Y/n)"
        }
        if ($installNode -notmatch "^[nN]") {
            Write-Host "[*] Installing Node.js LTS via winget..." -ForegroundColor Cyan
            winget install OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
    } else {
        Write-Host "[-] Please install Node.js (18+) from https://nodejs.org before continuing." -ForegroundColor Red
        return
    }
} else {
    $nodeVer = (node -v).Trim()
    Write-Host "[+] Node.js detected: $nodeVer" -ForegroundColor Green
}

# 2. Check Claude Code CLI
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Claude Code CLI not found. Installing globally via npm..." -ForegroundColor Cyan
    try {
        npm install -g @anthropic-ai/claude-code
        Write-Host "[+] Claude Code installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to install Claude Code CLI. Please run: npm install -g @anthropic-ai/claude-code" -ForegroundColor Red
    }
} else {
    Write-Host "[+] Claude Code CLI is already installed." -ForegroundColor Green
}

# 3. Setup Destination Directory
$userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$skillsDest = Join-Path $userHome ".claude\skills"

if (-not (Test-Path $skillsDest)) {
    New-Item -ItemType Directory -Force -Path $skillsDest | Out-Null
}

Write-Host "[*] Target directory: $skillsDest" -ForegroundColor Cyan

# 4. Acquire and Extract Skills
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
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
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

# 5. Optional Royal MCP Setup
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
    if ($cleanUrl -and $cleanUrl.StartsWith("http")) {
        $mcpEndpoint = "$cleanUrl/wp-json/royal-mcp/v1/mcp"
        Write-Host "[*] Registering Royal MCP with Claude Code ($cleanUrl)..." -ForegroundColor Cyan
        try {
            if ($targetApiKey -and $targetApiKey.Trim()) {
                claude mcp add --transport http royal-wordpress $mcpEndpoint --header "Authorization: Bearer $($targetApiKey.Trim())"
            } else {
                claude mcp add --transport http royal-wordpress $mcpEndpoint
            }
            Write-Host "[+] Royal MCP registered successfully." -ForegroundColor Green
        } catch {
            Write-Host "[-] Failed to register MCP automatically. Run manually:" -ForegroundColor Yellow
            Write-Host "    claude mcp add --transport http royal-wordpress $mcpEndpoint"
        }
    } else {
        Write-Host "[!] Invalid URL provided. Skipping Royal MCP setup." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Skills installed to: $skillsDest"
Write-Host "Run 'claude' in any project to use your SEO skills."
Write-Host ""
