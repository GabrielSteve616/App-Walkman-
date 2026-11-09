$ErrorActionPreference = 'Stop'
$toolchain = 'C:\Walkman-tools'
$sdk = Join-Path $toolchain 'android-sdk'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$env:ANDROID_HOME = $sdk
$env:ANDROID_AVD_HOME = Join-Path $toolchain 'avd'
$apk = Join-Path $PSScriptRoot 'Walkmen.apk'

function Find-WalkmenPhone {
    foreach ($row in (& $adb devices)) {
        if ($row -match '^(emulator-\d+)\s+device$') {
            $candidate = $Matches[1]
            $name = & $adb -s $candidate emu avd name 2>$null
            if ($name -contains 'Walkmen_Celular') { return $candidate }
        }
    }
    return $null
}

if (!(Test-Path -LiteralPath $emulator) -or !(Test-Path -LiteralPath $apk)) {
    throw 'Emulador ou Walkmen.apk não encontrado.'
}
& $adb start-server
$phone = Find-WalkmenPhone
$starting = Get-CimInstance Win32_Process -Filter "Name='emulator.exe' OR Name='qemu-system-x86_64.exe'" |
    Where-Object { $_.CommandLine -match '\bWalkmen_Celular\b' }
if (!$phone -and !$starting) {
    # A window is intentional: this is the interactive phone display.
    Start-Process -FilePath $emulator -WorkingDirectory $toolchain -WindowStyle Normal -ArgumentList @(
        '-avd', 'Walkmen_Celular', '-gpu', 'swiftshader', '-no-snapshot-save', '-no-boot-anim', '-scale', '0.65'
    )
}
$deadline = (Get-Date).AddMinutes(4)
do {
    if (!$phone) { $phone = Find-WalkmenPhone }
    if ($phone) {
        $boot = & $adb -s $phone shell getprop sys.boot_completed 2>$null
        if ($boot -and $boot.Trim() -eq '1') { break }
    }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)
if (!$phone -or !$boot -or $boot.Trim() -ne '1') {
    throw 'O Android ainda não terminou de iniciar. Aguarde a tela do celular e tente novamente.'
}
& $adb -s $phone install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível instalar o APK.' }
& $adb -s $phone shell input keyevent 82
& $adb -s $phone shell am start -n 'br.com.walkman.walkman/.MainActivity'
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível abrir o Walkmen.' }
Write-Host 'Walkmen aberto no celular virtual. Use o mouse para tocar e arrastar.'
