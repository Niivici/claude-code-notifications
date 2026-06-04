# PreToolUse hook: Auto-approve safe commands silently.
# Non-safe commands pass through to Claude Code's native permission system,
# which decides whether to prompt the user. The transcript watcher
# (claude-notify-watcher.ps1) detects when Claude Code actually waits
# for confirmation and sends notifications — zero false positives.

param()

try {
    $stdinData = [Console]::In.ReadToEnd()
    if (-not $stdinData) { exit 0 }

    $inputData = $stdinData | ConvertFrom-Json
    $toolName = $inputData.tool_name
    $command = $inputData.tool_input.command

    if ($toolName -ne "Bash" -or -not $command) { exit 0 }

    # Safe command patterns - silently approved, no notification.
    # These are read-only or low-risk commands that never need user confirmation.
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
            Write-Output '{"decision":"approve","permissionDecision":"allow"}'
            exit 0
        }
    }

    # Non-safe command: let Claude Code's native permission system decide.
    # Do NOT send notification here — the transcript watcher handles that,
    # only when Claude Code actually requires user confirmation.

} catch {
    # On error, let Claude Code handle it
}
