
# Publish-UI-Screenshots.ps1
# Commit and push UI screenshots only.

$ErrorActionPreference = "Stop"

$repo = "E:\Programming\Tool\pa-development"
$branch = "review/pa-development"
$remote = "origin"

Set-Location $repo

# 1. Verify Git repository and branch.
$currentBranch = (git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $branch) {
    throw "Wrong branch. Expected: $branch"
}

# 2. Verify screenshot folder.
if (-not (Test-Path "screenshot" -PathType Container)) {
    throw "Screenshot folder not found."
}

# 3. Stage only screenshots.
git add -A -- screenshot/
if ($LASTEXITCODE -ne 0) {
    throw "Failed to stage screenshots."
}

# 4. Check staged changes.
$changes = @(git diff --cached --name-only -- screenshot/)
if ($LASTEXITCODE -ne 0) {
    throw "Failed to inspect staged changes."
}

if ($changes.Count -eq 0) {
    Write-Host "No screenshot changes to publish."
    exit 0
}

# 5. Refuse to include unrelated staged changes.
$otherStaged = @(git diff --cached --name-only -- . ":(exclude)screenshot/**")
if ($LASTEXITCODE -ne 0) {
    throw "Failed to inspect other staged changes."
}

if ($otherStaged.Count -gt 0) {
    throw "Other files are staged. Unstage them before publishing screenshots."
}

Write-Host "Screenshot changes:"
$changes | ForEach-Object { Write-Host "  $_" }

# 6. Commit.
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
git commit -m "docs(ui): update screenshots ($stamp)"
if ($LASTEXITCODE -ne 0) {
    throw "Commit failed."
}

# 7. Push the expected branch.
git push $remote "HEAD:refs/heads/$branch"
if ($LASTEXITCODE -ne 0) {
    throw "Push failed. Local commit remains available."
}

Write-Host ""
Write-Host "UI screenshots published successfully."
Write-Host "Branch: $branch"
Write-Host "Commit: $(git rev-parse --short HEAD)"
