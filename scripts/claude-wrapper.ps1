# claude-wrapper.ps1
# Wraps Claude CLI to detect permission prompts and send Windows notifications.
# Usage: .\claude-wrapper.ps1 [claude args...]
#
# This script monitors Claude Code's output stream for permission prompt patterns.
# When detected, it sends a Windows notification and plays a sound.
# It does NOT intercept or modify Claude's behavior - just monitors and notifies.

param(
    [string[]]$ClaudeArgs
)

# --- Configuration ---
$notifyScript = Join-Path $PSScriptRoot "notify.ps1"

# Patterns that indicate Claude Code is waiting for user confirmation
$permissionPatterns = @(
    'Allow\?\s*\(y/N\)',
    'Do you want to proceed',
    'needs your permission',
    'waiting for user confirmation',
    'approve.*\? \(y/N\)',
    'Wants to run',
    'Claude wants to run',
    'permission to run',
    '\(y/N\)\s*$',
    'Press.*to approve',
    'Enter.*to confirm'
)

# --- Start Claude Code ---
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "claude"
$psi.Arguments = ($ClaudeArgs -join " ")
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi

try {
    $null = $process.Start()
} catch {
    Write-Error "Failed to start claude: $_"
    exit 1
}

$alreadyNotified = $false
$lastNotifyTime = [DateTime]::MinValue

# --- Monitor output in background jobs ---
$stdoutJob = Start-Job -ScriptBlock {
    param($proc)
    while (-not $proc.HasExited) {
        try {
            if (-not $proc.StandardOutput.EndOfStream) {
                $proc.StandardOutput.ReadLine()
            } else {
                Start-Sleep -Milliseconds 50
            }
        } catch { break }
    }
} -ArgumentList $process

$stderrJob = Start-Job -ScriptBlock {
    param($proc)
    while (-not $proc.HasExited) {
        try {
            if (-not $proc.StandardError.EndOfStream) {
                $proc.StandardError.ReadLine()
            } else {
                Start-Sleep -Milliseconds 50
            }
        } catch { break }
    }
} -ArgumentList $process

# --- Main monitoring loop ---
while (-not $process.HasExited) {

    # Check stdout
    $stdoutResult = Receive-Job $stdoutJob -ErrorAction SilentlyContinue
    if ($stdoutResult) {
        foreach ($line in $stdoutResult) {
            Write-Host $line

            # Check for permission prompt
            $matched = $false
            foreach ($pattern in $permissionPatterns) {
                if ($line -match $pattern) {
                    $matched = $true
                    break
                }
            }

            $now = Get-Date
            if ($matched -and -not $alreadyNotified -and ($now - $lastNotifyTime).TotalSeconds -gt 5) {
                # Send notification
                & $notifyScript -Title "Claude Code" -Message "Waiting for your confirmation" -Scenario "confirm" 2>$null
                $alreadyNotified = $true
                $lastNotifyTime = $now
            }

            # Reset notification flag when execution continues
            if ($line -match '^\s*(Executing|Running|Tool result|Completed|Error)') {
                $alreadyNotified = $false
            }
        }
    }

    # Check stderr
    $stderrResult = Receive-Job $stderrJob -ErrorAction SilentlyContinue
    if ($stderrResult) {
        foreach ($line in $stderrResult) {
            Write-Host $line -ForegroundColor Red

            foreach ($pattern in $permissionPatterns) {
                if ($line -match $pattern) {
                    $now = Get-Date
                    if (-not $alreadyNotified -and ($now - $lastNotifyTime).TotalSeconds -gt 5) {
                        & $notifyScript -Title "Claude Code" -Message "Waiting for your confirmation" -Scenario "confirm" 2>$null
                        $alreadyNotified = $true
                        $lastNotifyTime = $now
                    }
                    break
                }
            }
        }
    }

    Start-Sleep -Milliseconds 100
}

# Cleanup
Remove-Job $stdoutJob -Force -ErrorAction SilentlyContinue
Remove-Job $stderrJob -Force -ErrorAction SilentlyContinue

exit $process.ExitCode
