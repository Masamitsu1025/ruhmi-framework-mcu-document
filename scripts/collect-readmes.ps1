# docs/ は Actions 内で毎回生成（リポジトリにはコミットしない）
# 生成内容は ログに一覧表示（必要なら artifact でダウンロード可）
# その docs/ を元に MkDocs でビルド→gh-pages にデプロイ

[CmdletBinding()]
param(
  [string]$OutDir = "docs",                      # 出力先（MkDocs 既定）
  [switch]$Clean,                                # 出力先を掃除してから実行
  [string[]]$MdPatterns    = @("*.md"),          # 対象Markdown（既定: すべての .md）
  [string[]]$ImagePatterns = @("*.png","*.jpg","*.jpeg","*.gif","*.svg","*.webp","*.bmp","*.ico"),
  [switch]$IncludeRoot = $true                   # ルート直下のファイルも含める
)

$ErrorActionPreference = 'Stop'

# --- 便利関数 ---
function Get-Rel($base, $path) {
  $baseUri   = [Uri]((Resolve-Path $base).ProviderPath + [IO.Path]::DirectorySeparatorChar)
  $targetUri = [Uri]((Resolve-Path $path).ProviderPath)
  $rel = [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString())
  return $rel.Replace('/','\')  # Windows区切りに統一
}

# --- Git ルート（なければカレント） ---
$gitRoot = (git rev-parse --show-toplevel) 2>$null
if (-not $gitRoot) { $gitRoot = (Get-Location).Path }
$rootFull = (Resolve-Path $gitRoot).ProviderPath

# --- 出力初期化 ---
if ($Clean -and (Test-Path $OutDir)) {
  Write-Host "Cleaning '$OutDir'..." -ForegroundColor Yellow
  Remove-Item -Recurse -Force $OutDir
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$outFull = (Resolve-Path $OutDir).ProviderPath

# 除外トップ（自己コピー/不要走査防止）
$excludeTop = @([IO.Path]::GetFileName($OutDir), '.git', '.github', 'site', '.venv', 'venv', 'node_modules', 'dist', 'build')

Write-Host "Collecting from ROOT and ALL top-level folders -> '$OutDir' ..." -ForegroundColor Cyan

$copiedMd = 0
$copiedImg = 0

# --- 共通コピー関数 ---
function Copy-Files {
  param(
    [string]$basePath,
    [string[]]$patterns
  )
  foreach ($pattern in $patterns) {
    Get-ChildItem -Path $basePath -Recurse -File -Filter $pattern | ForEach-Object {
      $src = $_.FullName
      # 出力先配下のファイルはスキップ（自己コピー防止）
      if ($src.StartsWith($outFull, [System.StringComparison]::OrdinalIgnoreCase)) { return }

      $rel = Get-Rel $rootFull $src
      $top = ($rel -split '[\\/]')[0]
      if ($excludeTop -contains $top) { return }

      $dst = Join-Path $OutDir $rel
      New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
      Copy-Item $src $dst -Force
      return $dst
    }
  }
}

# 1) ルート直下の *.md / 画像
if ($IncludeRoot) {
  # 直下のみ（再帰なし）で拾いたいときは -Recurse を外すが、ここは再帰でOK
  foreach ($pattern in $MdPatterns) {
    foreach ($dst in (Copy-Files -basePath $rootFull -patterns @($pattern))) {
      if ($dst) { $copiedMd++ ; Write-Host "✓ MD   $(Get-Rel $OutDir $dst)" -ForegroundColor Green }
    }
  }
  foreach ($pattern in $ImagePatterns) {
    foreach ($dst in (Copy-Files -basePath $rootFull -patterns @($pattern))) {
      if ($dst) { $copiedImg++; Write-Host "✓ IMG  $(Get-Rel $OutDir $dst)" -ForegroundColor DarkGray }
    }
  }
}

# 2) ルート直下の全フォルダ配下
$topFolders = Get-ChildItem -Path $rootFull -Directory | Where-Object { $_.Name -notin $excludeTop }
foreach ($folder in $topFolders) {
  Write-Host "Processing $($folder.Name) ..." -ForegroundColor Yellow

  foreach ($pattern in $MdPatterns) {
    foreach ($dst in (Copy-Files -basePath $folder.FullName -patterns @($pattern))) {
      if ($dst) { $copiedMd++ ; Write-Host "✓ MD   $(Get-Rel $OutDir $dst)" -ForegroundColor Green }
    }
  }
  foreach ($pattern in $ImagePatterns) {
    foreach ($dst in (Copy-Files -basePath $folder.FullName -patterns @($pattern))) {
      if ($dst) { $copiedImg++; Write-Host "✓ IMG  $(Get-Rel $OutDir $dst)" -ForegroundColor DarkGray }
    }
  }
}

Write-Host "Done. Copied: MD=$copiedMd, IMG=$copiedImg" -ForegroundColor Cyan
