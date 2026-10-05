# Serves the exported web build from .\build on http://localhost:8000
#
#   .\serve.ps1
#
# A plain static file server is NOT enough for a Godot web export: the engine
# loads as WebAssembly and needs cross-origin isolation headers, otherwise the
# browser refuses to start it. This script sends the required headers.
param([int]$Port = 8000)

$ErrorActionPreference = 'Stop'
$buildDir = Join-Path $PSScriptRoot 'build'

if (-not (Test-Path (Join-Path $buildDir 'index.html'))) {
	Write-Host "No build found at $buildDir" -ForegroundColor Red
	Write-Host "Export first with:  .\tools\export.ps1"
	exit 1
}

$mimeTypes = @{
	'.html' = 'text/html; charset=utf-8'
	'.js'   = 'application/javascript'
	'.json' = 'application/json'
	'.wasm' = 'application/wasm'
	'.pck'  = 'application/octet-stream'
	'.png'  = 'image/png'
	'.svg'  = 'image/svg+xml'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host ""
Write-Host "  Neon Dash is running at  http://localhost:$Port/" -ForegroundColor Cyan
Write-Host "  Press Ctrl+C to stop." -ForegroundColor DarkGray
Write-Host ""

try {
	while ($listener.IsListening) {
		$context = $listener.GetContext()

		# One bad request must not take the whole server down.
		try {
			$request = $context.Request
			$response = $context.Response

			# Required by Godot's threaded WebAssembly build.
			$response.Headers.Add('Cross-Origin-Opener-Policy', 'same-origin')
			$response.Headers.Add('Cross-Origin-Embedder-Policy', 'require-corp')
			$response.Headers.Add('Cache-Control', 'no-store')

			$relative = $request.Url.AbsolutePath.TrimStart('/')
			if ([string]::IsNullOrWhiteSpace($relative)) {
				$relative = 'index.html'
			}

			# Keep requests inside the build folder.
			$fullPath = Join-Path $buildDir ($relative -replace '/', '\')
			if (-not $fullPath.StartsWith((Resolve-Path $buildDir).Path)) {
				$response.StatusCode = 403
				$response.Close()
				continue
			}

			if (-not (Test-Path $fullPath -PathType Leaf)) {
				$response.StatusCode = 404
				$response.Close()
				continue
			}

			$bytes = [System.IO.File]::ReadAllBytes($fullPath)
			$extension = [System.IO.Path]::GetExtension($fullPath).ToLowerInvariant()
			$response.ContentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { 'application/octet-stream' }
			$response.ContentLength64 = $bytes.Length

			# A HEAD response must not include a body.
			if ($request.HttpMethod -ne 'HEAD') {
				$response.OutputStream.Write($bytes, 0, $bytes.Length)
			}

			$response.Close()
		}
		catch {
			Write-Host "request failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
		}
	}
}
finally {
	$listener.Stop()
	$listener.Close()
}