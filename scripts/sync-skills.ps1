# Sync skills and the global CLAUDE.md block from this repository (source of truth) to ~/.claude.
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\sync-skills.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\sync-skills.ps1 -DryRun
#
# Skills: only skill folders that exist under .\skills are replaced. Other skills in ~/.claude/skills are left untouched.
# CLAUDE.md: only the block between the dev-playbook markers in ~/.claude/CLAUDE.md is replaced. Other content is kept.

param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$claudeDir = Join-Path $env:USERPROFILE '.claude'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# ---- Skills ----
$source = Join-Path $repoRoot 'skills'
$dest = Join-Path $claudeDir 'skills'

if (-not (Test-Path $source)) {
    Write-Error "Source folder not found: $source"
}

if (-not (Test-Path $dest)) {
    if ($DryRun) {
        Write-Host "[dry-run] create $dest"
    } else {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
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

# ---- Global CLAUDE.md block ----
$blockSource = Join-Path $repoRoot 'global\CLAUDE.md'
$claudeMd = Join-Path $claudeDir 'CLAUDE.md'
$begin = '<!-- dev-playbook:begin (managed by dev-playbook/scripts/sync-skills.ps1; do not edit inside) -->'
$end = '<!-- dev-playbook:end -->'

if (Test-Path $blockSource) {
    $blockBody = [System.IO.File]::ReadAllText($blockSource, [System.Text.Encoding]::UTF8).TrimEnd()
    $block = $begin + "`r`n" + $blockBody + "`r`n" + $end

    $current = ''
    if (Test-Path $claudeMd) {
        $current = [System.IO.File]::ReadAllText($claudeMd, [System.Text.Encoding]::UTF8)
    }

    $pattern = '(?s)<!-- dev-playbook:begin.*?<!-- dev-playbook:end -->'
    if ([regex]::IsMatch($current, $pattern)) {
        $updated = [regex]::Replace($current, $pattern, { param($m) $block })
    } elseif ($current.Trim().Length -eq 0) {
        $updated = $block + "`r`n"
    } else {
        $updated = $current.TrimEnd() + "`r`n`r`n" + $block + "`r`n"
    }

    if ($DryRun) {
        Write-Host "[dry-run] update dev-playbook block in $claudeMd"
    } elseif ($updated -ne $current) {
        if (-not (Test-Path $claudeDir)) {
            New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($claudeMd, $updated, $utf8NoBom)
        Write-Host "updated dev-playbook block in $claudeMd"
    } else {
        Write-Host "CLAUDE.md block is up to date"
    }
}

Write-Host 'done. Changes to existing skill folders are picked up by running sessions; if a skill does not appear, run /reload-skills.'
