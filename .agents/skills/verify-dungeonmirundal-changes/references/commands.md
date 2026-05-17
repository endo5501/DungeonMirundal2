# Commands

## Default Windows path

Use the wrapper first:

```powershell
.\scripts\run_tests.ps1
```

Pass focused arguments through the wrapper when the wrapper behavior is sufficient:

```powershell
.\scripts\run_tests.ps1 "-gtest=res://tests/dungeon/test_monster_data.gd"
```

Why this wrapper matters in this repo:

- It runs `scripts/check_scripts.gd` before GUT.
- It fails on silent GUT load/parse problems even if GUT prints `All tests passed!`.

## Focused direct-GUT path

Use this when you need exact targeting, exact output capture, or the wrapper/run configuration is too broad.

Important:

- Always pass `-gconfig=` on direct GUT commands in this repo.
- Without `-gconfig=`, `.gutconfig.json` can cause broad test discovery through `dirs`.
- Always pass `-gexit` so the headless process exits after the run.

### Single test file

```powershell
& '<resolved-godot-console-exe>' --headless -s addons/gut/gut_cmdln.gd `
  -gconfig= -gexit `
  -gtest=res://tests/dungeon/test_monster_data.gd
```

### Single test name inside a file

```powershell
& '<resolved-godot-console-exe>' --headless -s addons/gut/gut_cmdln.gd `
  -gconfig= -gexit `
  -gtest=res://tests/dungeon/test_monster_data.gd `
  -gunit_test_name=spellcasting_monster_art
```

## Resolve the actual Godot console executable

In this environment, invoking the WinGet link directly may fail or behave inconsistently. Resolve the real target first:

```powershell
Get-Item "$env:LOCALAPPDATA\\Microsoft\\WinGet\\Links\\godot_console.exe" |
  Select-Object -ExpandProperty Target
```

Use the resolved target path for direct GUT commands.

## Monitored Windows fallback

Use this when direct invocation hangs, when you need stdout/stderr capture, or when you want a bounded wait:

```powershell
$exe = '<resolved-godot-console-exe>'
$out = [System.IO.Path]::GetTempFileName()
$err = [System.IO.Path]::GetTempFileName()
try {
    $p = Start-Process -FilePath $exe -ArgumentList @(
        '--headless',
        '-s', 'addons/gut/gut_cmdln.gd',
        '-gconfig=',
        '-gexit',
        '-gtest=res://tests/dungeon/test_monster_data.gd'
    ) -PassThru -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden

    if (-not ($p.WaitForExit(30000))) {
        $p | Stop-Process -Force
        'TIMED_OUT'
    } else {
        'EXIT_CODE=' + $p.ExitCode
    }

    '---STDOUT---'
    Get-Content $out
    '---STDERR---'
    Get-Content $err
}
finally {
    Remove-Item $out, $err -ErrorAction SilentlyContinue
}
```

## Parse-only check

Run the repo parse gate directly when you need to isolate script load errors:

```powershell
.\scripts\run_tests.ps1
```

or, for the underlying Godot script:

```powershell
& '<resolved-godot-console-exe>' --headless -s scripts/check_scripts.gd
```

## Clean up stray Godot processes

If a timed-out run leaves headless Godot behind:

```powershell
Get-Process | Where-Object { $_.ProcessName -like 'Godot*' } | Stop-Process -Force
```

## Escalation guidance

If sandboxed runs cannot execute the repo's Godot commands correctly:

- rerun the verification command with escalation
- keep the command narrow
- explain whether you are verifying a full wrapper path or a focused direct-GUT fallback
