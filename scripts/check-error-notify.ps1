# PostToolUse hook: Check if tool execution had a real error.
# Only notifies on clear failure signals, not benign "error" text in output.

param()

$logFile = "$PSScriptRoot/notify.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

try {
    $inputData = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $toolOutput = $inputData.tool_output
    $toolName = $inputData.tool_name

    # Only check Bash commands
    if ($toolName -ne "Bash") { exit 0 }

    # Safely get output preview
    $outputPreview = if ($toolOutput) {
        $toolOutput.Substring(0, [Math]::Min(200, $toolOutput.Length))
    } else {
        "(null)"
    }
    Add-Content -Path $logFile -Value "$timestamp | PostToolUse | Tool=$toolName | Output=$outputPreview"

    # Check for REAL error indicators only.
    # Avoid matching benign text like grep results or compiler info messages.
    $errorPatterns = @(
        'command not found',
        'Permission denied',
        'No such file or directory',
        'cannot access',
        'is not recognized as',
        'fatal:',
        'FATAL:',
        'CRITICAL:'
    )

    if ($toolOutput) {
        foreach ($pattern in $errorPatterns) {
            if ($toolOutput -match $pattern) {
                Add-Content -Path $logFile -Value "$timestamp | ERROR DETECTED in $toolName: $pattern"
                $preview = $toolOutput
                if ($preview.Length -gt 100) { $preview = $preview.Substring(0, 100) + "..." }
                & "$PSScriptRoot/notify.ps1" -Title "Claude Code" -Message "Error: $preview" -Scenario "error" 2>$null
                break
            }
        }
    }
} catch {
    Add-Content -Path $logFile -Value "$timestamp | PostToolUse EXCEPTION: $_"
    # Silently fail - don't break Claude Code execution
}
