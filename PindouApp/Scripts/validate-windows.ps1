[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-FileContains {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Pattern,

        [Parameter(Mandatory)]
        [string] $FailureMessage
    )

    $content = Get-Content -Raw -LiteralPath $Path
    if ($content -notmatch $Pattern) {
        $script:failures.Add($FailureMessage)
    }
}

$projectSpec = Join-Path $projectRoot 'project.yml'
$workflow = Join-Path $workspaceRoot 'codemagic.yaml'
$baseConfig = Join-Path $projectRoot 'Configurations/Base.xcconfig'

Assert-FileContains $projectSpec 'iOS:\s*"16\.0"' 'project.yml 未固定 iOS 16.0'
Assert-FileContains $projectSpec 'TARGETED_DEVICE_FAMILY:\s*"1,2"' '工程未同时启用 iPhone 与 iPad'
Assert-FileContains $projectSpec 'PRODUCT_MODULE_NAME:\s*PindouApp' 'Swift 模块名未固定为 PindouApp'
Assert-FileContains $projectSpec 'PindouAppUnitTests:' '缺少单元测试 target'
Assert-FileContains $workflow 'ios-validation:' 'Codemagic 缺少验证工作流'
Assert-FileContains $workflow 'ios-ipa-adhoc:' 'Codemagic 缺少 Ad Hoc IPA 工作流'
Assert-FileContains $workflow 'ios-testflight:' 'Codemagic 缺少 TestFlight 工作流'
Assert-FileContains $workflow 'xcodegen generate' 'Codemagic 缺少 XcodeGen 生成步骤'
Assert-FileContains $workflow 'xcodebuild test' 'Codemagic 缺少 XCTest 执行步骤'
Assert-FileContains $workflow 'xcode-project build-ipa' 'Codemagic 缺少 IPA 构建步骤'
Assert-FileContains $baseConfig 'PINDOU_BUNDLE_ID\s*=\s*[^\s]+' 'Base.xcconfig 缺少 Bundle ID'

$requiredFiles = @(
    'App/AppShell/PindouApplication.swift',
    'App/AppShell/RootView.swift',
    'Shared/Navigation/AppSection.swift',
    'Tests/Unit/AppSectionTests.swift',
    'Configurations/Base.xcconfig'
)

foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        $failures.Add("缺少文件：$relativePath")
    }
}

$forbiddenAPIs = 'ContentUnavailableView|@Observable|SwiftData'
$apiMatches = Get-ChildItem -LiteralPath $projectRoot -Recurse -Filter '*.swift' -File |
    Select-String -Pattern $forbiddenAPIs
if ($apiMatches) {
    $failures.Add("发现不兼容 iOS 16 的 API：$($apiMatches.Path -join ', ')")
}

$domainFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'Features') -Recurse -Filter '*.swift' -File |
    Where-Object { $_.FullName -match '[\\/]Domain[\\/]' }
$domainLeaks = $domainFiles | Select-String -Pattern '^import\s+(SwiftUI|UIKit|CoreData|Vision|CoreImage)$'
if ($domainLeaks) {
    $failures.Add("Domain 引用了 Apple 平台框架：$($domainLeaks.Path -join ', ')")
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'Windows static validation passed.'
Write-Output 'Deployment target: iOS 16.0'
Write-Output 'Device families: iPhone + iPad'
Write-Output 'Swift compile and IPA: delegated to Codemagic'

$bundleIDLine = Select-String -LiteralPath $baseConfig -Pattern '^PINDOU_BUNDLE_ID\s*=\s*(.+)$'
if ($bundleIDLine.Matches.Groups[1].Value.Trim() -eq 'com.yourcompany.pindou') {
    Write-Warning 'Bundle ID 仍为占位值；签名构建前需同步修改 Base.xcconfig 和 codemagic.yaml。'
}
