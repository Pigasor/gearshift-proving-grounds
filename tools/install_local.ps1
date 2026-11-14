# Installs the game on this PC as a normal program: exports the game data (.pck) next to a copy of
# the Godot runtime named GearShiftJoyDrive.exe (with the game's icon and name, see brand_exe.ps1),
# then puts a shortcut on the desktop. Also makes "GearShift JoyDrive!.exe" in the project folder,
# which runs the project there - always the current code.
# Run again after changes to update the installed game. (Godot finds <exe name>.pck next to the exe.)
# shortcut: uses the editor binary as the runtime (no export templates needed locally); the GitHub
# release exe is the proper standalone build.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$name = "GearShift JoyDrive!"
$engine = Join-Path $root "engine\Godot_v4.3-stable_win64.exe"
$ico = Join-Path $root "assets\icon.ico"
$brand = Join-Path $PSScriptRoot "brand_exe.ps1"
$version = [string](Get-Content (Join-Path $root "export_presets.cfg") | Where-Object { $_ -match '^application/file_version=' } | Select-Object -First 1)
$version = $version -replace '.*="(.*)"', '$1'
if (-not $version) { $version = "0.1.0.0" }

# the old name's install, shortcut and project-folder exe
$oldDest = Join-Path $env:LOCALAPPDATA "Programs\GearShift Proving Grounds"
if (Test-Path $oldDest) { Remove-Item -Recurse -Force $oldDest }
$oldLnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "GearShift Proving Grounds.lnk"
if (Test-Path $oldLnk) { Remove-Item -Force $oldLnk }
$oldExe = Join-Path $root "GearShift Proving Grounds.exe"
if (Test-Path $oldExe) { Remove-Item -Force $oldExe }

$dest = Join-Path $env:LOCALAPPDATA "Programs\$name"
New-Item -ItemType Directory -Force $dest | Out-Null
$pck = Join-Path $dest "GearShiftJoyDrive.pck"
& (Join-Path $root "engine\Godot_v4.3-stable_win64_console.exe") --headless --path $root --export-pack "Windows Desktop" $pck | Out-Null
if (-not (Test-Path $pck)) { throw "export failed: $pck missing" }
$exe = Join-Path $dest "GearShiftJoyDrive.exe"
Copy-Item $engine $exe -Force
& $brand -Exe $exe -Ico $ico -Name $name -Version $version | Out-Null
Copy-Item $ico (Join-Path $dest "icon.ico") -Force
$lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "$name.lnk"
$sh = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sh.TargetPath = $exe
$sh.WorkingDirectory = $dest
$sh.IconLocation = (Join-Path $dest "icon.ico") + ",0"
$sh.Description = $name
$sh.Save()

# the game exe in the project folder (a branded copy of the engine; started there it runs the project)
$game = Join-Path $root "$name.exe"
Copy-Item $engine $game -Force
& $brand -Exe $game -Ico $ico -Name $name -Version $version | Out-Null
Write-Output "installed: $dest"
Write-Output "shortcut: $lnk"
Write-Output "project exe: $game"
