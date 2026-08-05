[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $projectRoot

$javaCandidates = @(
    $env:JAVA_HOME,
    (Join-Path $env:ProgramFiles "Android\Android Studio1\jbr"),
    (Join-Path $env:ProgramFiles "Android\Android Studio\jbr")
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
$validJavaHome = $javaCandidates | Where-Object {
    (Test-Path -LiteralPath (Join-Path $_ "bin\java.exe")) -and
    (Test-Path -LiteralPath (Join-Path $_ "lib\jvm.cfg"))
} | Select-Object -First 1
if (-not $validJavaHome) {
    throw "A valid Android JDK was not found."
}
$env:JAVA_HOME = $validJavaHome

function Assert-LastExitCode {
    param([Parameter(Mandatory = $true)][string]$Step)
    if ($LASTEXITCODE -ne 0) {
        throw "$Step failed with exit code $LASTEXITCODE."
    }
}

function Set-HtmlElementText {
    param(
        [Parameter(Mandatory = $true)][string]$Html,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $pattern = '(<[^>]+\bid="' + [regex]::Escape($Id) + '"[^>]*>)[^<]*(</[^>]+>)'
    $expression = [regex]::new($pattern)
    if ($expression.Matches($Html).Count -ne 1) {
        throw "Expected exactly one HTML element with id '$Id'."
    }
    $encoded = [Net.WebUtility]::HtmlEncode($Value)
    $evaluator = [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        return $match.Groups[1].Value + $encoded + $match.Groups[2].Value
    }
    return $expression.Replace($Html, $evaluator, 1)
}

if (-not (Test-Path -LiteralPath "pubspec.yaml") -or
    -not (Test-Path -LiteralPath "lib\main.dart") -or
    -not (Test-Path -LiteralPath "assets")) {
    throw "Run this script from the Flutter project root."
}

if (-not (Test-Path -LiteralPath "android\key.properties")) {
    throw "Release signing is missing. See SIGNING-INSTRUCTIONS.txt."
}

$notificationIcons = @(
    Get-ChildItem -LiteralPath "android\app\src\main\res" -Recurse -File -Filter "notification_icon.png"
)
if ($notificationIcons.Count -lt 5) {
    throw "Android notification icons are incomplete."
}

$pubspec = Get-Content -LiteralPath "pubspec.yaml" -Raw -Encoding UTF8
$versionMatch = [regex]::Match(
    $pubspec,
    '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$'
)
if (-not $versionMatch.Success) {
    throw "pubspec.yaml does not contain a valid version and build number."
}
$versionName = $versionMatch.Groups[1].Value
$versionCode = $versionMatch.Groups[2].Value

Write-Host "[1/8] flutter clean"
if (Test-Path -LiteralPath "android\gradlew.bat") {
    $savedErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $gradleStopOutput = & "android\gradlew.bat" --stop 2>&1
    $gradleStopExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorPreference
    if ($gradleStopExitCode -ne 0) {
        throw "Unable to stop the project Gradle daemon before cleaning."
    }
}
& flutter clean
Assert-LastExitCode "flutter clean"
$staleReleaseApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path -LiteralPath $staleReleaseApk) {
    throw "flutter clean left a stale Release APK; refusing to reuse it."
}

Write-Host "[2/8] flutter pub get"
& flutter pub get
Assert-LastExitCode "flutter pub get"

Write-Host "[3/8] flutter analyze"
& flutter analyze
Assert-LastExitCode "flutter analyze"

Write-Host "[4/8] flutter build apk --release"
& flutter build apk --release
Assert-LastExitCode "Flutter Release build"

$sourceApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path -LiteralPath $sourceApk -PathType Leaf)) {
    throw "Release APK was not created at $sourceApk"
}

$sourceInfo = Get-Item -LiteralPath $sourceApk
if ($sourceInfo.Length -lt 1MB) {
    throw "The generated APK is empty or implausibly small."
}

$signature = New-Object byte[] 4
$stream = [IO.File]::OpenRead($sourceApk)
try {
    if ($stream.Read($signature, 0, 4) -ne 4) {
        throw "Unable to read the APK signature."
    }
} finally {
    $stream.Dispose()
}
if ([BitConverter]::ToString($signature) -ne "50-4B-03-04") {
    throw "The generated file is not an APK/ZIP archive."
}

$sdkRoot = if ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} elseif ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
} else {
    Join-Path $env:LOCALAPPDATA "Android\Sdk"
}
$buildToolsRoot = Join-Path $sdkRoot "build-tools"
$buildTools = Get-ChildItem -LiteralPath $buildToolsRoot -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 1
if (-not $buildTools) {
    throw "Android build-tools were not found under $buildToolsRoot"
}
$aapt = Join-Path $buildTools.FullName "aapt.exe"
$apksigner = Join-Path $buildTools.FullName "apksigner.bat"
$zipalign = Join-Path $buildTools.FullName "zipalign.exe"
foreach ($tool in @($aapt, $apksigner, $zipalign)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Required Android tool is missing: $tool"
    }
}

Write-Host "[5/8] Verify package, version, signing, and alignment"
$badging = & $aapt dump badging $sourceApk 2>&1
Assert-LastExitCode "aapt APK inspection"
$badgingText = $badging -join "`n"
if ($badgingText -notmatch "package: name='com\.abuammar\.horseclub\.mobile2026'") {
    throw "Unexpected Android package name."
}
if ($badgingText -notmatch "versionCode='$([regex]::Escape($versionCode))'") {
    throw "Unexpected Android versionCode."
}
if ($badgingText -notmatch "versionName='$([regex]::Escape($versionName))'") {
    throw "Unexpected Android versionName."
}

$savedErrorPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$signingOutput = & $apksigner verify --verbose --print-certs $sourceApk 2>&1
$signingExitCode = $LASTEXITCODE
$ErrorActionPreference = $savedErrorPreference
if ($signingExitCode -ne 0) {
    throw "APK signature verification failed."
}
$signingText = $signingOutput -join "`n"
if ($signingText -notmatch 'Verified using v2 scheme \(APK Signature Scheme v2\): true') {
    throw "APK does not contain the required v2 Release signature."
}
if ($signingText -match 'Android Debug') {
    throw "A Debug certificate was detected in the Release APK."
}

$savedErrorPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$alignmentOutput = & $zipalign -c -P 16 4 $sourceApk 2>&1
$alignmentExitCode = $LASTEXITCODE
$ErrorActionPreference = $savedErrorPreference
if ($alignmentExitCode -ne 0) {
    throw "APK zip alignment verification failed."
}

Write-Host "[6/8] Copy verified APK into docs/downloads"
$downloadsDirectory = Join-Path $projectRoot "docs\downloads"
New-Item -ItemType Directory -Path $downloadsDirectory -Force | Out-Null
$downloadApk = Join-Path $downloadsDirectory "HorseClub.apk"
if (Test-Path -LiteralPath $downloadApk) {
    Remove-Item -LiteralPath $downloadApk -Force
}
Copy-Item -LiteralPath $sourceApk -Destination $downloadApk -Force

$sourceHash = (Get-FileHash -LiteralPath $sourceApk -Algorithm SHA256).Hash
$downloadHash = (Get-FileHash -LiteralPath $downloadApk -Algorithm SHA256).Hash
$downloadInfo = Get-Item -LiteralPath $downloadApk
if ($sourceHash -ne $downloadHash -or $sourceInfo.Length -ne $downloadInfo.Length) {
    throw "The downloadable APK does not match the original Release APK."
}

Write-Host "[7/8] Update download-page release metadata"
$indexPath = Join-Path $projectRoot "docs\index.html"
if (-not (Test-Path -LiteralPath $indexPath)) {
    throw "docs/index.html is missing."
}
$html = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8
$sizeText = ($downloadInfo.Length / 1MB).ToString("0.00", [Globalization.CultureInfo]::InvariantCulture) + " MB"
$dateText = Get-Date -Format "yyyy-MM-dd"
$html = Set-HtmlElementText -Html $html -Id "app-version" -Value $versionName
$html = Set-HtmlElementText -Html $html -Id "last-updated" -Value $dateText
$html = Set-HtmlElementText -Html $html -Id "apk-size" -Value $sizeText
$html = Set-HtmlElementText -Html $html -Id "apk-sha256" -Value $downloadHash
[IO.File]::WriteAllText($indexPath, $html, (New-Object Text.UTF8Encoding($false)))

$updatedHtml = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8
if ([regex]::Matches($updatedHtml, 'href="\./downloads/HorseClub\.apk"').Count -ne 1) {
    throw "The page must contain exactly one relative HorseClub.apk download link."
}
if ([regex]::Matches($updatedHtml, 'id="android-download"').Count -ne 1 -or
    [regex]::Matches($updatedHtml, 'class="download-button"').Count -ne 1) {
    throw "The page must contain exactly one visible Android download button."
}
if ($updatedHtml -match '(?i)(file:///|localhost|127\.0\.0\.1|[A-Z]:\\Users\\)') {
    throw "A forbidden local path was found in docs/index.html."
}

Write-Host "[8/8] Release package ready"
Write-Host "Original APK : $sourceApk"
Write-Host "Download APK : $downloadApk"
Write-Host "Version      : $versionName ($versionCode)"
Write-Host "Size         : $($downloadInfo.Length) bytes ($sizeText)"
Write-Host "SHA-256      : $downloadHash"
