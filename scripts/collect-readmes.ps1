<#
.SYNOPSIS
  Collect all README.md files from the repository and copy them into docs/ for MkDocs.

.DESCRIPTION
  - Recursively finds all README.md files
  - Renames them to index.md (so URLs look like /project/, not /project/README/)
  - Copies associated image files (png, jpg, jpeg, gif, svg) from the same directory
  - Preserves folder structure under docs/

.EXAMPLE
  PS> .\collect-readmes.ps1
#>

# 出力先ディレクトリ
$outDir = "docs"
Write-Host "Collecting README*.md into '$outDir'..." -ForegroundColor Cyan

# --- Gitリポジトリのルートを特定 ---
$gitRoot = (git rev-parse --show-toplevel) 2>$null
if (-not $gitRoot) { $gitRoot = (Get-Location).Path }  # git未使用なら現在地をルート扱い

# PowerShell 7 には GetRelativePath があるが、5.1 互換のため関数を用意
function Get-RelPath($base, $path) {
  $baseUri   = [Uri]((Resolve-Path $base).ProviderPath + [IO.Path]::DirectorySeparatorChar)
  $targetUri = [Uri]((Resolve-Path $path).ProviderPath)
  $rel = $baseUri.MakeRelativeUri($targetUri).ToString()
  # URI区切りをWindowsの区切りに
  return [Uri]::UnescapeDataString($rel).Replace('/','\')
}

# 安全：先頭の "..\" や ".\" を潰す
function Sanitize-Rel($rel) {
  $r = $rel -replace '^[.\\\/]+',''
  while ($r -like '..\*') { $r = $r.Substring(3) }  # 念のため防御
  return $r
}

# 対象: README*.md（README.md, README_ja.md など）
Get-ChildItem -Path $gitRoot -Recurse -File -Filter "README*.md" | ForEach-Object {
  $src = $_.FullName

  # ルートからの相対パス（.. を含まない形へ）
  $rel = Get-RelPath $gitRoot $src
  $rel = Sanitize-Rel $rel

  # 出力先の相対パス（README*.md → index.md）
  $relOut = ($rel -replace '(?i)README.*\.md$','index.md')
  $dst = Join-Path $outDir $relOut

  New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
  Copy-Item $src $dst -Force
  Write-Host "✓ $rel -> $dst" -ForegroundColor Green

  # 同階層の画像もコピー（必要に応じて拡張子を追加）
  $imgDir = Split-Path $src
  Get-ChildItem $imgDir -File -Include *.png,*.jpg,*.jpeg,*.gif,*.svg,*.webp,*.bmp,*.ico |
    ForEach-Object {
      $imgRel = Get-RelPath $gitRoot $_.FullName
      $imgRel = Sanitize-Rel $imgRel
      $imgDst = Join-Path $outDir $imgRel
      New-Item -ItemType Directory -Force -Path (Split-Path $imgDst) | Out-Null
      Copy-Item $_.FullName $imgDst -Force
      Write-Host "    → image $imgRel" -ForegroundColor DarkGray
    }
}


Write-Host "All READMEs collected under '$outDir' 🎉" -ForegroundColor Cyan
