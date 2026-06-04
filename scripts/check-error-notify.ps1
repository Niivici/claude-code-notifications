# Check if tool execution had an error
# Claude Code sets TOOL_OUTPUT environment variable with the result

param()

# Read tool output from environment or stdin
$toolOutput = $env:TOOL_OUTPUT

# Check for error indicators
if ($toolOutput -match "error|Error|ERROR|failed|Failed|FAILED|exception|Exception") {
    # Send error notification
    & "$PSScriptRoot/notify.ps1" -Title "Claude Code" -Message "Error occurred" -Scenario "error"
}
