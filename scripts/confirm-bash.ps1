# PreToolUse hook: Auto-approve safe Bash commands, prompt for others
# Outputs JSON decision to stdout to control Claude Code behavior

param()

try {
    # Read tool input from stdin
    $stdinData = [Console]::In.ReadToEnd()
    if (-not $stdinData) { exit 0 }

    $inputData = $stdinData | ConvertFrom-Json
    $toolName = $inputData.tool_name
    $command = $inputData.tool_input.command

    # Only process Bash commands with actual command content
    if ($toolName -ne "Bash" -or -not $command) { exit 0 }

    # Safe command patterns (read-only, no side effects)
    $safePatterns = @(
        '^ls\b',
        '^dir\b',
        '^cat\b',
        '^head\b',
        '^tail\b',
        '^grep\b',
        '^find\b',
        '^echo\b',
        '^pwd$',
        '^date$',
        '^which\b',
        '^where\b',
        '^whoami$',
        '^git\s+status',
        '^git\s+diff',
        '^git\s+log',
        '^git\s+branch',
        '^npm\s+list',
        '^pip\s+list',
        '^pip\s+show',
        '^claude\s+--version',
        '^claude\s+config'
    )

    # Check if command matches safe patterns
    foreach ($pattern in $safePatterns) {
        if ($command -match $pattern) {
            # Safe command - auto-approve silently
            Write-Output '{"decision":"approve","permissionDecision":"allow"}'
            exit 0
        }
    }

    # Non-safe command - send notification and request confirmation
    & "$PSScriptRoot/notify.ps1" -Title "Claude Code" -Message "Confirm: $command" -Scenario "confirm" 2>$null

    # Output permission prompt decision
    $reason = "Please confirm: $command"
    if ($reason.Length -gt 100) {
        $reason = $reason.Substring(0, 100) + "..."
    }
    $escapedReason = $reason -replace '"', '\"' -replace '\\', '\\\\'
    Write-Output "{`"decision`":`"approve`",`"permissionDecision`":`"ask`",`"permissionDecisionReason`":`"$escapedReason`"}"
} catch {
    # On error, allow the command (don't block Claude Code)
    Write-Output '{"decision":"approve","permissionDecision":"allow"}'
}
