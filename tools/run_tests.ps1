# Runs the GUT test suite headless and exits with GUT's exit code.
# Usage: powershell -File tools/run_tests.ps1
# Godot executable: $env:GODOT, default C:\Users\Davide\Desktop\GODOT\Godot_v4.5-stable_win64_console.exe.
# The project is imported first, because a fresh checkout or worktree has no .godot/ cache (class names, imports).
# A first headless import on a checkout with unimported fonts can crash and leave *.tmp files in .godot/imported:
# in that case the temporary files are removed and the import is retried once.

$ErrorActionPreference = 'Continue'

$DefaultGodot = 'C:\Users\Davide\Desktop\GODOT\Godot_v4.5-stable_win64_console.exe'
$MaxImportAttempts = 2

$godot = $env:GODOT
if ([string]::IsNullOrWhiteSpace($godot)) {
    $godot = $DefaultGodot
}
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
    [Console]::Error.WriteLine("run_tests: Godot executable not found: $godot (set `$env:GODOT)")
    exit 2
}

$projectDir = Split-Path -Parent $PSScriptRoot
$importedDir = Join-Path $projectDir '.godot\imported'

$importExit = 1
for ($attempt = 1; $attempt -le $MaxImportAttempts; $attempt++) {
    Write-Host "run_tests: importing project (attempt $attempt of $MaxImportAttempts)"
    & $godot --headless --path $projectDir --import
    $importExit = $LASTEXITCODE
    if ($importExit -eq 0) {
        break
    }
    [Console]::Error.WriteLine("run_tests: import failed with exit code $importExit")
    if (Test-Path -LiteralPath $importedDir -PathType Container) {
        $tmpFiles = @(Get-ChildItem -LiteralPath $importedDir -Filter '*.tmp' -File -Force)
        foreach ($tmp in $tmpFiles) {
            Remove-Item -LiteralPath $tmp.FullName -Force
        }
        Write-Host "run_tests: removed $($tmpFiles.Count) temporary file(s) from .godot\imported"
    }
}
if ($importExit -ne 0) {
    [Console]::Error.WriteLine("run_tests: import failed $MaxImportAttempts times (last exit code $importExit), tests not run")
    exit 3
}

Write-Host 'run_tests: running GUT'
& $godot --headless --path $projectDir -s addons/gut/gut_cmdln.gd
$gutExit = $LASTEXITCODE
if ($gutExit -eq 0) {
    Write-Host 'run_tests: OK'
} else {
    [Console]::Error.WriteLine("run_tests: FAILED (GUT exit code $gutExit)")
}
exit $gutExit
