$ErrorActionPreference = 'Stop'
$setup = (Resolve-Path 'Epinal-Setup-x64.exe').Path
$directory = Join-Path $env:RUNNER_TEMP 'Epinal-Setup-Test'
$roaming = [Environment]::GetFolderPath('ApplicationData')
$dataDir = Join-Path $roaming 'Epinal Reader\Epinal'
$sentinel = Join-Path $dataDir 'install-test-data.txt'
$programs = [Environment]::GetFolderPath('Programs')
$desktop = [Environment]::GetFolderPath('DesktopDirectory')
$menuLink = Join-Path $programs 'Épinal.lnk'
$desktopLink = Join-Path $desktop 'Épinal.lnk'
$log = Join-Path $env:RUNNER_TEMP 'epinal-setup-test.log'

function Start-Installer([string[]]$setupArgs) {
  $process = Start-Process -FilePath $setup -ArgumentList $setupArgs -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    if (Test-Path $log) { Get-Content $log | Write-Host }
    throw "Le programme d’installation a échoué : $($process.ExitCode)"
  }
}

New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
Set-Content -Path $sentinel -Value 'Bibliothèque conservée'
try {
  $args = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
    "/DIR=`"$directory`"", "/LOG=`"$log`"")
  # First install: default desktop task should be selected.
  Start-Installer $args
  $exe = Join-Path $directory 'Epinal.exe'
  if (!(Test-Path $exe)) { throw 'Application non installée' }
  if (!(Test-Path (Join-Path $directory 'data\flutter_assets\AssetManifest.bin'))) { throw 'Ressources non installées' }
  $original = Get-FileHash 'build/windows/x64/runner/Release/Epinal.exe' -Algorithm SHA256
  if ((Get-FileHash $exe -Algorithm SHA256).Hash -ne $original.Hash) { throw 'Exécutable installé incorrect' }
  $shell = New-Object -ComObject WScript.Shell
  foreach ($link in @($menuLink, $desktopLink)) {
    if (!(Test-Path $link)) { throw "Raccourci absent : $link" }
    if ($shell.CreateShortcut($link).TargetPath -ne $exe) { throw "Mauvaise cible du raccourci : $link" }
  }
  if (!(Test-Path $sentinel)) { throw "Les données ont disparu pendant l’installation" }
  # Reinstall over the existing version: same directory and data.
  Start-Installer $args
  if (!(Test-Path $sentinel) -or !(Test-Path $exe)) { throw 'Échec de conservation pendant la mise à jour' }
  $uninstaller = Join-Path $directory 'unins000.exe'
  if (!(Test-Path $uninstaller)) { throw 'Désinstalleur absent' }
  $remove = Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -Wait -PassThru
  if ($remove.ExitCode -ne 0) { throw "Désinstallation en erreur : $($remove.ExitCode)" }
  if (Test-Path $exe) { throw 'Application encore présente après désinstallation' }
  if ((Test-Path $menuLink) -or (Test-Path $desktopLink)) { throw 'Raccourci encore présent après désinstallation' }
  if (!(Test-Path $sentinel)) { throw 'La désinstallation a supprimé les données utilisateur' }
  Write-Host 'Installation, raccourcis, mise à jour et conservation des données : OK'
} finally {
  Remove-Item $sentinel -Force -ErrorAction SilentlyContinue
}
