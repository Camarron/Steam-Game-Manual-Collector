# Get-SteamManuals

A PowerShell script that automatically downloads every available game manual from your Steam library.

It walks through your entire game list, checks the Steam store for a hosted manual for each title, and saves any it finds to a local folder — skipping games that have no manual and resuming gracefully if you've run it before.

---

## Requirements

- Windows PowerShell 5.1 or later (included in Windows 10/11)
- A **Steam Web API key** — get one free at [steamcommunity.com/dev/apikey](https://steamcommunity.com/dev/apikey)
- Your **64-bit Steam ID** — look it up at [steamid.io](https://steamid.io)
- Your Steam profile's game list must be set to **Public**

---

## Usage

### Basic (interactive prompts)

```powershell
.\Get-SteamManualsv2.ps1
```

The script will prompt you for your API key and Steam ID if they aren't provided.

### With parameters

```powershell
.\Get-SteamManualsv2.ps1 -ApiKey "YOUR_API_KEY" -SteamId "76561198XXXXXXXXX"
```

### With a custom output folder

```powershell
.\Get-SteamManualsv2.ps1 -ApiKey "YOUR_API_KEY" -SteamId "76561198XXXXXXXXX" -OutputDir "C:\Manuals"
```

---

## Parameters

| Parameter    | Description                                              | Default           |
|--------------|----------------------------------------------------------|-------------------|
| `-ApiKey`    | Your Steam Web API key                                   | `$env:STEAM_API_KEY` |
| `-SteamId`   | Your 64-bit Steam ID                                     | `$env:STEAM_ID`   |
| `-OutputDir` | Folder to save manuals into                              | `.\steam_manuals` |
| `-DelayMs`   | Milliseconds to wait between requests (be nice to Steam) | `1500`            |

### Using environment variables

You can set your credentials as environment variables to avoid typing them each time:

```powershell
$env:STEAM_API_KEY = "YOUR_API_KEY"
$env:STEAM_ID      = "76561198XXXXXXXXX"
.\Get-SteamManualsv2.ps1
```

---

## Output

Manuals are saved as:

```
GameName (AppID).pdf
GameName (AppID).zip
```

The script detects the file type from the server's `Content-Type` header and falls back to the URL extension. Files already present in the output folder are skipped automatically, so re-running the script after adding new games to your library is safe.

A summary is printed at the end:

```
--------------------------------------------------
Manuals downloaded : 12
Already present    : 304
Errors             : 2
Saved to           : C:\Users\You\steam_manuals
```

---

## Notes

- Not every game on Steam has a hosted manual. Most results will be "no manual" — that's normal.
- The default 1500 ms delay between requests helps avoid rate-limiting from the Steam store.
- If you see an error about your game list being empty, double-check that your Steam profile's game details are set to **Public** in your [Privacy Settings](https://steamcommunity.com/my/edit/settings).
