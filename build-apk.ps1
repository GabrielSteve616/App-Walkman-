$ErrorActionPreference = 'Stop'
$toolchain = 'C:\Walkman-tools'
$flutter = Join-Path $toolchain 'flutter\bin\flutter.bat'
$jdk = Get-ChildItem -Directory (Join-Path $toolchain 'java') | Select-Object -First 1
if (!(Test-Path -LiteralPath $flutter) -or !$jdk) {
    throw 'SDK Flutter ou JDK não encontrado em C:\Walkman-tools.'
}
$env:JAVA_HOME = $jdk.FullName
$env:ANDROID_HOME = Join-Path $toolchain 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PATH = "$toolchain\flutter\bin;$env:JAVA_HOME\bin;$env:PATH"
Push-Location $PSScriptRoot
try {
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao resolver dependências.' }
    & $flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Análise estática falhou.' }
    & $flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Testes falharam.' }
    & $flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'Compilação falhou.' }
    # Flutter rewrites these Windows paths without escaping the drive colon.
    $properties = Join-Path $PSScriptRoot 'android\local.properties'
    $propertiesText = [System.IO.File]::ReadAllText($properties)
    $propertiesText = $propertiesText -replace '=C:', '=C\:'
    [System.IO.File]::WriteAllText($properties, $propertiesText)
    Copy-Item -LiteralPath 'build\app\outputs\flutter-apk\app-release.apk' -Destination 'Walkmen.apk'
    Get-FileHash -Algorithm SHA256 -LiteralPath 'Walkmen.apk'
} finally {
    Pop-Location
}



