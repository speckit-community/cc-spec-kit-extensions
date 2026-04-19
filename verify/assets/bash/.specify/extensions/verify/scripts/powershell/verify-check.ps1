# verify-check.ps1 — Run verification checks on spec artifacts
param(
    [string]$SpecDir = "."
)

$FeatureDir = $null
$SpecsPath = Join-Path $SpecDir "specs"

if (Test-Path $SpecsPath) {
    $FeatureDir = Get-ChildItem -Path $SpecsPath -Directory | Select-Object -First 1
}

if (-not $FeatureDir) {
    Write-Host "No feature directory found under specs/"
    exit 1
}

$FeatureName = $FeatureDir.Name
$Pass = 0
$Warn = 0
$Fail = 0

Write-Host "🔍 Spec Verification Report"
Write-Host "Feature: $FeatureName"
Write-Host ""

# Check spec.md
if (Test-Path (Join-Path $FeatureDir.FullName "spec.md")) {
    Write-Host "  ✅ spec.md — Found"
    $Pass++
} else {
    Write-Host "  ❌ spec.md — Missing"
    $Fail++
}

# Check plan.md
if (Test-Path (Join-Path $FeatureDir.FullName "plan.md")) {
    Write-Host "  ✅ plan.md — Found"
    $Pass++
} else {
    Write-Host "  ❌ plan.md — Missing"
    $Fail++
}

# Check tasks.md
if (Test-Path (Join-Path $FeatureDir.FullName "tasks.md")) {
    Write-Host "  ✅ tasks.md — Found"
    $Pass++
} else {
    Write-Host "  ⚠️  tasks.md — Missing (optional at this stage)"
    $Warn++
}

Write-Host ""
Write-Host "Result: $Pass passed, $Warn warnings, $Fail failed"

if ($Fail -gt 0) { exit 1 }
