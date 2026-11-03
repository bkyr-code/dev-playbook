# Sync skills from this repository (source of truth) to the Claude Code user skills folder.
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\sync-skills.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\sync-skills.ps1 -DryRun
#
# Only skill folders that exist under .\skills are replaced. Other skills in ~/.claude/skills are left untouched.

param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$source = Join-Path (Split-Path -Parent $PSScriptRoot) 'skills'
$dest = Join-Path $env:USERPROFILE '.claude\skills'

if (-not (Test-Path $source)) {
    Write-Error "Source folder not found: $source"
}

if (-not (Test-Path $dest)) {
    if ($DryRun) {
        Write-Host "[dry-run] create $dest"
    } else {
        New-Item -ItemType Directory -Path $dest | Out-Null
    }
}

Get-ChildItem -Path $source -Directory | ForEach-Object {
    $name = $_.Name
    $target = Join-Path $dest $name

    if (-not (Test-Path (Join-Path $_.FullName 'SKILL.md'))) {
        Write-Warning "skip $name (no SKILL.md)"
        return
    }

    if ($DryRun) {
        Write-Host "[dry-run] sync $name -> $target"
        return
    }

    if (Test-Path $target) {
        Remove-Item -Path $target -Recurse -Force
    }
    Copy-Item -Path $_.FullName -Destination $target -Recurse
    Write-Host "synced $name -> $target"
}

Write-Host 'done. If a running Claude Code session does not see the changes, restart it.'
