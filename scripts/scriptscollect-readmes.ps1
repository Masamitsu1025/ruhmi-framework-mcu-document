<# 
  collect-readmes.ps1
  - リポジトリ内の README*.md を探索し、ファイル名を変えずに docs/ 配下へコピー
  - 各 README と同じフォルダの画像も docs/ 配下へ相対パスを維持してコピー
  - -Clean を付けると docs/ を削除してから再生成
  - docs/ 自身や .git, node_modules 等は探索から除外（自己コピー/重量化の防止）
#>

[CmdletBinding()]
param(
  [string]$OutDir = "docs",
  [switch]$Clean,
  [string[]]$ReadmePatterns = @("README*.md"),
  [string[]]$ImagePatterns  = @("*.png","*.jpg","*.jpeg","*.gif","*.svg","*.webp","*.bmp","*.ico")
)

$ErrorActionPreference = 'Stop'

# --- Git ルートを特定（なければカレント） ---
$gitRoot = (git rev-parse --show-toplevel) 2>$null
if (-not $gitRoot) { $gitRoot = (Get-Location).Path }

# 相対パス作成（.. を含まない安定版）
function Get-Rel($base, $path) {
  $baseUri   = [Uri]((Resolve-Path $base).ProviderPath + [IO.Path]::DirectorySeparatorChar)
  $targetUri = [Uri]((Resolve-Path $path).ProviderPath)
  $rel = [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString())
  return $rel.Replace('/','\')
}

# 除外トップレベル（自己コピー防止 & 高速化）
$excludeTop = @(
  [IO.Path]::GetFileName($OutDir), '.git', '.github', 'site',
  '.venv', 'venv', 'node_modules', '.tox', '.pytest_cache', 'dist', 'build'
)

# 出力初期化
if ($Clean -and (Test-Path $OutDir)) {
  Write-Host "Cleaning '$OutDir'..." -ForegroundColor Yellow
  Remove-Item -Recurse -Force $OutDir
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "Collecting READMEs into '$OutDir'..." -ForegroundColor Cyan

$gitRootFull = (Resolve-Path $gitRoot).ProviderPath
$outDirFull  = (Resolve-Path $OutDir).ProviderPath

$copiedReadmes = 0
$copiedImages  = 0

# --- README*.md を探索してコピー（Filter で高速化） ---
foreach ($pattern in $ReadmePatterns) {
  Get-ChildItem -Path $gitRoot -Recurse -File -Filter $pattern | ForEach-Object {
    $src = $_.FullName

    # docs/ 配下や除外トップ直下はスキップ（自己コピー/不要コピー防止）
    $relFromRoot = Get-Rel $gitRoot $src
    $top = ($relFromRoot -split '[\\/]')[0]
    if ($excludeTop -contains $top) { return }
    if ($src.StartsWith($outDirFull, [System.StringComparison]::OrdinalIgnoreCase)) { return }

    # 出力先へ（ファイル名はそのまま、リネームしない）
    $dst = Join-Path $OutDir $relFromRoot
    New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
    Copy-Item $src $dst -Force
    $copiedReadmes++
    Write-Host "✓ $relFromRoot -> $dst" -ForegroundColor Green

    # 同階層の画像もコピー
    $imgDir = Split-Path $src -Parent
    if (Test-Path $imgDir) {
      Get-ChildItem $imgDir -File -Include $ImagePatterns | ForEach-Object {
        $imgRel = Get-Rel $gitRoot $_.FullName
        $imgTop = ($imgRel -split '[\\/]')[0]
        if ($excludeTop -contains $imgTop) { return }

        $imgDst = Join-Path $OutDir $imgRel
        New-Item -ItemType Directory -Force -Path (Split-Path $imgDst -Parent) | Out-Null
        Copy-Item $_.FullName $imgDst -Force
        $copiedImages++
        Write-Host "    → image $imgRel" -ForegroundColor DarkGray
      }
    }
  }
}

Write-Host "Done. READMEs: $copiedReadmes, images: $copiedImages" -ForegroundColor Cyan
