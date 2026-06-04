Describe "Send-Notification" {
    BeforeEach {
        Import-Module "$PSScriptRoot/NotificationModule.psm1" -Force
    }

    Context "Basic functionality" {
        It "Should return true on success" {
            $result = Send-Notification -Title "Test" -Message "Test message"
            $result | Should Be $true
        }

        It "Should use default values" {
            $result = Send-Notification
            $result | Should Be $true
        }
    }

    Context "Special characters" {
        It "Should handle Chinese characters" {
            $result = Send-Notification -Title "Claude Code" -Message "Chinese test"
            $result | Should Be $true
        }

        It "Should handle long messages" {
            $longMessage = "A" * 500
            $result = Send-Notification -Title "Test" -Message $longMessage
            $result | Should Be $true
        }
    }

    Context "Notification scenarios" {
        It "Should send tool execution notification" {
            $result = Send-Notification -Title "Claude Code" -Message "Edit file"
            $result | Should Be $true
        }

        It "Should send task completion notification" {
            $result = Send-Notification -Title "Claude Code" -Message "Task completed"
            $result | Should Be $true
        }
    }
}
