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

Write-Host "Collecting README*.md files into '$outDir'..." -ForegroundColor Cyan

# ルートディレクトリを取得（スクリプト実行時のカレント）
$root = Get-Location

# README*.md を探索
Get-ChildItem -Recurse -File -Filter "README*.md" | ForEach-Object {
    $source = $_.FullName

    # ルートからの相対パスを計算
    $relPath = Resolve-Path -Relative -Path $source -RelativeBase $root

    # 出力先のパスを組み立て（README*.md → index.md）
    $relFixed = $relPath -replace 'README.*\.md$', 'index.md'
    $dest = Join-Path $outDir $relFixed

    # 出力先フォルダを作成
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null

    # README*.md をコピー
    Copy-Item $source $dest -Force
    Write-Host "✓ Copied $relPath -> $dest" -ForegroundColor Green

    # 同じフォルダ内の画像もコピー
    $imgDir = Split-Path $source
    Get-ChildItem $imgDir -File -Include *.png,*.jpg,*.jpeg,*.gif,*.svg | ForEach-Object {
        $imgPath = $_.FullName
        $imgRelPath = Resolve-Path -Relative -Path $imgPath -RelativeBase $root
        $imgDest = Join-Path $outDir $imgRelPath
        New-Item -ItemType Directory -Force -Path (Split-Path $imgDest) | Out-Null
        Copy-Item $imgPath $imgDest -Force
        Write-Host "    → Copied image $imgRelPath" -ForegroundColor DarkGray
    }
}

Write-Host "All READMEs collected under '$outDir' 🎉" -ForegroundColor Cyan
