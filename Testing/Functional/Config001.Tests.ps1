#$private:ExecutingTestPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
# Import-Module -Name $(Join-Path -Path $private:ExecutingTestPath -ChildPath '..\..\..\..\PowerShell\ScubaGear\Modules\ScubaConfig\ScubaConfig.psm1') -Force

Describe -tag "Config001" -name 'Teams Functional Test for Config001' {
    context 'JSON Configuration' {
        BeforeAll {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'ScubaConfigTestFile')]
            $TestFile = Join-Path -Path $PSScriptRoot -ChildPath ../TestResults.json
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'Results')]
            $TestResults = Get-Content -Raw -Path $TestFile | ConvertFrom-Json
            $Results = @{}

            for ($Index = 0; $Index -lt $TestResults.length; $Index++){
                $Record = $TestResults[$Index]
                $Key = "$($Record.Control)"
                $Results[$Key] = $TestResults[$Index].RequirementMet
            }
        }
        It 'Teams 2.1-A DLP solution SHALL be enabled' {
            $Key = "Teams 2.1"
            $Results["$Key"] | Should -Be $true
        }
        It 'Teams 2.2-Anonymous users SHALL NOT be enabled to start meetings in the Global (Org-wide default) meeting policy or in custom meeting policies if any exist' {
            $Key = "Teams 2.2"
            $Results["$Key"] | Should -Be $true
        }
        It 'Teams 2.3-Internal users SHOULD be admitted automatically' {
            $Key = "Teams 2.3" #Internal users SHOULD be admitted automatically"
            $Results["$Key"] | Should -Be $true
        }
        It 'Teams 2.9-Cloud video recording SHOULD be disabled in the global (org-wide default) meeting policy' {
            $Key = "Teams 2.9" #Cloud video recording SHOULD be disabled in the global (org-wide default) meeting policy"
            $Results["$Key"] | Should -Be $true
        }
        It 'Teams 2.10-Record an event SHOULD be set to Organizer can record' {
            $Key = "Teams 2.10" #Cloud video recording SHOULD be disabled in the global (org-wide default) meeting policy"
            $Results["$Key"] | Should -Be $true
        }
    }
}