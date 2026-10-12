# Builds the Flutter web app and writes a unique deployment id.
# The id is compiled into the app, then published as build/web/petnest-build.json.
# The source stamp is restored afterward so local development stays on "dev".

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$stampPath = Join-Path $root 'lib\core\web\web_build_stamp.dart'
$utf8 = New-Object System.Text.UTF8Encoding $false
$original = [System.IO.File]::ReadAllText($stampPath)
$utc = (Get-Date).ToUniversalTime()
$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$buildId = $utc.ToString('yyyyMMddTHHmmss', $invariant) + 'Z-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$builtAt = $utc.ToString('yyyy-MM-ddTHH:mm:ss', $invariant) + 'Z'

try {
  $stamp = @"
// 檔案名稱：lib/core/web/web_build_stamp.dart
// 功能說明：這次正式 Web 建置暫時寫入的部署識別碼。

const String kWebBuildId = '$buildId';
const String kWebBuiltAt = '$builtAt';
"@
  [System.IO.File]::WriteAllText($stampPath, $stamp.Trim() + "`n", $utf8)

  $versionPath = Join-Path $root 'build\web\petnest-build.json'
  if (Test-Path $versionPath) {
    Remove-Item $versionPath -Force
  }

  & flutter build web @args
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  $versionJson = '{"buildId":"' + $buildId + '","builtAt":"' + $builtAt + '"}'
  [System.IO.File]::WriteAllText($versionPath, $versionJson, $utf8)
  Write-Output "petnest-build.json buildId=$buildId"
}
finally {
  [System.IO.File]::WriteAllText($stampPath, $original, $utf8)
}
