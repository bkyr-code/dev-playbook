# SessionStart hook: name the Claude Code session after the GitHub Issue of the current branch.
# Title format: "#<issue number> <summary>"
#   1. git config branch.<branch>.sessionTitle  (set by the /issue skill)
#   2. otherwise "#<n> " + Issue title from gh (bracket tags removed, max 20 chars)
#   3. otherwise "#<n> " + rest of the branch name
# Does nothing on the default branch or on branches that do not start with "<number>-".
# Output is ASCII-only JSON (non-ASCII escaped as \uXXXX) to avoid console encoding problems on Windows.

$ErrorActionPreference = 'SilentlyContinue'
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Out-Nothing { exit 0 }

function ConvertTo-AsciiJsonString([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        $code = [int]$ch
        if ($ch -eq '"') { [void]$sb.Append('\"') }
        elseif ($ch -eq '\') { [void]$sb.Append('\\') }
        elseif ($code -lt 0x20 -or $code -gt 0x7e) { [void]$sb.Append(('\u{0:x4}' -f $code)) }
        else { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

$raw = [Console]::In.ReadToEnd()
$cwd = $null
try { $cwd = ($raw | ConvertFrom-Json).cwd } catch {}
if (-not $cwd) { $cwd = (Get-Location).Path }

$branch = (& git -C $cwd branch --show-current 2>$null)
if (-not $branch) { Out-Nothing }
$branch = $branch.Trim()
if ($branch -notmatch '^(\d+)-(.+)$') { Out-Nothing }
$num = $Matches[1]
$rest = $Matches[2]

$title = (& git -C $cwd config --get "branch.$branch.sessionTitle" 2>$null)
if ($title) { $title = $title.Trim() }

if (-not $title) {
    $issueTitle = $null
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Push-Location $cwd
        $issueTitle = (& gh issue view $num --json title --jq .title 2>$null)
        Pop-Location
    }
    if ($issueTitle) {
        $summary = ($issueTitle.Trim() -replace '^\s*(\[[^\]]*\]\s*)+', '')
    } else {
        $summary = $rest
    }
    if ($summary.Length -gt 20) { $summary = $summary.Substring(0, 20) }
    $title = "#$num $summary"
}

$json = '{"hookSpecificOutput":{"hookEventName":"SessionStart","sessionTitle":"' + (ConvertTo-AsciiJsonString $title) + '"}}'
[Console]::Out.Write($json)
exit 0
