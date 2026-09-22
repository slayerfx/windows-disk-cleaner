# windows-disk-cleaner

**Free up space on your Windows system drive in one double-click, without touching your files.**

*Version française : [README.fr.md](README.fr.md)*

`windows-disk-cleaner` removes only things that rebuild themselves or are no longer used. Start with a dry run to see exactly what it would do: it never deletes your documents, games or downloads.

## Quick start

1. Download the project (**Code → Download ZIP**) and extract it anywhere, for example in `Documents\windows-disk-cleaner`.
   If Windows blocks the files, right-click the ZIP → **Properties** → tick **Unblock** before extracting.
2. Double-click **`Analyze.cmd`**: a dry run that changes nothing and lists what could be freed.
3. Double-click **`Clean.cmd`** and accept the administrator prompt. A summary is shown at the end.

Every run is logged to `windows-disk-cleaner.log` next to the script. Messages are in English or French, following the Windows display language.

## What it cleans

| Step | What | Why it is safe |
|---|---|---|
| NVIDIA shader caches of old drivers | Files in `%LOCALAPPDATA%\NVIDIA\DXCache` (and `LocalLow`) that belong to previous drivers | Every driver update starts a new cache and never reads the old one again, so it can grow by several GB per update. The current driver's cache is kept. |
| Driver setup files | Package kept by the NVIDIA App, `C:\NVIDIA\DisplayDriver`, `C:\AMD` | Leftovers of drivers that are already installed. A downloaded driver that is not installed yet is kept. |
| Old versions of self-updating apps | `app-x.y.z` folders next to an `Update.exe` (Discord, Slack, …) | The newest version and any running one are kept. |
| Browser caches | Chrome, Edge, Brave, Vivaldi, Opera, Firefox | Caches only: history, passwords, cookies, extensions and site data are kept. Skipped while the browser runs. |
| App caches | Discord, Slack, Steam web cache, Epic Games Launcher web cache | Skipped while the app runs. |
| Code editors | VS Code, VS Code Insiders, Cursor: downloaded extensions, internal caches, obsolete extensions | Skipped while the editor runs. |
| Package manager caches | npm, Yarn, pip, NuGet HTTP cache | Rebuilt automatically when needed. |
| Temporary files | `%TEMP%` and `C:\Windows\Temp`, older than 7 days | Files in use are skipped and junctions are never followed. |
| Crash dumps and error reports | Older than 14 days | Only useful to debug a crash. |
| Windows | Windows **Disk Cleanup** (safe categories only), old Windows Update downloads, old CBS logs, Delivery Optimization cache, `DISM /StartComponentCleanup` | Microsoft's own tools. |
| Moves *(optional, off)* | For example big installers from Downloads to another drive | **Moved, never deleted.** |
| Recycle Bin *(optional, off)* | | |

Disk Cleanup categories used: temporary and setup files, Windows Update cleanup, old device driver packages, Delivery Optimization files, DirectX shader cache, thumbnails, error reports, memory dumps, upgrade logs and discarded files, Microsoft Defender temporary files, Feedback Hub logs, old search index files, offline web pages and temporary sync files. A previous Windows installation (`Windows.old`) is removed only when it is older than 30 days.

## What it never touches

Your documents, pictures, videos and downloads (unless you add a move rule, and even then they are only moved), game saves, installed programs and games, browser history, passwords and cookies, the shader cache of the current driver, File History versions, the Windows files used by "Reset this PC", and the Recycle Bin unless you enable it.

Removing old device driver packages means Device Manager can no longer "roll back" a driver to its previous version. Turn off `runDiskCleanup` if you want to keep that option.

## Configuration

Everything works without configuration. To customize, copy `config.example.json` to `config.json` (next to the script, ignored by git) or pass `-Config path\to\file.json`.

| Key | Default | Meaning |
|---|---|---|
| `tempAgeDays` | `7` | Minimum age of temporary files to delete |
| `crashDumpAgeDays` | `14` | Minimum age of crash dumps and error reports to delete |
| `runDiskCleanup` | `true` | Run Windows Disk Cleanup with the safe categories |
| `runDism` | `true` | Run `DISM /StartComponentCleanup` (a few minutes) |
| `emptyRecycleBin` | `false` | Empty the Recycle Bin |
| `steps` | all `true` | Turn a step off: `nvidiaShaderCache`, `driverInstallers`, `oldAppVersions`, `browserCaches`, `appCaches`, `codeEditors`, `packageCaches`, `tempFiles`, `crashDumps`, `windows` |
| `moveRules` | none | Files to move to another drive (see below) |
| `extraCleanup` | none | Extra files to delete (see below) |

**Move rules** move the files of `folder` (default: your Downloads folder, written `{Downloads}`) that match `include`, are bigger than `minSizeMB` and older than `minAgeDays`, to `destination`. A rule is skipped if its destination drive is missing.

```json
"moveRules": [
  { "name": "Big installers", "enabled": true, "folder": "{Downloads}",
    "include": ["*.exe", "*.msi", "*.iso"], "minSizeMB": 200, "minAgeDays": 7,
    "destination": "D:\\Archives\\Installers" }
]
```

**Extra cleanup** deletes files (never folders) matching a path pattern. Wildcards and environment variables are allowed; patterns too close to a drive root are refused.

```json
"extraCleanup": [
  { "name": "Game replay buffer", "path": "C:\\Games\\SomeGame\\tmp\\replay.bin", "minAgeDays": 0 }
]
```

## Command line

```powershell
powershell -ExecutionPolicy Bypass -File .\windows-disk-cleaner.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .\windows-disk-cleaner.ps1 -Config D:\my-config.json -Language en
```

| Parameter | Meaning |
|---|---|
| `-DryRun` | Show what would be done, change nothing |
| `-Config <file>` | Use a JSON configuration file |
| `-Language fr\|en` | Force the language (default: Windows display language) |
| `-NoElevate` | Do not ask for administrator rights (Windows steps are skipped) |
| `-NoPause` | Do not wait for Enter at the end |

## Requirements

Windows 10 or 11 with Windows PowerShell 5.1 (built in). Administrator rights are needed for the Windows steps and the NVIDIA App package. If your account is not an administrator, the user-profile steps apply to the account that approves the prompt.

## Disclaimer

Provided as is, without warranty. Run `Analyze.cmd` first and read what it reports.

## License

[MIT](LICENSE)
