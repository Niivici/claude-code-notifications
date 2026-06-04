# Check if tool execution had an error
# Claude Code passes data via stdin JSON

param()

$logFile = "$PSScriptRoot/notify.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

try {
    # Read tool output from stdin (Claude Code's hook system)
    $inputData = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $toolOutput = $inputData.tool_output
    $toolName = $inputData.tool_name

    # Safely get output preview
    $outputPreview = if ($toolOutput) {
        $toolOutput.Substring(0, [Math]::Min(200, $toolOutput.Length))
    } else {
        "(null)"
    }
    Add-Content -Path $logFile -Value "$timestamp | PostToolUse | Tool=$toolName | Output=$outputPreview"

    # Check for error indicators (more precise matching)
    if ($toolOutput -match "^error:|failed:|exception:|FATAL|CRITICAL") {
        Add-Content -Path $logFile -Value "$timestamp | ERROR DETECTED in $toolName"
        # Send error notification
        & "$PSScriptRoot/notify.ps1" -Title "Claude Code" -Message "Error in $toolName" -Scenario "error"
    }
} catch {
    Add-Content -Path $logFile -Value "$timestamp | PostToolUse EXCEPTION: $_"
    # Silently fail - don't break Claude Code execution
}
