$ErrorActionPreference = 'Stop'
$root = 'C:\Users\user\.cline\data\workspaces\chat\godot-endless-runner'
$log = Join-Path $root 'tools\setup.log'
function L($m) { Add-Content -Path $log -Value ('[' + (Get-Date -Format 'HH:mm:ss') + '] ' + $m) }
try {
    L 'SETUP START'
    $editorDir = Join-Path $root 'tools\godot-editor'
    New-Item -ItemType Directory -Force -Path $editorDir | Out-Null
    L 'extracting editor...'
    Expand-Archive -Path (Join-Path $root 'tools\Godot_v4.7.2-stable_win64.exe.zip') -DestinationPath $editorDir -Force
    $exe = Get-ChildItem $editorDir -Filter 'Godot_v4.7.2-stable_win64.exe' -Recurse | Select-Object -First 1
    L ('editor exe: ' + $exe.FullName)

    L 'extracting templates...'
    $tmp = Join-Path $root 'tools\tpl'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $tpz = Join-Path $root 'tools\templates.zip'
    Copy-Item (Join-Path $root 'tools\Godot_v4.7.2-stable_export_templates.tpz') $tpz -Force
    Expand-Archive -Path $tpz -DestinationPath $tmp -Force
    Remove-Item $tpz -Force

    $dest = Join-Path $env:APPDATA ('Godot\export_templates\4.7.2.stable')
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $src = Join-Path $tmp 'templates'
    Copy-Item (Join-Path $src '*') $dest -Recurse -Force
    Set-Content -Path (Join-Path $dest 'version.txt') -Value '4.7.2.stable' -Encoding ASCII
    L ('templates installed: ' + (Get-ChildItem $dest -Filter 'web_*' | Measure-Object).Count + ' web templates')
    Remove-Item $tmp -Recurse -Force
    Remove-Item (Join-Path $root 'tools\Godot_v4.7.2-stable_export_templates.tpz') -Force
    L 'free GB: ' + [math]::Round((Get-PSDrive C).Free/1GB,1)
    L 'SETUP COMPLETE'
} catch {
    L ('SETUP FAILED: ' + $_.Exception.Message)
}
