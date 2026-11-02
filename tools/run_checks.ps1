# Runs every project check and exits with a non-zero code at the first failure:
#   1. tools/run_tests.ps1 (import + GUT test suite)
#   2. tools/check_file_sizes.gd (no .gd/.tscn over 400 lines under core/ systems/ ui/ tools/)
#   3. tools/check_forbidden_refs.gd (no previous-game paths, no root node paths, no bare print calls)
# Usage: powershell -File tools/run_checks.ps1
# Godot executable: $env:GODOT, default C:\Users\Davide\Desktop\GODOT\Godot_v4.5-stable_win64_console.exe.

$ErrorActionPreference = 'Continue'

$DefaultGodot = 'C:\Users\Davide\Desktop\GODOT\Godot_v4.5-stable_win64_console.exe'
$CheckScripts = @('tools/check_file_sizes.gd', 'tools/check_forbidden_refs.gd')

$godot = $env:GODOT
if ([string]::IsNullOrWhiteSpace($godot)) {
    $godot = $DefaultGodot
}
$projectDir = Split-Path -Parent $PSScriptRoot

Write-Host '=== run_checks: tests ==='
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run_tests.ps1')
$testsExit = $LASTEXITCODE
if ($testsExit -ne 0) {
    [Console]::Error.WriteLine("run_checks: FAILED at tests (exit code $testsExit)")
    exit $testsExit
}

foreach ($script in $CheckScripts) {
    Write-Host "=== run_checks: $script ==="
    & $godot --headless --path $projectDir -s $script
    $checkExit = $LASTEXITCODE
    if ($checkExit -ne 0) {
        [Console]::Error.WriteLine("run_checks: FAILED at $script (exit code $checkExit)")
        exit $checkExit
    }
}

Write-Host 'run_checks: OK'
exit 0
