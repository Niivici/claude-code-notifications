# claude-notify-watcher.ps1
# Background watcher: monitors Claude Code transcript for permission requests.
#
# Detects TWO types of signals (belt-and-suspenders):
#
#   Signal 1 (NATIVE - Claude Code's own permission system):
#     tool_result with "requires approval" in content
#     → This is Claude Code saying "I need user permission for this command"
#     → Written when the permission gate blocks a command
#     → Latency: ~2 seconds (poll interval)
#
#   Signal 2 (HOOK - PreToolUse hook output):
#     hook_response with permissionDecision:"ask"
#     → This is the hook requesting confirmation
#     → Written when the hook fires
#     → Latency: ~2 seconds (poll interval)
#
# Usage:
#   .\claude-notify-watcher.ps1                    # Watch latest session
#   .\claude-notify-watcher.ps1 -SessionId "xxx"   # Watch specific session

param(
    [string]$SessionId = "",
    [int]$PollIntervalMs = 2000
)

$notifyScript = Join-Path $PSScriptRoot "notify.ps1"
$transcriptDir = "$env:USERPROFILE\.claude\projects"

function Get-LatestTranscript {
    param([string]$sid)
    if ($sid) {
        $files = Get-ChildItem -Path $transcriptDir -Filter "$sid.jsonl" -Recurse -ErrorAction SilentlyContinue
    } else {
        $files = Get-ChildItem -Path $transcriptDir -Filter "*.jsonl" -Recurse -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    return $files | Select-Object -First 1
}

$lastSize = 0
$currentFile = $null
$notifiedCommands = @{}

Write-Host "Claude Code notification watcher started." -ForegroundColor Green
Write-Host "Monitoring: $transcriptDir" -ForegroundColor Gray
Write-Host "Poll interval: ${PollIntervalMs}ms" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop." -ForegroundColor Gray
Write-Host ""

while ($true) {
    try {
        $file = Get-LatestTranscript -sid $SessionId

        if (-not $file) {
            Start-Sleep -Milliseconds $PollIntervalMs
            continue
        }

        if ($currentFile -ne $file.FullName) {
            $currentFile = $file.FullName
            $lastSize = 0
            $notifiedCommands = @{}
            Write-Host "Watching: $currentFile" -ForegroundColor Cyan
        }

        $currentSize = $file.Length
        if ($currentSize -eq $lastSize) {
            Start-Sleep -Milliseconds $PollIntervalMs
            continue
        }

        # Read new content
        $stream = [System.IO.StreamReader]::new($file.FullName, [System.Text.Encoding]::UTF8)
        $stream.BaseStream.Seek($lastSize, [System.IO.SeekOrigin]::Begin) | Out-Null

        while ($null -ne ($line = $stream.ReadLine())) {
            try {
                $entry = $line | ConvertFrom-Json

                # === Signal 1: Native permission denial (Claude Code's own system) ===
                # When Claude Code blocks a command due to permission, the tool_result
                # contains "requires approval" and is_error:true
                if ($entry.type -eq "user" -and $entry.message -and $entry.message.content) {
                    foreach ($content in $entry.message.content) {
                        if ($content.type -eq "tool_result" -and
                            $content.is_error -eq $true -and
                            $content.content -match "requires approval") {

                            # Extract the command from the message
                            $msg = $content.content
                            $cmd = ""
                            if ($msg -match "requires approval:\s*(.+)$") {
                                $cmd = $matches[1].Trim()
                            }

                            $hash = "native-$($content.tool_use_id)"
                            if (-not $notifiedCommands.ContainsKey($hash)) {
                                $notifiedCommands[$hash] = $true
                                $preview = if ($cmd) {
                                    if ($cmd.Length -gt 80) { $cmd.Substring(0, 80) + "..." } else { $cmd }
                                } else { "Bash command" }

                                $ts = Get-Date -Format "HH:mm:ss"
                                Write-Host "[$ts] PERMISSION NEEDED: $preview" -ForegroundColor Yellow
                                & $notifyScript -Title "Claude Code" -Message "Confirm: $preview" -Scenario "confirm" 2>$null
                            }
                        }
                    }
                }

                # === Signal 2: Hook-based permission request ===
                if ($entry.type -eq "system" -and
                    $entry.subtype -eq "hook_response" -and
                    $entry.hook_name -match "PreToolUse" -and
                    $entry.output -match '"permissionDecision"\s*:\s*"ask"') {

                    $preview = "Bash command"
                    if ($entry.output -match '"permissionDecisionReason"\s*:\s*"([^"]+)"') {
                        $preview = $matches[1] -replace '^Confirm:\s*', ''
                        if ($preview.Length -gt 80) { $preview = $preview.Substring(0, 80) + "..." }
                    }

                    $hash = "hook-$($entry.hook_id)"
                    if (-not $notifiedCommands.ContainsKey($hash)) {
                        $notifiedCommands[$hash] = $true
                        $ts = Get-Date -Format "HH:mm:ss"
                        Write-Host "[$ts] HOOK CONFIRM: $preview" -ForegroundColor Magenta
                        & $notifyScript -Title "Claude Code" -Message "Confirm: $preview" -Scenario "confirm" 2>$null
                    }
                }

                # Clean up on session end
                if ($entry.type -eq "result" -and $entry.terminal_reason) {
                    $notifiedCommands = @{}
                }

            } catch {
                # Skip malformed JSON
            }
        }

        $stream.Close()
        $lastSize = $currentSize

    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }

    Start-Sleep -Milliseconds $PollIntervalMs
}
