# 一键发布：提交 -> 推送 -> 等 Actions -> 下载未签名 ipa 到 dist/
# 依赖：PAT 存放在 %TEMP%\leafreader-gh\pat.txt（scope: repo + workflow）
param(
    [string]$Message = "chore: 更新",
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$patFile = Join-Path $env:TEMP 'leafreader-gh\pat.txt'
if (-not (Test-Path $patFile)) {
    throw "找不到 PAT：$patFile。请创建 token 后写入该文件（内容只放 token 本身）。"
}
$pat = (Get-Content $patFile -Raw).Trim()
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("mmliusu:$pat"))
$owner = 'mmliusu'; $repo = 'leafreader'
$api = "https://api.github.com/repos/$owner/$repo"
$headers = @{ Authorization = "token $pat"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'leafreader-release' }

Write-Host "==> 提交变更" -ForegroundColor Cyan
git -C $root add -A
git -C $root diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    $msgFile = Join-Path $env:TEMP 'leafreader-commit-msg.txt'
    [IO.File]::WriteAllText($msgFile, $Message, [System.Text.UTF8Encoding]::new($false))
    git -C $root commit -F $msgFile
} else {
    Write-Host "（没有新的变更）"
}

Write-Host "==> 推送" -ForegroundColor Cyan
git -C $root -c "http.https://ghproxy.net/.extraheader=Authorization: Basic $auth" push origin main
if ($LASTEXITCODE -ne 0) { throw "推送失败" }

if ($NoBuild) { return }

Write-Host "==> 等待 GitHub Actions" -ForegroundColor Cyan
$deadline = (Get-Date).AddMinutes(20)
$run = $null
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 8
    $runs = Invoke-RestMethod -Uri "$api/actions/runs?per_page=1" -Headers $headers
    $candidate = $runs.workflow_runs | Select-Object -First 1
    if (-not $candidate) { continue }
    if ($candidate.status -eq 'completed') { $run = $candidate; break }
    Write-Host ("    状态: {0}" -f $candidate.status)
}
if (-not $run) { throw "等待超时" }

if ($run.conclusion -ne 'success') {
    throw "构建失败（$($run.conclusion)）：$($run.html_url)"
}
Write-Host "==> 构建成功 #$($run.run_number)" -ForegroundColor Green

Write-Host "==> 下载 ipa" -ForegroundColor Cyan
$arts = Invoke-RestMethod -Uri "$api/actions/runs/$($run.id)/artifacts" -Headers $headers
$ipa = $arts.artifacts | Where-Object { $_.name -eq 'LeafReader-unsigned-ipa' }
if (-not $ipa) { throw "没有找到 ipa artifact" }

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zipPath = Join-Path $dist 'LeafReader-unsigned-ipa.zip'
Invoke-WebRequest -Uri $ipa.archive_download_url -Headers $headers -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath (Join-Path $dist 'unpacked') -Force
Write-Host "ipa: $(Join-Path $dist 'unpacked\LeafReader-unsigned.ipa')" -ForegroundColor Green