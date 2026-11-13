# Installs the game on this PC as a normal program: exports the game data (.pck) next to a copy of
# the Godot runtime named GearShiftProvingGrounds.exe, then puts a shortcut on the desktop.
# Run again after changes to update the installed game. (Godot finds <exe name>.pck next to the exe.)
# shortcut: uses the editor binary as the runtime (no export templates needed locally); the GitHub
# release exe is the proper standalone build.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $env:LOCALAPPDATA "Programs\GearShift Proving Grounds"
New-Item -ItemType Directory -Force $dest | Out-Null
$pck = Join-Path $dest "GearShiftProvingGrounds.pck"
& (Join-Path $root "engine\Godot_v4.3-stable_win64_console.exe") --headless --path $root --export-pack "Windows Desktop" $pck | Out-Null
if (-not (Test-Path $pck)) { throw "export failed: $pck missing" }
Copy-Item (Join-Path $root "engine\Godot_v4.3-stable_win64.exe") (Join-Path $dest "GearShiftProvingGrounds.exe") -Force
Copy-Item (Join-Path $root "assets\icon.ico") (Join-Path $dest "icon.ico") -Force
$lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "GearShift Proving Grounds.lnk"
$sh = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sh.TargetPath = Join-Path $dest "GearShiftProvingGrounds.exe"
$sh.WorkingDirectory = $dest
$sh.IconLocation = (Join-Path $dest "icon.ico") + ",0"
$sh.Description = "GearShift Proving Grounds"
$sh.Save()
# The game exe in the project folder: a hard link to the engine (no extra disk space). Started from
# the project folder it runs the project there - always the current code (it replaced play.bat).
$game = Join-Path $root "GearShift Proving Grounds.exe"
if (-not (Test-Path $game)) { New-Item -ItemType HardLink -Path $game -Target (Join-Path $root "engine\Godot_v4.3-stable_win64.exe") | Out-Null }
Write-Output "installed: $dest"
Write-Output "shortcut: $lnk"
