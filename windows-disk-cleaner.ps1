<#
.SYNOPSIS
    Frees space on the Windows system drive without touching your files.
    Libère de la place sur le disque système de Windows sans toucher à tes fichiers.

.DESCRIPTION
    EN: Removes only things that rebuild themselves or are no longer used: shader caches of
        old NVIDIA drivers, setup files of drivers that are already installed, old versions of
        self-updating apps, browser / app / editor / package-manager caches, old temporary
        files, crash dumps and error reports. Runs Windows' own Disk Cleanup (safe categories
        only) and component cleanup. Can move big downloads to another drive (never deletes
        them). -DryRun shows everything without changing anything.
    FR: Supprime uniquement ce qui se reconstruit tout seul ou ne sert plus : caches de shaders
        des anciens pilotes NVIDIA, fichiers d'installation de pilotes déjà installés,
        anciennes versions d'applis, caches de navigateurs, d'applis, d'éditeurs et de
        gestionnaires de paquets, vieux fichiers temporaires, rapports de plantage et
        d'erreurs. Lance le Nettoyage de disque de Windows (catégories sûres uniquement) et le
        nettoyage des composants. Peut déplacer les gros téléchargements vers un autre disque
        (sans jamais les supprimer). -DryRun montre tout sans rien changer.

.PARAMETER DryRun
    Show what would be done, change nothing. / Simulation : montre ce qui serait fait.
.PARAMETER Config
    JSON configuration file (default: config.json next to the script, if present).
    Fichier de configuration JSON (par défaut : config.json à côté du script, s'il existe).
.PARAMETER Language
    fr or en (default: Windows display language). / fr ou en (par défaut : langue de Windows).
.PARAMETER NoElevate
    Do not ask for administrator rights. / Ne pas demander les droits administrateur.
.PARAMETER NoPause
    Do not wait for Enter at the end. / Ne pas attendre Entrée à la fin.

.EXAMPLE
    .\windows-disk-cleaner.ps1 -DryRun
.EXAMPLE
    .\windows-disk-cleaner.ps1 -Config D:\my-config.json -Language en

.LINK
    https://github.com/slayerfx/windows-disk-cleaner
#>
[CmdletBinding()]
param(
    [Alias('Simulation')][switch]$DryRun,
    [string]$Config,
    [ValidateSet('fr', 'en')][string]$Language,
    [Alias('SansElevation')][switch]$NoElevate,
    [Alias('SansPause')][switch]$NoPause
)

$ScriptVersion = '1.0.0'

# ================================================================ Messages
$Messages = @{
    fr = @{
        AdminRefused    = 'Droits administrateur refusés : je continue sans (étapes Windows sautées).'
        ConfigError     = 'Configuration illisible ({0}) : {1}'
        Title           = 'windows-disk-cleaner {0}  -  disque {1}  -  {2}'
        DryRunTag       = '[SIMULATION : rien ne sera supprimé ni déplacé]'
        FreeStart       = 'Espace libre au départ : {0}'
        ConfigUsed      = 'Configuration : {0}'
        NoAdmin         = 'Sans droits administrateur : les parties Windows ne sont ni mesurées ni nettoyées.'
        Nothing         = 'rien à faire'
        Items           = '{0} élément(s)'
        InUse           = '{0} élément(s) en cours d''utilisation laissé(s)'
        WouldMove       = '{0} fichier(s) iraient vers {1}'
        MovedTo         = 'déplacé vers {0}'
        NeedsAdmin      = 'droits administrateur nécessaires'
        Rebuilds        = 'se reconstruit tout seul'
        StepNvidia      = 'Caches de shaders NVIDIA des anciens pilotes'
        NvidiaOld       = 'Caches des anciens pilotes'
        NvidiaCurrent   = 'pilote actuel installé le {0}'
        NvidiaNone      = 'pas de pilote ou de cache NVIDIA'
        StepInstallers  = 'Fichiers d''installation de pilotes déjà installés'
        NvAppPackage    = 'Paquet gardé par la NVIDIA App'
        NvAppPending    = 'pilote {0} téléchargé mais pas encore installé : conservé'
        NvAppInstalled  = 'pilote installé : {0}'
        NvExtracted     = 'Pilotes NVIDIA décompressés ({0})'
        AmdExtracted    = 'Installeurs AMD décompressés ({0})'
        InstallersNone  = 'Fichiers d''installation de pilotes'
        StepApps        = 'Anciennes versions d''applis qui se mettent à jour seules'
        AppOld          = '{0} : anciennes versions'
        AppKeeps        = 'garde {0}'
        AppsNone        = 'Anciennes versions d''applis'
        StepBrowsers    = 'Caches des navigateurs (fermés seulement)'
        BrowserCache    = 'Cache de {0}'
        BrowserOpen     = 'ouvert : ignoré (ferme-le complètement, icône près de l''horloge comprise)'
        BrowserKeeps    = 'historique, mots de passe et cookies conservés'
        BrowsersNone    = 'Navigateurs'
        StepAppCaches   = 'Caches d''applis (fermées seulement)'
        AppCache        = 'Cache de {0}'
        AppOpen         = 'ouvert : ignoré'
        AppCachesNone   = 'Caches d''applis'
        StepEditors     = 'Éditeurs de code (VS Code, Cursor...)'
        EditorOpen      = 'ouvert : ignoré (ferme-le puis relance)'
        EditorVsix      = '{0} : cache des extensions téléchargées'
        EditorWebCache  = '{0} : caches internes'
        EditorOrphans   = '{0} : extensions obsolètes'
        EditorsNone     = 'Éditeurs de code'
        Redownloaded    = 'retéléchargé si besoin'
        StepPackages    = 'Caches de gestionnaires de paquets'
        PackagesNone    = 'Caches de paquets'
        StepTemp        = 'Fichiers temporaires de plus de {0} jours'
        TempUser        = 'Temp de l''utilisateur'
        TempWindows     = 'Temp de Windows'
        StepDumps       = 'Rapports de plantage et d''erreurs de plus de {0} jours'
        DumpsApps       = 'Rapports de plantage des applis'
        WerUser         = 'Rapports d''erreurs Windows'
        DumpsWindows    = 'Rapports de plantage de Windows'
        StepMove        = 'Déplacements (jamais de suppression)'
        MoveNoDest      = 'destination {0} indisponible'
        MoveRule        = 'Règle de déplacement'
        StepExtra       = 'Nettoyages personnalisés'
        ExtraRefused    = 'chemin trop large, refusé'
        StepWindows     = 'Windows'
        WinUpdateOld    = 'Anciens téléchargements de Windows Update (plus de 10 jours)'
        CbsLogs         = 'Anciens journaux CBS (plus de 30 jours)'
        WinLabel        = 'Nettoyage de disque Windows, optimisation de distribution, anciennes mises à jour'
        WinDryRun       = 'non estimable en simulation'
        CleanmgrRunning = 'Nettoyage de disque de Windows : quelques minutes, une fenêtre de progression peut s''ouvrir...'
        DismRunning     = 'Anciennes mises à jour (DISM) : quelques minutes, ne ferme pas la fenêtre...'
        StepRecycle     = 'Corbeille'
        RecycleLabel    = 'Corbeille vidée'
        SummaryDry      = 'SIMULATION : environ {0} pourraient être libérés sur {1} (sans compter l''étape Windows).'
        SummaryDone     = 'Espace libre : {0}  ->  {1}   (+{2})'
        Watch           = 'À surveiller (le script n''y touche pas) :'
        WatchNvidia     = 'Cache de shaders NVIDIA du pilote actuel'
        WatchDownloads  = 'Téléchargements'
        WatchVhdx       = 'Disques virtuels Docker / WSL'
        WatchHiber      = 'hiberfil.sys (veille prolongée ; « powercfg /h off » en admin le supprime)'
        WatchWinOld     = 'Windows.old présent (Paramètres > Stockage > Fichiers temporaires)'
        WatchNone       = 'rien de notable'
        PressEnter      = 'Appuie sur Entrée pour fermer'
        LogFreeSpace    = 'Libre avant : {0} / après : {1}'
        SizeGB          = 'Go'
        SizeMB          = 'Mo'
    }
    en = @{
        AdminRefused    = 'Administrator rights declined: continuing without them (Windows steps skipped).'
        ConfigError     = 'Cannot read the configuration ({0}): {1}'
        Title           = 'windows-disk-cleaner {0}  -  drive {1}  -  {2}'
        DryRunTag       = '[DRY RUN: nothing will be deleted or moved]'
        FreeStart       = 'Free space at start: {0}'
        ConfigUsed      = 'Configuration: {0}'
        NoAdmin         = 'Without administrator rights: Windows parts are neither measured nor cleaned.'
        Nothing         = 'nothing to do'
        Items           = '{0} item(s)'
        InUse           = '{0} item(s) in use, left in place'
        WouldMove       = '{0} file(s) would go to {1}'
        MovedTo         = 'moved to {0}'
        NeedsAdmin      = 'administrator rights required'
        Rebuilds        = 'rebuilt automatically'
        StepNvidia      = 'NVIDIA shader caches of old drivers'
        NvidiaOld       = 'Old driver caches'
        NvidiaCurrent   = 'current driver installed on {0}'
        NvidiaNone      = 'no NVIDIA driver or cache'
        StepInstallers  = 'Setup files of drivers already installed'
        NvAppPackage    = 'Package kept by the NVIDIA App'
        NvAppPending    = 'driver {0} downloaded but not installed yet: kept'
        NvAppInstalled  = 'installed driver: {0}'
        NvExtracted     = 'Extracted NVIDIA drivers ({0})'
        AmdExtracted    = 'Extracted AMD installers ({0})'
        InstallersNone  = 'Driver setup files'
        StepApps        = 'Old versions of self-updating apps'
        AppOld          = '{0}: old versions'
        AppKeeps        = 'keeps {0}'
        AppsNone        = 'Old app versions'
        StepBrowsers    = 'Browser caches (closed browsers only)'
        BrowserCache    = '{0} cache'
        BrowserOpen     = 'running: skipped (close it completely, including its tray icon)'
        BrowserKeeps    = 'history, passwords and cookies kept'
        BrowsersNone    = 'Browsers'
        StepAppCaches   = 'App caches (closed apps only)'
        AppCache        = '{0} cache'
        AppOpen         = 'running: skipped'
        AppCachesNone   = 'App caches'
        StepEditors     = 'Code editors (VS Code, Cursor...)'
        EditorOpen      = 'running: skipped (close it and run again)'
        EditorVsix      = '{0}: downloaded extension cache'
        EditorWebCache  = '{0}: internal caches'
        EditorOrphans   = '{0}: obsolete extensions'
        EditorsNone     = 'Code editors'
        Redownloaded    = 'downloaded again if needed'
        StepPackages    = 'Package manager caches'
        PackagesNone    = 'Package caches'
        StepTemp        = 'Temporary files older than {0} days'
        TempUser        = 'User temp'
        TempWindows     = 'Windows temp'
        StepDumps       = 'Crash dumps and error reports older than {0} days'
        DumpsApps       = 'App crash dumps'
        WerUser         = 'Windows error reports'
        DumpsWindows    = 'Windows crash dumps'
        StepMove        = 'Moves (never deletes)'
        MoveNoDest      = 'destination {0} unavailable'
        MoveRule        = 'Move rule'
        StepExtra       = 'Custom cleanups'
        ExtraRefused    = 'path too broad, refused'
        StepWindows     = 'Windows'
        WinUpdateOld    = 'Old Windows Update downloads (older than 10 days)'
        CbsLogs         = 'Old CBS logs (older than 30 days)'
        WinLabel        = 'Windows Disk Cleanup, Delivery Optimization, old updates'
        WinDryRun       = 'cannot be estimated in a dry run'
        CleanmgrRunning = 'Windows Disk Cleanup: a few minutes, a progress window may open...'
        DismRunning     = 'Old updates (DISM): a few minutes, do not close the window...'
        StepRecycle     = 'Recycle Bin'
        RecycleLabel    = 'Recycle Bin emptied'
        SummaryDry      = 'DRY RUN: about {0} could be freed on {1} (Windows step not included).'
        SummaryDone     = 'Free space: {0}  ->  {1}   (+{2})'
        Watch           = 'Worth a look (not touched by the script):'
        WatchNvidia     = 'NVIDIA shader cache of the current driver'
        WatchDownloads  = 'Downloads'
        WatchVhdx       = 'Docker / WSL virtual disks'
        WatchHiber      = 'hiberfil.sys (hibernation; "powercfg /h off" as admin removes it)'
        WatchWinOld     = 'Windows.old present (Settings > Storage > Temporary files)'
        WatchNone       = 'nothing notable'
        PressEnter      = 'Press Enter to close'
        LogFreeSpace    = 'Free before: {0} / after: {1}'
        SizeGB          = 'GB'
        SizeMB          = 'MB'
    }
}

if (-not $Language) {
    $Language = 'en'
    if ((Get-UICulture).TwoLetterISOLanguageName -eq 'fr') { $Language = 'fr' }
}
$Msg = $Messages[$Language]
function L([string]$Key) { return $Msg[$Key] }

# =============================================================== Elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $NoElevate) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath), '-Language', $Language)
    if ($DryRun) { $argList += '-DryRun' }
    if ($NoPause) { $argList += '-NoPause' }
    if ($Config) {
        $fullConfig = $Config
        try { $fullConfig = (Resolve-Path -LiteralPath $Config -ErrorAction Stop).Path } catch { }
        $argList += @('-Config', ('"{0}"' -f $fullConfig))
    }
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList -ErrorAction Stop
        exit
    } catch {
        Write-Host (L 'AdminRefused') -ForegroundColor Yellow
    }
}

# =========================================================== Configuration
if (-not $Config) {
    $defaultConfig = Join-Path $PSScriptRoot 'config.json'
    if (Test-Path -LiteralPath $defaultConfig) { $Config = $defaultConfig }
}
$cfg = $null
if ($Config) {
    try {
        $cfg = Get-Content -Raw -LiteralPath $Config -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host ((L 'ConfigError') -f $Config, $_.Exception.Message) -ForegroundColor Red
        if (-not $NoPause) { Read-Host (L 'PressEnter') | Out-Null }
        exit 1
    }
}

function Get-Option($Object, [string]$Name, $Default) {
    if ($null -ne $Object) {
        $prop = $Object.PSObject.Properties[$Name]
        if ($prop -and $null -ne $prop.Value) { return $prop.Value }
    }
    return $Default
}

$tempAgeDays      = [int](Get-Option $cfg 'tempAgeDays' 7)
$crashDumpAgeDays = [int](Get-Option $cfg 'crashDumpAgeDays' 14)
$runDiskCleanup   = [bool](Get-Option $cfg 'runDiskCleanup' $true)
$runDism          = [bool](Get-Option $cfg 'runDism' $true)
$emptyRecycleBin  = [bool](Get-Option $cfg 'emptyRecycleBin' $false)
$stepsConfig      = Get-Option $cfg 'steps' $null
$moveRules        = @(Get-Option $cfg 'moveRules' @())
$extraCleanup     = @(Get-Option $cfg 'extraCleanup' @())
function Test-Step([string]$Name) { return [bool](Get-Option $stepsConfig $Name $true) }

$ErrorActionPreference = 'SilentlyContinue'
$sysDrive = $env:SystemDrive
$results = New-Object System.Collections.ArrayList
$script:stepNumber = 0

$downloads = $null
try { $downloads = (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path } catch { }
if (-not $downloads) { $downloads = Join-Path $env:USERPROFILE 'Downloads' }

# ================================================================= Helpers
function Format-Size([double]$Bytes) {
    if ($Bytes -ge 1GB) { return ('{0:N2} {1}' -f ($Bytes / 1GB), (L 'SizeGB')) }
    return ('{0:N0} {1}' -f ($Bytes / 1MB), (L 'SizeMB'))
}

function Get-FreeSpace {
    return [double](Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $sysDrive)).FreeSpace
}

# Files under a folder, never following junctions or symbolic links
function Get-SafeFiles([string]$Root) {
    if (-not $Root -or -not (Test-Path -LiteralPath $Root)) { return }
    $stack = New-Object System.Collections.Stack
    $stack.Push($Root)
    while ($stack.Count -gt 0) {
        $folder = $stack.Pop()
        foreach ($entry in (Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue)) {
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if ($entry.PSIsContainer) { $stack.Push($entry.FullName) } else { $entry }
        }
    }
}

function Get-Size($Items) {
    $total = [double]0
    foreach ($item in @($Items)) {
        if (-not $item) { continue }
        if ($item.PSIsContainer) { $total += [double]((Get-SafeFiles $item.FullName | Measure-Object -Property Length -Sum).Sum) }
        else { $total += [double]$item.Length }
    }
    return $total
}

# Existing folders among a list of paths, as items
function Get-ExistingFolders($Paths) {
    foreach ($path in @($Paths)) {
        if ($path -and (Test-Path -LiteralPath $path)) { Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    }
}

function Test-Running([string[]]$Names) {
    return [bool](Get-Process -Name $Names -ErrorAction SilentlyContinue)
}

function Add-Result([string]$Label, [double]$Bytes, [string]$Detail) {
    [void]$results.Add([pscustomobject]@{ Label = $Label; Bytes = $Bytes; Detail = $Detail })
    $color = 'DarkGray'
    if ($Bytes -gt 0) { $color = 'Green' }
    $line = '   {0,9}  {1}' -f (Format-Size $Bytes), $Label
    if ($Detail) { $line += "  ($Detail)" }
    Write-Host $line -ForegroundColor $color
}

function Remove-Items([string]$Label, $Items, [string]$Detail) {
    $Items = @($Items | Where-Object { $_ })
    if ($Items.Count -eq 0) { Add-Result $Label 0 (L 'Nothing'); return }
    $before = Get-Size $Items
    if ($before -le 0) {
        # Only empty folders: remove them quietly, nothing worth reporting
        if (-not $DryRun) { foreach ($item in $Items) { if ($item.PSIsContainer) { cmd.exe /c ('rd /s /q "{0}"' -f $item.FullName) 2>$null | Out-Null } } }
        Add-Result $Label 0 (L 'Nothing')
        return
    }
    if ($DryRun) {
        $info = (L 'Items') -f $Items.Count
        if ($Detail) { $info = "$info, $Detail" }
        Add-Result $Label $before $info
        return
    }
    foreach ($item in $Items) {
        # rd never follows junctions: nothing outside the target folder can be deleted
        if ($item.PSIsContainer) { cmd.exe /c ('rd /s /q "{0}"' -f $item.FullName) 2>$null | Out-Null }
        else { Remove-Item -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue }
    }
    $left = @($Items | Where-Object { Test-Path -LiteralPath $_.FullName })
    $info = $Detail
    if ($left.Count -gt 0) {
        $note = (L 'InUse') -f $left.Count
        if ($info) { $info = "$info, $note" } else { $info = $note }
    }
    Add-Result $Label ($before - (Get-Size $left)) $info
}

function Move-Items([string]$Label, $Items, [string]$Destination) {
    $Items = @($Items | Where-Object { $_ })
    if ($Items.Count -eq 0) { Add-Result $Label 0 (L 'Nothing'); return }
    if ($DryRun) { Add-Result $Label (Get-Size $Items) ((L 'WouldMove') -f $Items.Count, $Destination); return }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $moved = [double]0
    foreach ($item in $Items) {
        $target = Join-Path $Destination $item.Name
        if (Test-Path -LiteralPath $target) { $target = Join-Path $Destination ('{0}_{1:yyyyMMdd-HHmmss}{2}' -f $item.BaseName, (Get-Date), $item.Extension) }
        Move-Item -LiteralPath $item.FullName -Destination $target -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $item.FullName)) { $moved += $item.Length }
    }
    Add-Result $Label $moved ((L 'MovedTo') -f $Destination)
}

function Write-Step([string]$Title) {
    $script:stepNumber++
    Write-Host ''
    Write-Host ('{0}. {1}' -f $script:stepNumber, $Title) -ForegroundColor White
}

function Expand-PathValue([string]$Value) {
    if (-not $Value) { return $Value }
    return [Environment]::ExpandEnvironmentVariables($Value.Replace('{Downloads}', $downloads))
}

# Windows' own Disk Cleanup, safe categories only. Never: Downloads folder, File History
# versions, Windows ESD files (needed by "Reset this PC"), language packs. Recycle Bin only if
# enabled in the config, previous Windows installation only when older than 30 days.
function Invoke-DiskCleanup {
    $id = 4242
    $flag = 'StateFlags{0:D4}' -f $id
    $root = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    $categories = @('Active Setup Temp Folders', 'BranchCache', 'D3D Shader Cache', 'Delivery Optimization Files',
        'Device Driver Packages', 'Diagnostic Data Viewer database files', 'Downloaded Program Files',
        'Internet Cache Files', 'Old ChkDsk Files', 'RetailDemo Offline Content', 'Setup Log Files',
        'System error memory dump files', 'System error minidump files', 'Temporary Files',
        'Temporary Setup Files', 'Thumbnail Cache', 'Update Cleanup', 'Upgrade Discarded Files',
        'Windows Defender', 'Windows Error Reporting Files', 'Windows Upgrade Log Files', 'Windows Reset Log Files',
        'Feedback Hub Archive log files', 'Content Indexer Cleaner', 'Offline Pages Files', 'Temporary Sync Files')
    if ($emptyRecycleBin) { $categories += 'Recycle Bin' }
    $windowsOld = Get-Item -LiteralPath (Join-Path $sysDrive '\Windows.old') -Force -ErrorAction SilentlyContinue
    if ($windowsOld -and $windowsOld.CreationTime -lt (Get-Date).AddDays(-30)) { $categories += 'Previous Installations' }
    $flagged = New-Object System.Collections.ArrayList
    foreach ($category in $categories) {
        $key = Join-Path $root $category
        if (Test-Path -LiteralPath $key) {
            New-ItemProperty -LiteralPath $key -Name $flag -Value 2 -PropertyType DWord -Force | Out-Null
            [void]$flagged.Add($key)
        }
    }
    if ($flagged.Count -eq 0) { return }
    Write-Host ('   ' + (L 'CleanmgrRunning')) -ForegroundColor DarkGray
    Start-Process -FilePath (Join-Path $env:windir 'System32\cleanmgr.exe') -ArgumentList ('/sagerun:{0}' -f $id) -Wait
    Get-Process -Name 'cleanmgr' -ErrorAction SilentlyContinue | Wait-Process -Timeout 1800
    foreach ($key in $flagged) { Remove-ItemProperty -LiteralPath $key -Name $flag -ErrorAction SilentlyContinue }
}

# =================================================================== Start
$freeBefore = Get-FreeSpace
Write-Host ''
Write-Host ((L 'Title') -f $ScriptVersion, $sysDrive, (Get-Date).ToString('g')) -ForegroundColor Cyan
if ($DryRun) { Write-Host (L 'DryRunTag') -ForegroundColor Cyan }
Write-Host ((L 'FreeStart') -f (Format-Size $freeBefore)) -ForegroundColor Cyan
if ($Config) { Write-Host ((L 'ConfigUsed') -f $Config) -ForegroundColor DarkGray }
if (-not $isAdmin) { Write-Host (L 'NoAdmin') -ForegroundColor Yellow }

# ------------------------------------------ NVIDIA shader caches of old drivers
if (Test-Step 'nvidiaShaderCache') {
    Write-Step (L 'StepNvidia')
    $shaderDirs = @(@((Join-Path $env:LOCALAPPDATA 'NVIDIA\DXCache'), (Join-Path $env:USERPROFILE 'AppData\LocalLow\NVIDIA\DXCache')) | Where-Object { Test-Path -LiteralPath $_ })
    $driverFolder = Get-ChildItem -LiteralPath (Join-Path $env:windir 'System32\DriverStore\FileRepository') -Directory -Filter 'nv_dispi.inf_amd64_*' -ErrorAction SilentlyContinue | Sort-Object CreationTime -Descending | Select-Object -First 1
    if ($driverFolder -and $shaderDirs.Count -gt 0) {
        # Cache files start with a 4-character tag that changes with every driver install, and
        # a new driver never reads the files of the previous one. A tag group created before the
        # current driver and not written during the 48 hours after its install is an old driver's.
        $installTime = $driverFolder.CreationTime
        $limit = $installTime.AddHours(48)
        if (((Get-Date) - $installTime).TotalHours -lt 48) { $limit = $installTime }
        $stale = New-Object System.Collections.ArrayList
        foreach ($dir in $shaderDirs) {
            $groups = Get-ChildItem -LiteralPath $dir -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.BaseName.Length -ge 8 } | Group-Object { $_.Name.Substring(0, 4) }
            foreach ($group in $groups) {
                $born = ($group.Group | Sort-Object CreationTime | Select-Object -First 1).CreationTime
                $last = ($group.Group | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
                if ($born -lt $installTime.AddHours(-1) -and $last -lt $limit -and $last -lt (Get-Date).AddHours(-24)) { [void]$stale.AddRange(@($group.Group)) }
            }
        }
        Remove-Items (L 'NvidiaOld') $stale ((L 'NvidiaCurrent') -f $installTime.ToString('d'))
    } else { Add-Result (L 'NvidiaOld') 0 (L 'NvidiaNone') }
}

# ------------------------------------- Setup files of drivers already installed
if (Test-Step 'driverInstallers') {
    Write-Step (L 'StepInstallers')
    $any = $false
    $nvAppPackage = Join-Path $env:ProgramData 'NVIDIA Corporation\NVIDIA App\UpdateFramework\ota-artifacts\grd'
    $content = @(Get-ChildItem -LiteralPath $nvAppPackage -Force -ErrorAction SilentlyContinue)
    if ($content.Count -gt 0) {
        $any = $true
        $installed = $null
        $driverVersion = (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' } | Select-Object -First 1).DriverVersion
        if ($driverVersion) {
            # 32.0.16.1692 -> 616.92
            $digits = $driverVersion -replace '\D', ''
            if ($digits.Length -ge 5) { $last5 = $digits.Substring($digits.Length - 5); $installed = $last5.Substring(0, 3) + '.' + $last5.Substring(3) }
        }
        $packageExe = Get-ChildItem -LiteralPath $nvAppPackage -Recurse -File -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        $packageVersion = $null
        if ($packageExe -and $packageExe.Name -match '^(\d{3}\.\d{2})') { $packageVersion = $Matches[1] }
        if ($packageVersion -and $installed -and ([version]$packageVersion -gt [version]$installed)) { Add-Result (L 'NvAppPackage') 0 ((L 'NvAppPending') -f $packageVersion) }
        elseif (-not $isAdmin -and -not $DryRun) { Add-Result (L 'NvAppPackage') 0 (L 'NeedsAdmin') }
        else { Remove-Items (L 'NvAppPackage') $content ((L 'NvAppInstalled') -f $installed) }
    }
    foreach ($extract in @(@{ Path = (Join-Path $sysDrive '\NVIDIA\DisplayDriver'); Label = 'NvExtracted' }, @{ Path = (Join-Path $sysDrive '\AMD'); Label = 'AmdExtracted' })) {
        $items = @(Get-ChildItem -LiteralPath $extract.Path -Force -ErrorAction SilentlyContinue)
        if ($items.Count -gt 0) { $any = $true; Remove-Items ((L $extract.Label) -f $extract.Path) $items '' }
    }
    if (-not $any) { Add-Result (L 'InstallersNone') 0 (L 'Nothing') }
}

# ------------------------- Old versions of self-updating apps (Squirrel installers)
if (Test-Step 'oldAppVersions') {
    Write-Step (L 'StepApps')
    $any = $false
    foreach ($appFolder in (Get-ChildItem -LiteralPath $env:LOCALAPPDATA -Directory -Force -ErrorAction SilentlyContinue)) {
        if (-not (Test-Path -LiteralPath (Join-Path $appFolder.FullName 'Update.exe'))) { continue }
        $versions = @(Get-ChildItem -LiteralPath $appFolder.FullName -Directory -Filter 'app-*' -ErrorAction SilentlyContinue | ForEach-Object {
            $parsed = $null
            if ([version]::TryParse($_.Name.Substring(4), [ref]$parsed)) { [pscustomobject]@{ Folder = $_; Version = $parsed } }
        } | Sort-Object Version -Descending)
        if ($versions.Count -lt 2) { continue }
        $prefix = $appFolder.FullName + '\'
        $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { ($_.Path.Substring($prefix.Length) -split '\\')[0] })
        $old = @($versions | Select-Object -Skip 1 | Where-Object { $running -notcontains $_.Folder.Name } | ForEach-Object { $_.Folder })
        if ($old.Count -gt 0) {
            $any = $true
            Remove-Items ((L 'AppOld') -f $appFolder.Name) $old ((L 'AppKeeps') -f $versions[0].Folder.Name)
        }
    }
    if (-not $any) { Add-Result (L 'AppsNone') 0 (L 'Nothing') }
}

# ----------------------------------------------- Browser caches (closed only)
if (Test-Step 'browserCaches') {
    Write-Step (L 'StepBrowsers')
    $any = $false
    $chromium = @(
        @{ Name = 'Chrome';  Process = 'chrome';  Root = (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data') },
        @{ Name = 'Edge';    Process = 'msedge';  Root = (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data') },
        @{ Name = 'Brave';   Process = 'brave';   Root = (Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data') },
        @{ Name = 'Vivaldi'; Process = 'vivaldi'; Root = (Join-Path $env:LOCALAPPDATA 'Vivaldi\User Data') }
    )
    foreach ($browser in $chromium) {
        if (-not (Test-Path -LiteralPath $browser.Root)) { continue }
        $any = $true
        if (Test-Running $browser.Process) { Add-Result ((L 'BrowserCache') -f $browser.Name) 0 (L 'BrowserOpen'); continue }
        # Only caches: history, passwords, cookies, extensions and site storage stay untouched
        $targets = @(Get-ExistingFolders (@('ShaderCache', 'GrShaderCache', 'GraphiteDawnCache') | ForEach-Object { Join-Path $browser.Root $_ }))
        foreach ($browserProfile in (Get-ChildItem -LiteralPath $browser.Root -Directory -Force -ErrorAction SilentlyContinue | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'Preferences') })) {
            $targets += @(Get-ExistingFolders (@('Cache', 'Code Cache', 'GPUCache', 'DawnCache', 'DawnGraphiteCache', 'DawnWebGPUCache') | ForEach-Object { Join-Path $browserProfile.FullName $_ }))
        }
        Remove-Items ((L 'BrowserCache') -f $browser.Name) $targets (L 'BrowserKeeps')
    }
    foreach ($opera in @(@{ Name = 'Opera'; Cache = (Join-Path $env:LOCALAPPDATA 'Opera Software\Opera Stable\Cache') }, @{ Name = 'Opera GX'; Cache = (Join-Path $env:LOCALAPPDATA 'Opera Software\Opera GX Stable\Cache') })) {
        if (-not (Test-Path -LiteralPath $opera.Cache)) { continue }
        $any = $true
        if (Test-Running 'opera') { Add-Result ((L 'BrowserCache') -f $opera.Name) 0 (L 'BrowserOpen'); continue }
        Remove-Items ((L 'BrowserCache') -f $opera.Name) (Get-ExistingFolders $opera.Cache) (L 'BrowserKeeps')
    }
    $firefoxProfiles = Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'
    if (Test-Path -LiteralPath $firefoxProfiles) {
        $any = $true
        if (Test-Running 'firefox') { Add-Result ((L 'BrowserCache') -f 'Firefox') 0 (L 'BrowserOpen') }
        else { Remove-Items ((L 'BrowserCache') -f 'Firefox') (Get-ChildItem -Path (Join-Path $firefoxProfiles '*\cache2') -Directory -Force -ErrorAction SilentlyContinue) (L 'BrowserKeeps') }
    }
    if (-not $any) { Add-Result (L 'BrowsersNone') 0 (L 'Nothing') }
}

# --------------------------------------------------- App caches (closed only)
if (Test-Step 'appCaches') {
    Write-Step (L 'StepAppCaches')
    $any = $false
    $apps = @(
        @{ Name = 'Discord';             Process = 'Discord';           Paths = @('discord\Cache', 'discord\Code Cache', 'discord\GPUCache' | ForEach-Object { Join-Path $env:APPDATA $_ }) },
        @{ Name = 'Slack';               Process = 'slack';             Paths = @('Slack\Cache', 'Slack\Code Cache', 'Slack\GPUCache' | ForEach-Object { Join-Path $env:APPDATA $_ }) },
        @{ Name = 'Steam (web)';         Process = 'steam';             Paths = @(Join-Path $env:LOCALAPPDATA 'Steam\htmlcache') },
        @{ Name = 'Epic Games Launcher'; Process = 'EpicGamesLauncher'; Paths = @(Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'EpicGamesLauncher\Saved\webcache*') -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
    )
    foreach ($app in $apps) {
        $folders = @(Get-ExistingFolders $app.Paths)
        if ($folders.Count -eq 0) { continue }
        $any = $true
        if (Test-Running $app.Process) { Add-Result ((L 'AppCache') -f $app.Name) 0 (L 'AppOpen'); continue }
        Remove-Items ((L 'AppCache') -f $app.Name) $folders (L 'Rebuilds')
    }
    if (-not $any) { Add-Result (L 'AppCachesNone') 0 (L 'Nothing') }
}

# ------------------------------------------------------------- Code editors
if (Test-Step 'codeEditors') {
    Write-Step (L 'StepEditors')
    $any = $false
    $editors = @(
        @{ Name = 'VS Code';          Process = 'Code';            Data = (Join-Path $env:APPDATA 'Code');            Extensions = (Join-Path $env:USERPROFILE '.vscode\extensions') },
        @{ Name = 'VS Code Insiders'; Process = 'Code - Insiders'; Data = (Join-Path $env:APPDATA 'Code - Insiders'); Extensions = (Join-Path $env:USERPROFILE '.vscode-insiders\extensions') },
        @{ Name = 'Cursor';           Process = 'Cursor';          Data = (Join-Path $env:APPDATA 'Cursor');          Extensions = (Join-Path $env:USERPROFILE '.cursor\extensions') }
    )
    foreach ($editor in $editors) {
        if (-not (Test-Path -LiteralPath $editor.Data) -and -not (Test-Path -LiteralPath $editor.Extensions)) { continue }
        $any = $true
        if (Test-Running $editor.Process) { Add-Result $editor.Name 0 (L 'EditorOpen'); continue }
        Remove-Items ((L 'EditorVsix') -f $editor.Name) (Get-ChildItem -LiteralPath (Join-Path $editor.Data 'CachedExtensionVSIXs') -Force -ErrorAction SilentlyContinue) (L 'Redownloaded')
        Remove-Items ((L 'EditorWebCache') -f $editor.Name) (Get-ExistingFolders (@('Cache', 'CachedData', 'Code Cache', 'GPUCache') | ForEach-Object { Join-Path $editor.Data $_ })) (L 'Rebuilds')
        $manifest = Join-Path $editor.Extensions 'extensions.json'
        if (Test-Path -LiteralPath $manifest) {
            $list = Get-Content -Raw -LiteralPath $manifest -Encoding UTF8 | ConvertFrom-Json
            $installedExt = @($list | ForEach-Object { if ($_.relativeLocation) { $_.relativeLocation } elseif ($_.location.path) { Split-Path -Leaf $_.location.path } })
            $obsolete = @()
            $obsoleteFile = Join-Path $editor.Extensions '.obsolete'
            if (Test-Path -LiteralPath $obsoleteFile) { $obsolete = @((Get-Content -Raw -LiteralPath $obsoleteFile | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $_.Name }) }
            if ($installedExt.Count -gt 0) {
                # Only folders the editor itself marked obsolete, or its unfinished temporary folders
                $orphans = @(Get-ChildItem -LiteralPath $editor.Extensions -Directory -Force -ErrorAction SilentlyContinue | Where-Object { ($installedExt -notcontains $_.Name) -and ($_.Name.StartsWith('.') -or ($obsolete -contains $_.Name)) })
                Remove-Items ((L 'EditorOrphans') -f $editor.Name) $orphans ''
            }
        }
    }
    if (-not $any) { Add-Result (L 'EditorsNone') 0 (L 'Nothing') }
}

# -------------------------------------------------- Package manager caches
if (Test-Step 'packageCaches') {
    Write-Step (L 'StepPackages')
    $any = $false
    $caches = @(
        @{ Name = 'npm';          Items = @(Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'npm-cache') -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -in '_cacache', '_npx' }) },
        @{ Name = 'Yarn';         Items = @(Get-ExistingFolders (Join-Path $env:LOCALAPPDATA 'Yarn\Cache')) },
        @{ Name = 'pip';          Items = @(Get-ExistingFolders (Join-Path $env:LOCALAPPDATA 'pip\Cache')) },
        @{ Name = 'NuGet (HTTP)'; Items = @(Get-ExistingFolders (Join-Path $env:LOCALAPPDATA 'NuGet\v3-cache')) }
    )
    foreach ($cache in $caches) { if ($cache.Items.Count -gt 0) { $any = $true; Remove-Items $cache.Name $cache.Items (L 'Rebuilds') } }
    if (-not $any) { Add-Result (L 'PackagesNone') 0 (L 'Nothing') }
}

# ------------------------------------------------------- Temporary files
if (Test-Step 'tempFiles') {
    Write-Step ((L 'StepTemp') -f $tempAgeDays)
    $tempLimit = (Get-Date).AddDays(-$tempAgeDays)
    Remove-Items (L 'TempUser') (Get-SafeFiles $env:TEMP | Where-Object { $_.LastWriteTime -lt $tempLimit }) ''
    if ($isAdmin) { Remove-Items (L 'TempWindows') (Get-SafeFiles (Join-Path $env:windir 'Temp') | Where-Object { $_.LastWriteTime -lt $tempLimit }) '' }
    else { Add-Result (L 'TempWindows') 0 (L 'NeedsAdmin') }
}

# ------------------------------------------- Crash dumps and error reports
if (Test-Step 'crashDumps') {
    Write-Step ((L 'StepDumps') -f $crashDumpAgeDays)
    $dumpLimit = (Get-Date).AddDays(-$crashDumpAgeDays)
    Remove-Items (L 'DumpsApps') (Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'CrashDumps') -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $dumpLimit }) ''
    $reports = @('ReportArchive', 'ReportQueue') | ForEach-Object { Get-SafeFiles (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\WER\$_") }
    Remove-Items (L 'WerUser') ($reports | Where-Object { $_.LastWriteTime -lt $dumpLimit }) ''
    if ($isAdmin) {
        $dumps = @(Get-ChildItem -LiteralPath (Join-Path $env:windir 'LiveKernelReports') -Recurse -File -Filter '*.dmp' -Force -ErrorAction SilentlyContinue)
        $dumps += @(Get-ChildItem -LiteralPath (Join-Path $env:windir 'Minidump') -File -Force -ErrorAction SilentlyContinue)
        $dumps += @(Get-Item -LiteralPath (Join-Path $env:windir 'MEMORY.DMP') -Force -ErrorAction SilentlyContinue)
        Remove-Items (L 'DumpsWindows') ($dumps | Where-Object { $_ -and $_.LastWriteTime -lt $dumpLimit }) ''
    } else { Add-Result (L 'DumpsWindows') 0 (L 'NeedsAdmin') }
}

# ------------------------------------------ Moves from the config (never deletes)
$activeRules = @($moveRules | Where-Object { $_ -and [bool](Get-Option $_ 'enabled' $true) })
if ($activeRules.Count -gt 0) {
    Write-Step (L 'StepMove')
    foreach ($rule in $activeRules) {
        $label = [string](Get-Option $rule 'name' (L 'MoveRule'))
        $folder = Expand-PathValue ([string](Get-Option $rule 'folder' '{Downloads}'))
        $destination = Expand-PathValue ([string](Get-Option $rule 'destination' ''))
        $patterns = @(Get-Option $rule 'include' @('*'))
        $minBytes = [double](Get-Option $rule 'minSizeMB' 0) * 1MB
        $maxDate = (Get-Date).AddDays(-[double](Get-Option $rule 'minAgeDays' 0))
        $qualifier = $null
        if ($destination) { $qualifier = Split-Path -Qualifier $destination }
        if (-not $qualifier -or -not (Test-Path -LiteralPath ($qualifier + '\'))) { Add-Result $label 0 ((L 'MoveNoDest') -f $destination); continue }
        $files = @(Get-ChildItem -LiteralPath $folder -File -Force -ErrorAction SilentlyContinue | Where-Object {
            $file = $_
            ($file.Length -ge $minBytes) -and ($file.LastWriteTime -lt $maxDate) -and (@($patterns | Where-Object { $file.Name -like $_ }).Count -gt 0)
        })
        Move-Items $label $files $destination
    }
}

# -------------------------------------- Extra cleanup from the config (files only)
$activeExtra = @($extraCleanup | Where-Object { $_ -and [bool](Get-Option $_ 'enabled' $true) -and (Get-Option $_ 'path' $null) })
if ($activeExtra.Count -gt 0) {
    Write-Step (L 'StepExtra')
    foreach ($entry in $activeExtra) {
        $pattern = Expand-PathValue ([string](Get-Option $entry 'path' ''))
        $label = [string](Get-Option $entry 'name' $pattern)
        # Refuse anything too close to a drive root, e.g. C:\* or C:\Windows\*
        if (($pattern.Split('\') | Where-Object { $_ }).Count -lt 4) { Add-Result $label 0 (L 'ExtraRefused'); continue }
        $maxDate = (Get-Date).AddDays(-[double](Get-Option $entry 'minAgeDays' 0))
        $files = @(Get-ChildItem -Path $pattern -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $maxDate })
        Remove-Items $label $files ''
    }
}

# ---------------------------------------------------------------- Windows
if (Test-Step 'windows') {
    Write-Step (L 'StepWindows')
    if (-not $isAdmin) { Add-Result (L 'WinLabel') 0 (L 'NeedsAdmin') }
    else {
        Remove-Items (L 'WinUpdateOld') (Get-SafeFiles (Join-Path $env:windir 'SoftwareDistribution\Download') | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-10) }) ''
        Remove-Items (L 'CbsLogs') (Get-ChildItem -LiteralPath (Join-Path $env:windir 'Logs\CBS') -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'CBS.log' -and $_.LastWriteTime -lt (Get-Date).AddDays(-30) }) ''
        if ($DryRun) { Add-Result (L 'WinLabel') 0 (L 'WinDryRun') }
        else {
            $before = Get-FreeSpace
            if ($runDiskCleanup) { Invoke-DiskCleanup }
            if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) { Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue }
            if ($runDism) {
                Write-Host ('   ' + (L 'DismRunning')) -ForegroundColor DarkGray
                & (Join-Path $env:windir 'System32\Dism.exe') /Online /Cleanup-Image /StartComponentCleanup
            }
            Add-Result (L 'WinLabel') ([math]::Max(0, (Get-FreeSpace) - $before)) ''
        }
    }
}

# ------------------------------------------------ Recycle Bin (off by default)
if ($emptyRecycleBin) {
    Write-Step (L 'StepRecycle')
    $binSize = [double]0
    (New-Object -ComObject Shell.Application).Namespace(10).Items() | ForEach-Object { $binSize += [double]$_.ExtendedProperty('Size') }
    if (-not $DryRun) { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }
    Add-Result (L 'RecycleLabel') $binSize ''
}

# ================================================================= Summary
$freeAfter = Get-FreeSpace
$total = [double](($results | Measure-Object -Property Bytes -Sum).Sum)
Write-Host ''
if ($DryRun) { Write-Host ((L 'SummaryDry') -f (Format-Size $total), $sysDrive) -ForegroundColor Cyan }
else { Write-Host ((L 'SummaryDone') -f (Format-Size $freeBefore), (Format-Size $freeAfter), (Format-Size ([math]::Max(0, $freeAfter - $freeBefore)))) -ForegroundColor Cyan }

Write-Host ''
Write-Host (L 'Watch') -ForegroundColor White
$watch = New-Object System.Collections.ArrayList
$nvidiaCache = [double]0
foreach ($dir in @((Join-Path $env:LOCALAPPDATA 'NVIDIA\DXCache'), (Join-Path $env:USERPROFILE 'AppData\LocalLow\NVIDIA\DXCache'))) { $nvidiaCache += Get-Size (Get-ChildItem -LiteralPath $dir -File -Force -ErrorAction SilentlyContinue) }
[void]$watch.Add(@((L 'WatchNvidia'), $nvidiaCache))
[void]$watch.Add(@((L 'WatchDownloads'), (Get-Size (Get-Item -LiteralPath $downloads -Force -ErrorAction SilentlyContinue))))
$vhdx = @(Get-SafeFiles (Join-Path $env:LOCALAPPDATA 'Docker') | Where-Object { $_.Extension -eq '.vhdx' })
$vhdx += @(Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Packages\*\LocalState\ext4.vhdx') -Force -ErrorAction SilentlyContinue)
$vhdx += @(Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'wsl\*\ext4.vhdx') -Force -ErrorAction SilentlyContinue)
[void]$watch.Add(@((L 'WatchVhdx'), (Get-Size $vhdx)))
$hiberFile = Get-Item -LiteralPath (Join-Path $sysDrive '\hiberfil.sys') -Force -ErrorAction SilentlyContinue
if ($hiberFile) { [void]$watch.Add(@((L 'WatchHiber'), [double]$hiberFile.Length)) }
$shown = $false
foreach ($w in $watch) { if ($w[1] -ge 500MB) { Write-Host ('   {0,9}  {1}' -f (Format-Size $w[1]), $w[0]); $shown = $true } }
if (Test-Path -LiteralPath (Join-Path $sysDrive '\Windows.old')) { Write-Host ('   {0,9}  {1}' -f '', (L 'WatchWinOld')); $shown = $true }
if (-not $shown) { Write-Host ('   ' + (L 'WatchNone')) -ForegroundColor DarkGray }

# ===================================================================== Log
$logFile = Join-Path $PSScriptRoot 'windows-disk-cleaner.log'
$lines = New-Object System.Collections.ArrayList
$header = '==== {0:yyyy-MM-dd HH:mm} ====' -f (Get-Date)
if ($DryRun) { $header += ' (dry run)' }
[void]$lines.Add($header)
[void]$lines.Add(((L 'LogFreeSpace') -f (Format-Size $freeBefore), (Format-Size $freeAfter)))
foreach ($r in $results) { [void]$lines.Add(('{0,9}  {1}  {2}' -f (Format-Size $r.Bytes), $r.Label, $r.Detail)) }
[void]$lines.Add('')
Add-Content -LiteralPath $logFile -Value $lines -Encoding UTF8

if (-not $NoPause) { Write-Host ''; Read-Host (L 'PressEnter') | Out-Null }
