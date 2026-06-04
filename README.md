# Claude Code Windows Notifications

Windows notification integration for Claude Code CLI. Get desktop notifications when tasks complete, confirmation is needed, or errors occur.

## Features

- **Task Completion**: Notification when Claude Code session ends
- **Confirmation Required**: Notification when user input is needed
- **Error Alerts**: Notification when tool execution fails

## Prerequisites

- Windows 10/11
- PowerShell 5.1+
- Notifications enabled in Windows Settings

## Installation

1. Clone this repository:
```bash
git clone https://github.com/YOUR_USERNAME/claude-code-notifications.git
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
            "command": "powershell.exe -ExecutionPolicy Bypass -File \"$HOME/.claude/scripts/notify.ps1\" -Title \"Claude Code\" -Message \"Task completed\" -Scenario \"complete\""
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -ExecutionPolicy Bypass -File \"$HOME/.claude/scripts/notify.ps1\" -Title \"Claude Code\" -Message \"Need your confirmation\" -Scenario \"confirm\""
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
            "command": "powershell.exe -ExecutionPolicy Bypass -File \"$HOME/.claude/scripts/check-error-notify.ps1\""
          }
        ]
      }
    ]
  }
}
```

## Windows Settings

Ensure notifications are enabled:
1. Open **Settings** → **System** → **Notifications**
2. Turn on **Notifications**
3. Turn on **Notification Center**

## Usage

Notifications are sent automatically:
- When Claude Code session ends
- When Claude Code needs your confirmation
- When a tool execution fails

View notifications: Press `Win+A` to open Action Center.

## Testing

Run tests with Pester:
```powershell
Invoke-Pester scripts/notify.tests.ps1
```

## Files

- `scripts/notify.ps1` - Main notification script
- `scripts/NotificationModule.psm1` - PowerShell module
- `scripts/notify.tests.ps1` - Pester tests
- `scripts/check-error-notify.ps1` - Error detection script

## License

MIT
