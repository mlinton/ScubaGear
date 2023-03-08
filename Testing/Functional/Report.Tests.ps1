Import-Module Selenium

Describe -Tag "UI","Chrome" -Name "Test Report with Chrome" {
	BeforeAll {
        $script:url = "file:///C:/Users/crutchfield/source/repos/ScubaGear/M365BaselineConformance_2023_03_02_09_24_54/BaselineReports.html"
		$script:ChromeDriver = Start-SeChrome -Arguments "headless", "incognito"
        Enter-SeUrl $script:url -Driver $script:ChromeDriver
	}

	It "Toggle Dark Mode" {
        $ToggleCheckbox = Find-SeElement -Driver $script:ChromeDriver -By XPath "//input[@id='toggle']"
        $ToggleText = Find-SeElement -Driver $script:ChromeDriver -Id "toggle-text"

        $ToggleCheckbox.Selected | Should -Be $false
        $ToggleText.Text | Should -Be 'Light Mode'

        $ToggleSwitch = Find-SeElement -Driver $script:ChromeDriver -ClassName "switch"
        Invoke-SeClick -Element $ToggleSwitch

        $ToggleText.Text | Should -Be 'Dark Mode'
        $ToggleCheckbox.Selected | Should -Be $true
	}

    It "Verify Tenant"{
        $TenantDataElement = Find-SeElement -Driver $script:ChromeDriver -ClassName "tenantdata"
        $TenantDataRows = Find-SeElement -Target $TenantDataElement -By TagName "tr"
        $TenantDataColumns = Find-SeElement -Target $TenantDataRows[1] -By TagName "td"
        $Tenant = $TenantDataColumns[0].Text
        $Tenant | Should -Be "Cybersecurity and Infrastructure Security Agency" -Because $Tenant
    }

    It "Verify  Domain"{
        $TenantDataElement = Find-SeElement -Driver $script:ChromeDriver -ClassName "tenantdata"
        $TenantDataRows = Find-SeElement -Target $TenantDataElement -By TagName "tr"
        $TenantDataColumns = Find-SeElement -Target $TenantDataRows[1] -By TagName "td"
        $Domain = $TenantDataColumns[1].Text
        $Domain | Should -Be "cisaent.onmicrosoft.com" -Because "Domain is $Domain"
    }

    It "Goto Azure Active Directory details"{
        $AadLink = Find-SeElement -Driver $script:ChromeDriver -By LinkText "Azure Active Directory"
        Invoke-SeClick -Element $AadLink

        $ToggleCheckbox = Find-SeElement -Driver $script:ChromeDriver -By XPath "//input[@id='toggle']"
        $ToggleText = Find-SeElement -Driver $script:ChromeDriver -Id "toggle-text"

        $ToggleText.Text | Should -Be 'Dark Mode'
        $ToggleCheckbox.Selected | Should -Be $true

        $ToggleSwitch = Find-SeElement -Driver $script:ChromeDriver -ClassName "switch"
        Invoke-SeClick -Element $ToggleSwitch

        $ToggleText.Text | Should -Be 'Light Mode'
        $ToggleCheckbox.Selected | Should -Be $false
    }

    It "Go Back to main page - Is Dark mode in correct state"{
        Open-SeUrl -Back -Driver $script:ChromeDriver
        $ToggleCheckbox = Find-SeElement -Driver $script:ChromeDriver -By XPath "//input[@id='toggle']"
        $ToggleText = Find-SeElement -Driver $script:ChromeDriver -Id "toggle-text"
        $ToggleText.Text | Should -Be 'Light Mode'
        $ToggleCheckbox.Selected | Should -Be $false
    }

	AfterAll {
		Stop-SeDriver -Driver $script:ChromeDriver
	}
}

Describe -Tag "UI","Edge" -Name "Test Report with Edge" {
	BeforeAll {
        $script:url = "file:///C:/Users/crutchfield/source/repos/ScubaGear/M365BaselineConformance_2023_03_02_09_24_54/BaselineReports.html"
		$script:EdgeDriver = Start-SeEdge
        Enter-SeUrl $script:url -Driver $script:EdgeDriver
	}

	It "Toggle Dark Mode" {
        $ToggleCheckbox = Find-SeElement -Driver $script:EdgeDriver -By XPath "//input[@id='toggle']"
        $ToggleText = Find-SeElement -Driver $script:EdgeDriver -Id "toggle-text"

        $ToggleCheckbox.Selected | Should -Be $false
        $ToggleText.Text | Should -Be 'Light Mode'

        $ToggleSwitch = Find-SeElement -Driver $script:EdgeDriver -ClassName "switch"
        Invoke-SeClick -Element $ToggleSwitch

        $ToggleText.Text | Should -Be 'Dark Mode'
        $ToggleCheckbox.Selected | Should -Be $true
	}

    It "Verify Tenant"{
        $TenantDataElement = Find-SeElement -Driver $script:EdgeDriver -ClassName "tenantdata"
        $TenantDataRows = Find-SeElement -Target $TenantDataElement -By TagName "tr"
        $TenantDataColumns = Find-SeElement -Target $TenantDataRows[1] -By TagName "td"
        $Tenant = $TenantDataColumns[0].Text
        $Tenant | Should -Be "Cybersecurity and Infrastructure Security Agency" -Because $Tenant
    }

    It "Verify  Domain"{
        $TenantDataElement = Find-SeElement -Driver $script:EdgeDriver -ClassName "tenantdata"
        $TenantDataRows = Find-SeElement -Target $TenantDataElement -By TagName "tr"
        $TenantDataColumns = Find-SeElement -Target $TenantDataRows[1] -By TagName "td"
        $Domain = $TenantDataColumns[1].Text
        $Domain | Should -Be "cisaent.onmicrosoft.com" -Because "Domain is $Domain"
    }

    It "Goto Azure Active Directory details"{
        $AadLink = Find-SeElement -Driver $script:EdgeDriver -By LinkText "Azure Active Directory"
        Invoke-SeClick -Element $AadLink

        $ToggleCheckbox = Find-SeElement -Driver $script:EdgeDriver -By XPath "//input[@id='toggle']"
        $ToggleText = Find-SeElement -Driver $script:EdgeDriver -Id "toggle-text"

        $ToggleText.Text | Should -Be 'Dark Mode'
        $ToggleCheckbox.Selected | Should -Be $true

        $ToggleSwitch = Find-SeElement -Driver $script:EdgeDriver -ClassName "switch"
        Invoke-SeClick -Element $ToggleSwitch

        $ToggleText.Text | Should -Be 'Light Mode'
        $ToggleCheckbox.Selected | Should -Be $false
    }

    It "Go Back to main page - Is Dark mode in correct state"{
        Open-SeUrl -Back -Driver $script:EdgeDriver

        $ToggleCheckbox = Find-SeElement -Driver $script:EdgeDriver -By XPath "//input[@id='toggle']"
        $ToggleText = Find-SeElement -Driver $script:EdgeDriver -Id "toggle-text"

        $ToggleText.Text | Should -Be 'Light Mode'
        $ToggleCheckbox.Selected | Should -Be $false
    }

	AfterAll {
		Stop-SeDriver -Driver $script:EdgeDriver
	}
}