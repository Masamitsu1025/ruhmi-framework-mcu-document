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

Write-Host "Collecting README.md files into '$outDir'..." -ForegroundColor Cyan

# README.md を探索
Get-ChildItem -Recurse -File -Filter "README.md" | ForEach-Object {
    $source = $_.FullName

    # 相対パスを作成
    $relPath = Resolve-Path -Relative $source

    # 出力先パス（README.md → index.md に変換）
    $dest = Join-Path $outDir ($relPath -replace '\\README\.md$', '\index.md' -replace '/', '\')
    
    # 出力先フォルダを作成
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null

    # README.md をコピー
    Copy-Item $source $dest -Force
    Write-Host "✓ Copied $relPath -> $dest" -ForegroundColor Green

    # 画像ファイルを同階層からコピー
    $imgDir = Split-Path $source
    Get-ChildItem $imgDir -File -Include *.png,*.jpg,*.jpeg,*.gif,*.svg | ForEach-Object {
        $imgRelPath = Resolve-Path -Relative $_.FullName
        $imgDest = Join-Path $outDir ($imgRelPath -replace '/', '\')
        New-Item -ItemType Directory -Force -Path (Split-Path $imgDest) | Out-Null
        Copy-Item $_.FullName $imgDest -Force
        Write-Host "    → Copied image $imgRelPath" -ForegroundColor DarkGray
    }
}

Write-Host "All READMEs collected under '$outDir' 🎉" -ForegroundColor Cyan
