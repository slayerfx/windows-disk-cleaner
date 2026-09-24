<#
    Runs windows-disk-cleaner.ps1 the way a user would, in a separate Windows
    PowerShell, and fails on any error output. Dry runs only: nothing is deleted
    or moved. The script is copied to a temporary folder first, so its log file
    lands there and a local config.json is not picked up.

    powershell -ExecutionPolicy Bypass -File .\tests\smoke-test.ps1
#>

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path ([IO.Path]::GetTempPath()) "windows-disk-cleaner-smoke-$PID"
New-Item -ItemType Directory -Force -Path $work | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'windows-disk-cleaner.ps1') -Destination $work
$script = Join-Path $work 'windows-disk-cleaner.ps1'

$badConfig = Join-Path $work 'bad.json'
'{ "tempAgeDays": 7, ' | Set-Content -LiteralPath $badConfig -Encoding UTF8

$runs = @(
    @{ Name = 'Dry run, defaults, English';       Args = @('-DryRun', '-Language', 'en');                                         ExitCode = 0; Expect = 'DRY RUN: about .+ could be freed' }
    @{ Name = 'Dry run, example config, French';  Args = @('-DryRun', '-Language', 'fr', '-Config', "$root\config.example.json"); ExitCode = 0; Expect = 'SIMULATION : environ .+ pourraient' }
    @{ Name = 'Unreadable configuration';         Args = @('-DryRun', '-Language', 'en', '-Config', $badConfig);                  ExitCode = 1; Expect = 'Cannot read the configuration' }
)

$failed = 0
foreach ($run in $runs) {
    $out = Join-Path $work 'out.txt'
    $err = Join-Path $work 'err.txt'
    $quoted = foreach ($a in $run.Args) { if ($a -match '\s') { "`"$a`"" } else { $a } }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$script`"") + @($quoted) + @('-NoElevate', '-NoPause')
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -NoNewWindow -Wait -PassThru `
                       -RedirectStandardOutput $out -RedirectStandardError $err
    $stdout = Get-Content -LiteralPath $out -Raw
    $stderr = "$(Get-Content -LiteralPath $err -Raw)".Trim()

    $problems = @()
    if ($p.ExitCode -ne $run.ExitCode) { $problems += "exit code $($p.ExitCode) instead of $($run.ExitCode)" }
    if ($stderr)                       { $problems += 'error output' }
    if ($stdout -notmatch $run.Expect) { $problems += "missing '$($run.Expect)'" }

    Write-Output "----- $($run.Name)"
    Write-Output $stdout
    if ($stderr) { Write-Output $stderr }
    if ($problems) {
        Write-Output "::error::$($run.Name): $($problems -join ', ')"
        $failed++
    } else {
        Write-Output "PASS  $($run.Name)"
    }
}

# Every run that got past the configuration writes its summary to the log
$log = Join-Path $work 'windows-disk-cleaner.log'
$dryRuns = @(Select-String -LiteralPath $log -Pattern '\(dry run\)' -ErrorAction SilentlyContinue).Count
if ($dryRuns -ne 2) {
    Write-Output "::error::Log file: $dryRuns dry-run entries instead of 2"
    $failed++
} else {
    Write-Output 'PASS  Log file'
}

Write-Output ''
Write-Output ("{0} check(s), {1} failed" -f ($runs.Count + 1), $failed)
if ($failed) { exit 1 }
