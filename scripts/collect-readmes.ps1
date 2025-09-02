<# 
  collect-readmes.ps1
  - README*.md を docs/ 配下へ収集して index.md にリネーム
  - 同階層の画像もコピー（相対リンク維持）
  - コンテンツ内の "README*.md" へのリンクを "index.md" に置換（Markdown/HTML両対応）
  - 既存 docs/ を消してから再生成したい時は -Clean を付ける

  使い方例:
    pwsh ./collect-readmes.ps1              # 差分コピー
    pwsh ./collect-readmes.ps1 -Clean       # docs/ を掃除してから再生成
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

# 相対パス作成（..\ を含まないよう統一）
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

# 対象: README*.md（README.md, README_ja.md など大文字小文字不問）
Get-ChildItem -Path $gitRoot -Recurse -File -Include README*.md | ForEach-Object {
  $src = $_.FullName
  $rel = Get-Rel $gitRoot $src

  # 出力先パス（README*.md → index.md）
  $relOut = ($rel -replace '(?i)README.*\.md$','index.md')
  $dst = Join-Path $OutDir $relOut
  $dstDir = Split-Path $dst -Parent
  New-Item -ItemType Directory -Force -Path $dstDir | Out-Null

  # --- 本文を読み込み、リンク置換して書き出し ---
  # 置換対象例：
  #   [text](README.md) / [text](./README_en.md) / href="README_ja.md"
  $content = Get-Content -Raw -Path $src

  # Markdownリンク [..](..README*.md..)
  $content = [regex]::Replace(
    $content,
    '(?xi)
      (\]\()            # group1: リンク開始 "]("
      (\.?\/)?          # group2: 先頭の "./" or ".\" (任意)
      (README[\w\.\-]*\.md) # group3: README*.md
      (?=(\)|\#|\?))    # 後読み: 直後に ) or # or ? が続く
    ',
    '${1}index.md'
  )

  # HTMLリンク <a href="README*.md">, <a href='./README_xx.md'>
  $content = [regex]::Replace(
    $content,
    '(?xi)
      (href=              # group1
        ["'']             # 開始クオート
      )
      (\.?\/)?            # group2: 先頭の ./ など
      (README[\w\.\-]*\.md) # group3
      (["''])             # group4: 終了クオート
    ',
    '${1}index.md$4'
  )

  # 書き出し（UTF-8）
  Set-Content -Path $dst -Value $content -Encoding UTF8 -NoNewline

  Write-Host ("✓ {0} -> {1}" -f $rel, $dst) -ForegroundColor Green

  # --- 同階層の画像をコピー（相対参照用） ---
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

