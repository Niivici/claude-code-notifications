# Claude Code Windows Notifications

Windows notification integration for Claude Code CLI. Get desktop notifications in Windows Action Center when tasks complete, notable commands execute, or errors occur.

## Features

- **Task Completion**: Notification when Claude Code session ends
- **Notable Commands**: Notification when potentially dangerous Bash commands are executed
- **Error Alerts**: Notification when tool execution fails

## Prerequisites

- Windows 10/11
- PowerShell 5.1+
- Notifications enabled in Windows Settings

## Installation

1. Clone this repository:
```bash
git clone https://github.com/Niivici/claude-code-notifications.git
```

2. Copy scripts to Claude Code directory:
```powershell
Copy-Item scripts/* ~/.claude/scripts/
```

3. Add hooks to `~/.claude/settings.json`:
```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -ExecutionPolicy Bypass -File \"C:/Users/YOUR_USERNAME/.claude/scripts/notify.ps1\" -Title \"Claude Code\" -Message \"Task completed\" -Scenario \"complete\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -ExecutionPolicy Bypass -File \"C:/Users/YOUR_USERNAME/.claude/scripts/check-confirm-notify.ps1\""
          },
          {
            "type": "command",
            "command": "powershell.exe -ExecutionPolicy Bypass -File \"C:/Users/YOUR_USERNAME/.claude/scripts/check-error-notify.ps1\""
          }
        ]
      }
    ]
  }
}
```

## Windows Settings

Ensure notifications are enabled:
1. Open **Settings** > **System** > **Notifications**
2. Turn on **Notifications**
3. Turn on **Notification Center**

## Usage

Notifications are sent automatically:
- When Claude Code session ends (Stop hook)
- When notable/dangerous Bash commands are executed (PostToolUse hook)
- When a tool execution fails with an error (PostToolUse hook)

View notifications: Press `Win+A` to open Action Center.

## How It Works

### Notification Flow

1. **Stop Hook**: Fires when Claude Code session ends. Sends a "Task completed" notification.

2. **PostToolUse Hook**: Fires after every tool execution. The `check-confirm-notify.ps1` script:
   - Reads the tool data from stdin (JSON)
   - Checks if the tool is a Bash command
   - Matches against a list of "dangerous" command patterns
   - Sends a notification if the command matches

3. **Error Detection**: The `check-error-notify.ps1` script:
   - Reads tool output from stdin
   - Checks for error indicators (error, failed, exception, FATAL, CRITICAL)
   - Sends an error notification if detected

### Dangerous Command Patterns

The following patterns trigger notifications:
- `rm -rf`, `rm -r`, `rmdir`, `del /`
- `git push`, `git reset --hard`, `git clean -f`
- `npm publish`, `pip install`, `cargo install`
- `sudo`, `chmod 777`, `chown`
- `curl | sh`, `wget | sh`
- `Remove-Item`, `Format-`, `Invoke-Expression`

## Known Limitations

- **PreToolUse hooks do not fire for Bash commands** in Claude Code's Auto mode (acceptEdits). This is a Claude Code limitation. Notifications are sent after command execution, not before.
- **Notification hook's `permission_prompt` matcher** does not trigger on Windows. This is a known issue with Claude Code 2.1.140.
- Notifications are sent for commands matching "dangerous" patterns, but this is an approximation. Some safe commands may match, and some dangerous commands may not match.

## Testing

Run tests with Pester:
```powershell
Invoke-Pester scripts/notify.tests.ps1
```

## Files

- `scripts/notify.ps1` - Main notification script (sends Windows toast notifications)
- `scripts/NotificationModule.psm1` - PowerShell module with Send-Notification function
- `scripts/notify.tests.ps1` - Pester tests
- `scripts/check-confirm-notify.ps1` - Notable command detection script
- `scripts/check-error-notify.ps1` - Error detection script

## License

MIT
