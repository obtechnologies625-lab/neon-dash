$root = 'C:\Users\user\.cline\data\workspaces\chat\godot-endless-runner'
$log = Join-Path $root 'tools\export.log'
$godot = Join-Path $root 'tools\godot-editor\Godot_v4.7.2-stable_win64.exe'
function L($m) { Add-Content -Path $log -Value $m }
Set-Content -Path $log -Value ('=== ' + (Get-Date -Format 'HH:mm:ss') + ' import + export ===')

L '--- pass 1: import project ---'
& $godot --headless --path $root --import 2>&1 | ForEach-Object { L $_ }

L '--- pass 2: export Web ---'
& $godot --headless --path $root --export-release 'Web' (Join-Path $root 'build\index.html') 2>&1 | ForEach-Object { L $_ }

L '=== DONE ==='
