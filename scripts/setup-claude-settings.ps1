# Add dev-playbook settings to ~/.claude/settings.json (run once; safe to run again).
#   - permissions.ask : git push / gh pr merge / gh api / gh repo edit always ask for confirmation
#   - hooks.SessionStart : name the session "#<issue> <summary>" (hooks/session-title.ps1)
# Existing settings are kept. A backup (settings.json.bak) is written before changing the file.
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\setup-claude-settings.ps1

$ErrorActionPreference = 'Stop'

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$settingsPath = Join-Path $claudeDir 'settings.json'
$hookScript = (Join-Path $claudeDir 'hooks\dev-playbook\session-title.ps1') -replace '\\', '/'
$hookCommand = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $hookScript + '"'
$askRules = @('Bash(git push *)', 'Bash(gh pr merge *)', 'Bash(gh api *)', 'Bash(gh repo edit *)')

function Set-Prop($obj, [string]$name, $value) {
    if ($obj.PSObject.Properties[$name]) { $obj.$name = $value }
    else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

# Load (or start empty)
$original = ''
if (Test-Path $settingsPath) {
    $original = [System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8)
}
if ($original.Trim().Length -gt 0) {
    try { $settings = $original | ConvertFrom-Json }
    catch { Write-Error "settings.json is not valid JSON. Fix it first: $settingsPath" }
} else {
    $settings = New-Object PSObject
}

# permissions.ask
if (-not $settings.PSObject.Properties['permissions']) { Set-Prop $settings 'permissions' (New-Object PSObject) }
$ask = New-Object System.Collections.ArrayList
if ($settings.permissions.PSObject.Properties['ask']) {
    foreach ($r in @($settings.permissions.ask)) { [void]$ask.Add($r) }
}
$addedRules = 0
foreach ($r in $askRules) {
    if (-not $ask.Contains($r)) { [void]$ask.Add($r); $addedRules++ }
}
Set-Prop $settings.permissions 'ask' $ask.ToArray()

# hooks.SessionStart
if (-not $settings.PSObject.Properties['hooks']) { Set-Prop $settings 'hooks' (New-Object PSObject) }
$groups = New-Object System.Collections.ArrayList
if ($settings.hooks.PSObject.Properties['SessionStart']) {
    foreach ($g in @($settings.hooks.SessionStart)) { [void]$groups.Add($g) }
}
$hookExists = $false
foreach ($g in $groups) {
    foreach ($h in @($g.hooks)) {
        if ($h.command -and $h.command -like '*session-title.ps1*') { $hookExists = $true }
    }
}
if (-not $hookExists) {
    $hook = New-Object PSObject -Property ([ordered]@{ type = 'command'; command = $hookCommand })
    $group = New-Object PSObject
    $group | Add-Member -NotePropertyName 'hooks' -NotePropertyValue @($hook)
    [void]$groups.Add($group)
}
Set-Prop $settings.hooks 'SessionStart' $groups.ToArray()

if ($addedRules -eq 0 -and $hookExists) {
    Write-Host 'Already set up. No changes.'
    exit 0
}

# Save (backup first)
if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }
if ($original.Length -gt 0) {
    [System.IO.File]::WriteAllText($settingsPath + '.bak', $original, (New-Object System.Text.UTF8Encoding($false)))
}
$json = $settings | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "updated $settingsPath (ask rules added: $addedRules, session-title hook added: $(-not $hookExists))"
if ($original.Length -gt 0) { Write-Host "backup: $settingsPath.bak" }
Write-Host 'Restart Claude Code sessions to apply.'
