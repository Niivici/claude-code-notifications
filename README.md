# Claude Code Windows Notifications

Windows 桌面通知集成，用于 Claude Code CLI。当任务完成、需要确认或出错时，在 Windows 通知中心推送消息。

## 功能

- **任务完成通知** — Claude Code 会话结束时推送
- **命令确认通知** — 需要用户确认的 Bash 命令执行前推送
- **错误通知** — 工具执行失败时推送

## 前置条件

- Windows 10/11
- PowerShell 5.1+
- Windows 通知已开启（设置 → 系统 → 通知）

## 安装

### 1. 克隆仓库

```bash
git clone https://github.com/Niivici/claude-code-notifications.git
```

### 2. 复制脚本到 Claude Code 目录

```powershell
Copy-Item scripts/* ~/.claude/scripts/
```

### 3. 配置 hooks（settings.json）

复制 `settings.example.json` 的内容到 `~/.claude/settings.json`，将 `YOUR_USERNAME` 替换为你的用户名。

### 4. 配置权限（settings.local.json）

复制 `settings.local.example.json` 的内容到 `~/.claude/settings.local.json`。

**关键**：`permissions.allow` 中只保留只读/安全命令，其余 Bash 命令由 PreToolUse hook 接管。

## 工作机制

```
Claude Code 执行 Bash 命令
        │
        ▼
┌─────────────────────────────────────────┐
│  PreToolUse Hook (confirm-bash.ps1)     │
│                                         │
│  收到命令 → 匹配安全模式？              │
│  ├─ YES → {"decision":"allow"} 静默放行  │
│  └─ NO  → 发送 Windows 通知             │
│           + {"decision":"permission_prompt"}
│           → 终端弹出 Yes/No 等待确认     │
└─────────────────────────────────────────┘
        │ (命令执行后)
        ▼
┌─────────────────────────────────────────┐
│  PostToolUse Hook (check-error-notify)  │
│  检测 error/failed/exception → 通知     │
└─────────────────────────────────────────┘
        │ (会话结束)
        ▼
┌─────────────────────────────────────────┐
│  Stop Hook (notify.ps1)                 │
│  发送 "Task completed" 通知             │
└─────────────────────────────────────────┘
```

## 安全命令白名单

以下命令自动放行，不弹通知（可在 `confirm-bash.ps1` 中自定义）：

- `ls`, `cat`, `grep`, `find`, `head`, `tail`, `echo`, `pwd`
- `git status`, `git diff`, `git log`, `git branch`
- `npm list`, `pip list`, `which`, `where`

其他所有 Bash 命令（如 `git push`, `rm`, `npm install`, `curl` 等）会触发通知并要求确认。

## 自定义

### 添加安全命令

编辑 `~/.claude/scripts/confirm-bash.ps1`，在 `$safePatterns` 数组中添加：

```powershell
$safePatterns = @(
    # ... 已有模式 ...
    '^your_safe_command\b'
)
```

### 修改通知样式

编辑 `~/.claude/scripts/notify.ps1`，调整 `$finalMessage` 的 switch 逻辑。

## 文件说明

| 文件 | 用途 |
|------|------|
| `scripts/notify.ps1` | 主通知脚本（发送 Windows Toast 通知） |
| `scripts/confirm-bash.ps1` | PreToolUse hook：决定放行或确认 + 通知 |
| `scripts/check-error-notify.ps1` | PostToolUse hook：检测错误并通知 |
| `scripts/NotificationModule.psm1` | PowerShell 模块 |
| `scripts/notify.tests.ps1` | Pester 测试 |
| `settings.example.json` | settings.json 配置示例 |
| `settings.local.example.json` | settings.local.json 权限配置示例 |

## 测试

```powershell
Invoke-Pester scripts/notify.tests.ps1
```

## 注意事项

- **需要重启 Claude Code 会话**才能让 hook 配置和权限规则生效
- PreToolUse hook 仅对不在 `permissions.allow` 中的 Bash 命令触发
- 如果 hook 脚本出错，会自动放行命令（不阻塞 Claude Code）

## License

MIT
