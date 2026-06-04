# Check if a Bash command was executed and notify user
# This runs as PostToolUse hook to detect Bash commands after execution

param()

$logFile = "$PSScriptRoot/notify.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

try {
    # Read tool data from stdin
    $stdinData = [Console]::In.ReadToEnd()
    if (-not $stdinData) { exit 0 }

    $inputData = $stdinData | ConvertFrom-Json
    $toolName = $inputData.tool_name
    $command = $inputData.tool_input.command

    # Only process Bash commands
    if ($toolName -ne "Bash" -or -not $command) { exit 0 }

    Add-Content -Path $logFile -Value "$timestamp | Bash executed | Command=$command"

    # Commands that are potentially "dangerous" or noteworthy
    $noteworthyPatterns = @(
        "rm -rf",
        "rm -r\b",
        "rmdir",
        "del /",
        "format ",
        "mkfs",
        "dd if=",
        "git push",
        "git reset --hard",
        "git clean -f",
        "npm publish",
        "pip install",
        "cargo install",
        "curl.*\|.*sh",
        "wget.*\|.*sh",
        "chmod 777",
        "sudo ",
        "Remove-Item",
        "Format-",
        "Invoke-Expression"
    )

    # Check if command matches any noteworthy pattern
    $isNoteworthy = $false
    foreach ($pattern in $noteworthyPatterns) {
        if ($command -match $pattern) {
            $isNoteworthy = $true
            break
        }
    }

    if ($isNoteworthy) {
        Add-Content -Path $logFile -Value "$timestamp | NOTABLE: $command"
        & "$PSScriptRoot/notify.ps1" -Title "Claude Code" -Message "Executed: $command" -Scenario "default"
    }
} catch {
    Add-Content -Path $logFile -Value "$timestamp | EXCEPTION: $_"
}
