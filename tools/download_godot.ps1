$ErrorActionPreference = 'Continue'
$root = 'C:\Users\user\.cline\data\workspaces\chat\godot-endless-runner'
$dl = Join-Path $root 'tools'
$log = Join-Path $dl 'download.log'
function L($m) { Add-Content -Path $log -Value ('[' + (Get-Date -Format 'HH:mm:ss') + '] ' + $m) }
$base = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/'
$files = @('Godot_v4.7.2-stable_win64.exe.zip','Godot_v4.7.2-stable_export_templates.tpz')
L 'DOWNLOAD START'
foreach ($f in $files) {
    $out = Join-Path $dl $f
    $ok = $false
    for ($t = 1; $t -le 3; $t++) {
        try {
            L "downloading $f (attempt $t)"
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add('User-Agent','Mozilla/5.0')
            $wc.DownloadFile($base + $f, $out)
            $wc.Dispose()
            L ("done $f -> " + [math]::Round((Get-Item $out).Length/1MB,1) + ' MB')
            $ok = $true
            break
        } catch {
            L ('error: ' + $_.Exception.Message)
            Start-Sleep -Seconds 5
        }
    }
    if (-not $ok) { L "FAILED $f" }
}
L 'DOWNLOAD COMPLETE'
