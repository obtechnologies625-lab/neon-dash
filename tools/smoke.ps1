$root = 'C:\Users\user\.cline\data\workspaces\chat\godot-endless-runner'
$godot = Join-Path $root 'tools\godot-editor\Godot_v4.7.2-stable_win64.exe'
& $godot --headless --path $root --quit-after 420 2>&1 | Out-String
