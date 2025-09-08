<#
  collect-readmes.ps1
  - README*.md を docs/ 配下にコピー（ファイル名を保持）
  - 同階層の画像もコピー（相対リンク維持）
  - -Clean を付けると docs/ を削除してから再生成
#>

[CmdletBinding()]
param(
  [string]$OutDir = "docs",
  [switch]$Clean
)

$ErrorActionPreference = 'Stop'

# --- Git ルートを特定（なければカレント） ---
$gitRoot = (git rev-parse --show-toplevel) 2>$null
if (-not $gitRoot) { $gitRoot = (Get-Location).Path }

function Get-Rel($base, $path) {
  $baseUri   = [Uri]((Resolve-Path $base).ProviderPath + [IO.Path]::DirectorySeparatorChar)
  $targetUri = [Uri]((Resolve-Path $path).ProviderPath)
  $rel = [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString())
  return $rel.Replace('/','\')
}

# 出力初期化
if ($Clean -and (Test-Path $OutDir)) {
  Write-Host "Cleaning '$OutDir'..." -ForegroundColor Yellow
  Remove-Item -Recurse -Force $OutDir
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "Collecting README*.md into '$OutDir'..." -ForegroundColor Cyan

# README*.md をそのままコピー
Get-ChildItem -Path $gitRoot -Recurse -File -Include README*.md | ForEach-Object {
  $src = $_.FullName
  $rel = Get-Rel $gitRoot $src
  $dst = Join-Path $OutDir $rel
  $dstDir = Split-Path $dst -Parent
  New-Item -ItemType Directory -Force -Path $dstDir | Out-Null

  Copy-Item $src $dst -Force
  Write-Host "✓ $rel -> $dst" -ForegroundColor Green

  # 同階層の画像もコピー
  $imgDir = Split-Path $src -Parent
  Get-ChildItem $imgDir -File -Include *.png,*.jpg,*.jpeg,*.gif,*.svg,*.webp,*.bmp,*.ico | ForEach-Object {
    $imgRel = Get-Rel $gitRoot $_.FullName
    $imgDst = Join-Path $OutDir $imgRel
    New-Item -ItemType Directory -Force -Path (Split-Path $imgDst) | Out-Null
    Copy-Item $_.FullName $imgDst -Force
    Write-Host "    → image $imgRel" -ForegroundColor DarkGray
  }
}

Write-Host "Done." -ForegroundColor Cyan
