#Requires -Version 5.1
<#
.SYNOPSIS
    Downloads available game manuals from your Steam library.

.DESCRIPTION
    Uses the Steam Web API to fetch your game library, then checks each game
    for a hosted manual and downloads it if one exists.

.PARAMETER ApiKey
    Your Steam Web API key. Get one free at: https://steamcommunity.com/dev/apikey

.PARAMETER SteamId
    Your 64-bit Steam ID. Look it up at: https://steamid.io

.PARAMETER OutputDir
    Folder to save manuals into. Defaults to .\steam_manuals

.PARAMETER DelayMs
    Milliseconds to wait between requests. Default: 1500

.EXAMPLE
    .\Get-SteamManuals.ps1 -ApiKey "XXXX" -SteamId "76561198XXXXXXXXX"

.EXAMPLE
    .\Get-SteamManuals.ps1  # will prompt for key and ID interactively
#>
#Requires -Version 5.1
[CmdletBinding()]
param (
    [string] $ApiKey    = $env:STEAM_API_KEY,
    [string] $SteamId   = $env:STEAM_ID,
    [string] $OutputDir = ".\steam_manuals",
    [int]    $DelayMs   = 1500
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Prompt if not provided
if (-not $ApiKey)  { $ApiKey  = Read-Host "Steam API key" }
if (-not $SteamId) { $SteamId = Read-Host "Steam ID (64-bit)" }

if (-not $ApiKey -or -not $SteamId) {
    Write-Error "Both API key and Steam ID are required."
    exit 1
}

# Fetch library using a params hashtable (avoids ampersand issues in strings)
Write-Host "`nFetching your Steam library..." -ForegroundColor Cyan

$params = @{
    key                       = $ApiKey
    steamid                   = $SteamId
    include_appinfo           = "true"
    include_played_free_games = "true"
    format                    = "json"
}

try {
    $response = Invoke-RestMethod -Uri "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/" -Method Get -Body $params -TimeoutSec 20
} catch {
    Write-Error "Failed to fetch library: $_"
    exit 1
}

$games = $response.response.games
if (-not $games -or $games.Count -eq 0) {
    Write-Error "No games returned. Check your API key / Steam ID and make sure your Steam profile's game list is set to Public."
    exit 1
}

$games = $games | Sort-Object name
Write-Host "Found $($games.Count) games.`n" -ForegroundColor Green

# Prepare output folder
$outPath = (New-Item -ItemType Directory -Path $OutputDir -Force).FullName

# Sanitise a string for use as a filename
function ConvertTo-SafeName ([string]$Name) {
    $illegal = [System.IO.Path]::GetInvalidFileNameChars() -join ''
    $pattern = "[$([regex]::Escape($illegal))]"
    ($Name -replace $pattern, '_').Trim()
}

# Guess file extension from Content-Type header
function Get-Extension ([string]$ContentType, [string]$FinalUrl) {
    if ($ContentType -match 'pdf') { return '.pdf' }
    if ($ContentType -match 'zip') { return '.zip' }
    $urlExt = [System.IO.Path]::GetExtension(($FinalUrl -split '\?')[0])
    if ($urlExt) { return $urlExt }
    return '.bin'
}

# Main loop
$found   = 0
$skipped = 0
$errors  = 0
$total   = $games.Count

for ($i = 0; $i -lt $total; $i++) {
    $game  = $games[$i]
    $appId = $game.appid
    $name  = if ($game.name) { $game.name } else { "App $appId" }
    $idx   = $i + 1

    # Skip if already downloaded
    $existing = Get-ChildItem -Path $outPath -Filter "* ($appId).*" -ErrorAction SilentlyContinue
    if ($existing) {
        $skipped++
        continue
    }

    Write-Host "[$idx/$total] $name" -NoNewline

    $manualUrl = "https://store.steampowered.com/manual/$appId"

    try {
        $webRequest                   = [System.Net.HttpWebRequest]::Create($manualUrl)
        $webRequest.Method            = "GET"
        $webRequest.Timeout           = 15000
        $webRequest.UserAgent         = "SteamManualDownloader/1.0"
        $webRequest.AllowAutoRedirect = $true

        $webResponse = $webRequest.GetResponse()
        $contentType = $webResponse.ContentType

        if ($contentType -match 'text/html') {
            $webResponse.Close()
            Write-Host " ... no manual" -ForegroundColor DarkGray
        } else {
            $ext      = Get-Extension $contentType $webResponse.ResponseUri.AbsoluteUri
            $safeName = ConvertTo-SafeName $name
            $filePath = Join-Path $outPath "$safeName ($appId)$ext"

            $stream     = $webResponse.GetResponseStream()
            $fileStream = [System.IO.File]::Create($filePath)
            $buffer     = New-Object byte[] 8192
            while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $fileStream.Write($buffer, 0, $read)
            }
            $fileStream.Close()
            $stream.Close()
            $webResponse.Close()

            $sizeKb = [math]::Round((Get-Item $filePath).Length / 1KB)
            Write-Host " ... saved -> $(Split-Path $filePath -Leaf) ($sizeKb KB)" -ForegroundColor Green
            $found++
        }
    } catch [System.Net.WebException] {
        $statusCode = [int]$_.Exception.Response.StatusCode
        if ($statusCode -eq 404) {
            Write-Host " ... no manual" -ForegroundColor DarkGray
        } else {
            Write-Host " ... error ($statusCode)" -ForegroundColor Yellow
            $errors++
        }
    } catch {
        Write-Host " ... error: $_" -ForegroundColor Yellow
        $errors++
    }

    Start-Sleep -Milliseconds $DelayMs
}

# Summary
Write-Host "`n--------------------------------------------------"
Write-Host "Manuals downloaded : $found"   -ForegroundColor Green
Write-Host "Already present    : $skipped" -ForegroundColor Cyan
Write-Host "Errors             : $errors"  -ForegroundColor $(if ($errors) { 'Yellow' } else { 'Gray' })
Write-Host "Saved to           : $outPath" -ForegroundColor Cyan
