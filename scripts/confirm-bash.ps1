# PreToolUse hook: Auto-approve safe commands, notify + prompt for others.
#
# Architecture:
#   permissions.allow (settings.local.json) = first filter
#     Commands listed there never reach this hook.
#
#   This script = second filter (safe patterns)
#     Commands matching safe patterns are silently approved.
#     All other commands get notification + confirmation prompt.
#
# To reduce false positives: add commands to $safePatterns below.
# To reduce notifications entirely: add commands to permissions.allow instead.

param()

$logFile = "$PSScriptRoot/confirm-bash.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

try {
    $stdinData = [Console]::In.ReadToEnd()
    if (-not $stdinData) { exit 0 }

    $inputData = $stdinData | ConvertFrom-Json
    $toolName = $inputData.tool_name
    $command = $inputData.tool_input.command

    if ($toolName -ne "Bash" -or -not $command) { exit 0 }

    # Safe command patterns - silently approved, no notification.
    # These are read-only or low-risk commands.
    # Add patterns here to reduce false positives.
    $safePatterns = @(
        '^ls\b', '^dir\b', '^cat\b', '^head\b', '^tail\b',
        '^grep\b', '^find\b', '^echo\b', '^pwd$', '^date$',
        '^which\b', '^where\b', '^whoami$',
        '^git\s+status', '^git\s+diff', '^git\s+log', '^git\s+branch',
        '^git\s+remote', '^git\s+show', '^git\s+stash\s+list',
        '^npm\s+list', '^npm\s+ls', '^npm\s+info', '^npm\s+view',
        '^pip\s+list', '^pip\s+show', '^pip\s+freeze',
        '^node\s+--version', '^npm\s+--version', '^python\s+--version',
        '^claude\s+--version', '^claude\s+config',
        '^Get-Content', '^Get-ChildItem', '^Test-Path',
        '^Select-String', '^Measure-Object'
    )

    foreach ($pattern in $safePatterns) {
        if ($command -match $pattern) {
            Add-Content -Path $logFile -Value "$timestamp | SAFE-APPROVE | $command"
            Write-Output '{"decision":"approve","permissionDecision":"allow"}'
            exit 0
        }
    }

    # Non-safe command - send notification and request confirmation
    $preview = $command
    if ($preview.Length -gt 100) { $preview = $preview.Substring(0, 100) + "..." }

    Add-Content -Path $logFile -Value "$timestamp | NOTIFY+ASK | $command"

    & "$PSScriptRoot/notify.ps1" -Title "Claude Code" -Message "Confirm: $preview" -Scenario "confirm" 2>$null

    $escapedPreview = $preview -replace '"', '\"' -replace '\\', '\\\\'
    Write-Output "{`"decision`":`"approve`",`"permissionDecision`":`"ask`",`"permissionDecisionReason`":`"Confirm: $escapedPreview`"}"
} catch {
    Add-Content -Path $logFile -Value "$timestamp | ERROR | $_"
    Write-Output '{"decision":"approve","permissionDecision":"allow"}'
}
