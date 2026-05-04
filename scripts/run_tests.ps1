#!/usr/bin/env pwsh
# scripts/run_tests.ps1
#
# Test runner with two safety nets that prevent silent test failures from
# slipping past GUT's "All tests passed!" message:
#
#   1. Pre-flight: every .gd file under src/ and tests/ is parsed via
#      scripts/check_scripts.gd. Files that fail to parse halt the run before
#      GUT is even invoked.
#
#   2. Post-scan: GUT output is searched for patterns that indicate a script
#      was silently dropped from the test set, even when GUT itself returned 0:
#        - SCRIPT ERROR:                    (parser / load error)
#        - Failed to load script            (engine load failure)
#        - Ignoring script ... because it   (GUT misclassifying a parse-failed
#          does not extend GutTest             test as "not a GutTest")
#
# Any extra arguments are forwarded to gut_cmdln.gd (e.g. -gtest=...).
#
# Exit code: 0 if both phases pass, 1 otherwise.

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Invoke-GodotCaptured {
    param([string[]]$Arguments)
    # Start-Process is the only reliable way under PowerShell to capture both
    # stdout AND stderr from a native exe. Direct invocation (& godot ...)
    # silently swallows stderr; "2>&1" wraps each line in an ErrorRecord.
    $tmpStdout = [System.IO.Path]::GetTempFileName()
    $tmpStderr = [System.IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath godot -ArgumentList $Arguments `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $tmpStdout -RedirectStandardError $tmpStderr
        $stdoutLines = Get-Content $tmpStdout
        $stderrLines = Get-Content $tmpStderr
        return [pscustomobject]@{
            ExitCode = $proc.ExitCode
            StdOut   = $stdoutLines
            StdErr   = $stderrLines
            Combined = @($stdoutLines) + @($stderrLines)
        }
    }
    finally {
        Remove-Item $tmpStdout, $tmpStderr -ErrorAction SilentlyContinue
    }
}

Write-Host '=== Phase 1/2: Pre-flight script parse check ===' -ForegroundColor Cyan
$preflight = Invoke-GodotCaptured @('--headless', '-s', 'scripts/check_scripts.gd')
$preflight.StdOut | ForEach-Object { Write-Host $_ }
$preflight.StdErr | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
if ($preflight.ExitCode -ne 0) {
    Write-Host ''
    Write-Host '[X] Pre-flight detected parse failures. Aborting before GUT.' -ForegroundColor Red
    Write-Host '    Fix the PARSE_FAIL paths above, then re-run.' -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host '=== Phase 2/2: GUT test run ===' -ForegroundColor Cyan
$gutArgs = @('--headless', '-s', 'addons/gut/gut_cmdln.gd') + $args
$gut = Invoke-GodotCaptured $gutArgs
$gut.StdOut | ForEach-Object { Write-Host $_ }
$gut.StdErr | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }

$silentFailurePatterns = @(
    'SCRIPT ERROR:',
    'Failed to load script',
    'Ignoring script .* because it does not extend GutTest'
)
$matchedLines = $gut.Combined | Select-String -Pattern $silentFailurePatterns

Write-Host ''
Write-Host '=== Result ===' -ForegroundColor Cyan
if ($matchedLines) {
    Write-Host '[X] Detected silent test failure indicators in GUT output:' -ForegroundColor Red
    foreach ($m in $matchedLines) {
        Write-Host ('  ' + $m.Line) -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Host ("GUT reported exit code $($gut.ExitCode), but the patterns above mean some tests never ran.") -ForegroundColor Red
    exit 1
}

if ($gut.ExitCode -ne 0) {
    Write-Host "[X] GUT reported a non-zero exit code: $($gut.ExitCode)" -ForegroundColor Red
    exit $gut.ExitCode
}

Write-Host '[OK] All checks passed: pre-flight clean, GUT green, no silent failures.' -ForegroundColor Green
exit 0
