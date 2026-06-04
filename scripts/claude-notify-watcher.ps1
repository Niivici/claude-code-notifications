# claude-notify-watcher.ps1
# Background watcher: monitors Claude Code transcript for permission denials.
# Run this alongside Claude Code (e.g., in a separate terminal or as a scheduled task).
#
# Usage:
#   .\claude-notify-watcher.ps1                    # Watch all sessions
#   .\claude-notify-watcher.ps1 -SessionId "xxx"   # Watch specific session
#
# How it works:
#   Monitors the latest Claude Code transcript file for "permission_denials" entries.
#   When a permission denial is detected (meaning Claude needs user confirmation),
#   sends a Windows notification.

param(
    [string]$SessionId = "",
    [int]$PollIntervalMs = 2000
)

$notifyScript = Join-Path $PSScriptRoot "notify.ps1"
$transcriptDir = "$env:USERPROFILE\.claude\projects"

# Find the latest transcript file
function Get-LatestTranscript {
    param([string]$sid)

    if ($sid) {
        # Look for specific session
        $files = Get-ChildItem -Path $transcriptDir -Filter "$sid.jsonl" -Recurse -ErrorAction SilentlyContinue
    } else {
        # Find the most recently modified transcript
        $files = Get-ChildItem -Path $transcriptDir -Filter "*.jsonl" -Recurse -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    return $files | Select-Object -First 1
}

# Main watcher loop
$lastSize = 0
$lastDenialCount = 0
$currentFile = $null

Write-Host "Claude Code notification watcher started." -ForegroundColor Green
Write-Host "Monitoring transcript directory: $transcriptDir" -ForegroundColor Gray
Write-Host "Poll interval: ${PollIntervalMs}ms" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop." -ForegroundColor Gray
Write-Host ""

while ($true) {
    try {
        # Get latest transcript file
        $file = Get-LatestTranscript -sid $SessionId

        if (-not $file) {
            Start-Sleep -Milliseconds $PollIntervalMs
            continue
        }

        # Switch to new file if session changed
        if ($currentFile -ne $file.FullName) {
            $currentFile = $file.FullName
            $lastSize = 0
            $lastDenialCount = 0
            Write-Host "Watching: $currentFile" -ForegroundColor Cyan
        }

        $currentSize = $file.Length
        if ($currentSize -eq $lastSize) {
            Start-Sleep -Milliseconds $PollIntervalMs
            continue
        }

        # Read new content since last check
        $stream = [System.IO.StreamReader]::new($file.FullName, [System.Text.Encoding]::UTF8)
        $stream.BaseStream.Seek($lastSize, [System.IO.SeekOrigin]::Begin) | Out-Null

        while ($null -ne ($line = $stream.ReadLine())) {
            try {
                $entry = $line | ConvertFrom-Json

                # Check for permission_denials in result entries
                if ($entry.type -eq "result" -and $entry.permission_denials) {
                    $denials = $entry.permission_denials
                    $denialCount = $denials.Count

                    if ($denialCount -gt $lastDenialCount) {
                        # New permission denials detected
                        $newDenials = $denials | Select-Object -Skip $lastDenialCount
                        foreach ($denial in $newDenials) {
                            $toolName = $denial.tool_name
                            $command = $denial.tool_input.command
                            $preview = if ($command) {
                                if ($command.Length -gt 80) { $command.Substring(0, 80) + "..." } else { $command }
                            } else { $toolName }

                            Write-Host "[NOTIFICATION] Permission needed: $preview" -ForegroundColor Yellow
                            & $notifyScript -Title "Claude Code" -Message "Confirm: $preview" -Scenario "confirm" 2>$null
                        }
                        $lastDenialCount = $denialCount
                    }
                }

                # Reset on new session
                if ($entry.type -eq "result" -and $entry.terminal_reason) {
                    $lastDenialCount = 0
                }
            } catch {
                # Skip malformed JSON lines
            }
        }

        $stream.Close()
        $lastSize = $currentSize
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }

    Start-Sleep -Milliseconds $PollIntervalMs
}
