param(
    [string]$Title = "Claude Code",
    [string]$Message = "Please confirm",
    [string]$ToolName = "",
    [string]$Scenario = "default"
)

# Log hook invocation for debugging
$logFile = "$PSScriptRoot/notify.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value "$timestamp | Scenario=$Scenario | Title=$Title | Message=$Message | ToolName=$ToolName"

# Build contextual message based on scenario
$finalMessage = switch ($Scenario) {
    "tool_use" { "Executing: $ToolName" }
    "confirm"  { "Please confirm: $Message" }
    "complete" { "Task completed: $Message" }
    "error"    { "Error: $Message" }
    default    { $Message }
}

# Register AppUserModelID
$appId = 'ClaudeCode.App'
$regPath = "HKCU:\Software\Classes\AppUserModelId\$appId"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
Set-ItemProperty -Path $regPath -Name 'DisplayName' -Value 'Claude Code' -Force

# Escape XML
$escapedTitle = [System.Security.SecurityElement]::Escape($Title)
$escapedMessage = [System.Security.SecurityElement]::Escape($finalMessage)

# Send toast
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml("<toast><visual><binding template=`"ToastGeneric`"><text>$escapedTitle</text><text>$escapedMessage</text></binding></visual><audio src=`"ms-winsoundevent:Notification.Default`"/></toast>")

$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
$toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(5)
$notifier.Show($toast)
