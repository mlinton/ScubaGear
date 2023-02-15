##### SCUBA Functional Test Orchestrator - DEMO version :)
#######################################################

[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Report')]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Compliant", "Noncompliant", IgnoreCase = $true)]
        [string]
        $CompliantMode
    )

if ($CompliantMode -eq "Compliant") {
    Write-Warning "###############   Simulate DSC configuring the tenant to a PASS state ########"
    Write-Warning ""

    # Policy:   Teams 2.10 Only the Meeting Organizer SHOULD Be Able to Record Live Events
    ########
    Set-CsTeamsMeetingBroadcastPolicy -BroadcastRecordingMode UserOverride
    ########

    # Policy:   Teams 2.9 Cloud Recording of Teams Meetings SHOULD Be Disabled for Unapproved Users
    ########
    Set-CsTeamsMeetingPolicy -Identity global -AllowCloudRecording $false
    ########
}
else {
    Write-Warning "###############   Simulate DSC configuring the tenant to a FAIL state ########"
    Write-Warning ""
    # Policy:   Teams 2.10 Only the Meeting Organizer SHOULD Be Able to Record Live Events
    ########
    Set-CsTeamsMeetingBroadcastPolicy -BroadcastRecordingMode AlwaysEnabled
    ########

    # Policy:   Teams 2.9 Cloud Recording of Teams Meetings SHOULD Be Disabled for Unapproved Users
    #######
    Set-CsTeamsMeetingPolicy -Identity global -AllowCloudRecording $true
    #######
}

Write-Warning "###############   Simulate ScubaGear Extracting the Config and Evaluating the Baseline Policies ########"
Write-Warning ""
# ================================================================================================ 

Import-Module -Name ..\PowerShell\ScubaGear

Invoke-RunCached -ProductNames teams -Quiet $true -LogIn $false


