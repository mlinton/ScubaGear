[CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('teams', 'exo', 'defender', 'aad', 'powerplatform', 'sharepoint', 'onedrive', '*', IgnoreCase = $false)]
        [Alias('p')]
        [string[]]$Products = '*',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('regression', 'scuba', IgnoreCase = $false)]
        [Alias('t')]
        [string]$TestType = 'regression',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Simple', 'Minimum', 'Extreme')]
        [Alias('a')]
        [string]$Auto = '',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Alias('o')]
        [string]$Out = $(Join-Path -Path $(Split-Path -Path $pwd) -ChildPath 'Functional\Reports'),

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Alias('s')]
        [string]$Save = $(Join-Path -Path $(Split-Path -Path $pwd) -ChildPath 'Functional\Archive'),

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Alias('i')]
        [string]$RegressionTests = '',

        [Parameter(Mandatory = $false)]
        [Alias('v')]
        [switch]$VerboseOutput,

        [Parameter(Mandatory = $false)]
        [Alias('q')]
        [switch]$Quiet
    )

    function Get-GoldenFiles {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [ValidateSet('aad', 'defender', 'exo', 'onedrive', 'powerplatform', 'sharepoint', 'teams', '*', IgnoreCase = $false)]
            [string[]]$Products,

            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$RegressionTestsPath
        )

        if ($RegressionTestsPath -ne '') {
            $GoldenFolderPath = Join-Path -Path $RegressionTestsPath -ChildPath 'GoldenRegressionTests'
        }
        else {
            $GoldenFolderPath = $(Join-Path -Path $(Split-Path -Path $pwd) -ChildPath 'GoldenRegressionTests')
        }
        New-Folders $GoldenFolderPath
        $LogIn = $true

        foreach( $Product in $Products) {
            $FolderPath = Join-Path -Path $GoldenFolderPath -ChildPath $Product
            New-Folders $FolderPath
            try {
                Invoke-SCuBA -ProductNames $Products -OutPath $Out -LogIn $LogIn -Quiet $Quiet
                $MostRecentFolder = (Get-ChildItem $Out -Directory | Sort-Object CreationTime)[-1]
                $RedactionDataFilePath = $(Join-Path -Path $(Split-Path -Path $pwd) -ChildPath 'Functional\RedactionData.csv')

                $RedactionParams = @{
                    'InputFilePath' = $(Join-Path -Path $Out -ChildPath $(Join-Path -Path $MostRecentFolder -ChildPath 'ProviderSettingsExport.json')); #$(Join-Path -Path $Out -ChildPath $MostRecentFolder);
                    'OutputFilePath' = $FolderPath;
                    'RedactionDataFilePath' = $RedactionDataFilePath;
                }
                .\Redact-SensitiveData.ps1 @RedactionParams
                #.\Redact-SensitiveData.ps1 -InputFilePath $(Join-Path -Path $Out -ChildPath $(Join-Path -Path $MostRecentFolder -ChildPath 'TestResults.json')) -OutputFilePath $FolderPath
                #Remove-Item -Recurse $MostRecentFolder
            }
            catch {
                Write-Output $_
            }
            $LogIn = $false
        }
        $GoldenFolderPath
    }

    function Invoke-SCuBATest {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [ValidateSet('aad', 'defender', 'exo', 'onedrive', 'powerplatform', 'sharepoint', 'teams', '*', IgnoreCase = $false)]
            [string[]]$Products,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$OutResultsPath,

            [Parameter(Mandatory)]
            [boolean]$LogIn,

            [Parameter(Mandatory)]
            [boolean]$Quiet
        )

        try {
            Invoke-SCuBA -ProductNames $Products -OutPath $OutResultsPath -LogIn $LogIn -Quiet $Quiet
        }
        catch {
            Write-Output $_
        }

    }

    function Invoke-RegressionTest {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [ValidateSet('aad', 'defender', 'exo', 'onedrive', 'powerplatform', 'sharepoint', 'teams', '*', IgnoreCase = $false)]
            [string[]]$Products,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$OutResultsPath,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$SaveResultsPath,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$RegressionTestsPath,

            [Parameter(Mandatory)]
            [boolean]$VerboseOutput,

            [Parameter(Mandatory)]
            [boolean]$Quiet
        )

        $ExportFilename = Join-Path -Path $PSScriptRoot -ChildPath 'ProviderSettingsExport.json'

        foreach($Product in $Products) {
            $FilePath = Join-Path -Path $RegressionTestsPath -ChildPath $Product
            $ProviderExportFiles = Get-Filenames -FilePath $FilePath -Key 'ProviderExport'
            if ($ProviderExportFiles[0]) {
                foreach ($File in $ProviderExportFiles[1]) {
                    #Copy-Item -Path $File -Destination $ExportFilename

                    if (Confirm-FileExists $ExportFilename) {
                        try {
                            .\RegoCachedProviderTesting.ps1 -ProductNames $Product -ExportProvider $false -OutPath $OutResultsPath -Quiet $Quiet
                        }
                        catch {
                            Set-Location $PSScriptRoot
                            Write-Error "Unknown problem running '.\RegoCachedProviderTesting.ps1', please report."
                            Write-Output $_
                            #Remove-Item $ExportFilename
                            exit
                        }
                        Set-Location $PSScriptRoot
                        Compare-TestResults -Filename $File -OutResultsPath $OutResultsPath -SaveResultsPath $SaveResultsPath
                        Remove-Item $ExportFilename
                    }
                }
            }
            else {
                Write-Warning "$Product is missing, no files for Rego test found`nSkipping......`n" | Out-Host
            }
        }
    }

    function Invoke-AutomaticTest {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [ValidateSet('regression', 'scuba', IgnoreCase = $false)]
            [string]$TestType,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [ValidateSet('Simple', 'Minimum', 'Extreme')]
            [string]$Auto,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Out,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Save,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$RegressionTests,

            [Parameter(Mandatory)]
            [switch]$VerboseOutput,

            [Parameter(Mandatory)]
            [switch]$Quiet
        )
        $Filename = ''

        switch ($Auto) {
            'Extreme' {
                Write-Warning "File has 1957 tests!`n" | Out-Host
                if ((Confirm-UserSelection "Do you wish to continue [y/n]?") -eq $false) {
                    Write-Output "Canceling....."
                    exit
                }
                Write-Output "Continuing.....`nEnter Ctrl+C to cancel`n"

                $Filename = "Functional\Auto\ExtremeTest.txt"
            }
            'Minimum' {
                $Filename = "Functional\Auto\MinimumTest.txt"
            }
            'Simple' {
                $Filename = "Functional\Auto\SimpleTest.txt"
            }
            Default {
                Write-Error "Uknown auto test '$Auto'"
                exit
            }
        }

        if (Confirm-FileExists $Filename) {
            foreach ($Products in Get-Content $Filename) {
                $IntegrationTestParams = @{
                    'Products' = $Products;
                    'TestType' = $TestType;
                    'Out' = $Out;
                    'Save' = $Save;
                    'RegressionTests' = $RegressionTests;
                    'VerboseOutput' = $VerboseOutput;
                    'Quiet' = $Quiet;
                }

                Invoke-IntegrationTest @IntegrationTestParams
            }
        }

    }

    function Compare-TestResults {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Filename,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$OutResultsPath,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$SaveResultsPath
        )

        $ResultRegression = $Filename -replace 'ProviderExport', 'TestResults'
        $RegressionJson = Get-FileContent $ResultRegression | ConvertFrom-Json
        $TestResultFile = Get-ChildItem $OutResultsPath -Filter *.json | Where-Object { $_.Name -match 'TestResults' } | Select-Object Fullname
        $SavedFile = Get-NewFilename -FilePath $ResultRegression -SaveResultsPath $SaveResultsPath
        Copy-Item -Path $TestResultFile.Fullname -Destination $SavedFile

        if (Confirm-FileExists $SavedFile) {
            $NewJson = Get-Content $SavedFile | ConvertFrom-Json

            if (($RegressionJson | ConvertTo-Json -Compress) -ne ($NewJson | ConvertTo-Json -Compress)) {
                try {
                    code --diff $ResultRegression $SavedFile
                }
                catch {
                    Compare-Object (($RegressionJson | ConvertTo-Json) -split '\r?\n') (($NewJson | ConvertTo-Json) -split '\r?\n')
                    Write-Output "`n==== $(Split-Path -Path $ResultRegression -Leaf -Resolve) vs $(Split-Path -Path $SavedFile -Leaf -Resolve) ====`n" | Out-Host
                }
            }
        }
    }

    function Confirm-FileExists {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Filename
        )

        if (Test-Path -Path $Filename -PathType Leaf) {
            return $true
        }
        else {
            Write-Warning "$Filename not found`nSkipping......`n" | Out-Host
        }
        return $false
    }

    function Get-NewFilename {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$FilePath,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$SaveResultsPath
        )

        $Filename = Split-Path -Path $Filepath -Leaf -Resolve
        $Date = Get-Date -Format 'MMddyyyy'
        $NewFilename = $Filename -replace '[0-9]+\.json', ($Date + '.json')

        return Join-Path -Path (Get-Item $SaveResultsPath) -ChildPath $NewFilename
    }

    function Get-FileContent {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$File
        )

        if (Confirm-FileExists $File) {
            return Get-Content $File
        }
        return $null

    }

    function Get-Filenames {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$FilePath,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Key
        )

        try {
            $Files = (Get-ChildItem  $FilePath -ErrorAction Stop | Where-Object { $_.Name -match $Key } | Select-Object FullName).FullName
            return $true, $Files
        }
        catch {
            return $false
        }
    }

    function Get-AbsolutePath {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$FilePath
        )

        $NewFilePath = (Get-ChildItem -Recurse -Filter $(Split-Path -Path $FilePath -Leaf) -Directory -ErrorAction SilentlyContinue -Path $(Split-Path -Path $FilePath)).FullName

        if ($null -eq $NewFilePath) {
            Write-Error "$FilePath NOT FOUND" | Out-Host
            exit
        }
        return $NewFilePath

    }

    function New-Folders {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [String[]]$Folders
        )

        foreach ($Folder in $Folders) {
            if ((Test-Path $Folder) -eq $false) {
                New-Item $Folder -ItemType Directory
            }
        }
    }

    New-Folders $Out
    $Out = Get-AbsolutePath $Out

    if ($Products[0] -eq '*') {
        [string[]] $Products = ((Get-ChildItem -Path 'Unit\Rego' -Recurse -Directory -Force -ErrorAction SilentlyContinue |
        Select-Object Name).Name).toLower()
    }

    if ($Auto -ne '') {
        $IntegrationTestParams = @{
            'Products' = $Products;
            'TestType' = $TestType;
            'Out' = $Out;
            'Save' = $Save;
            'RegressionTests' = $RegressionTests;
            'VerboseOutput' = $VerboseOutput;
            'Quiet' = $Quiet;
        }
        Invoke-AutomaticTest @IntegrationTestParams -Auto $Auto
        exit
    }

    switch ($TestType) {
        'regression' {
            $Out = Join-Path -Path $Out -ChildPath "Regression"
            New-Folders $Out,$Save
            #$RegressionTests = Get-GoldenFiles -Products $Products -RegressionTestsPath $RegressionTestsPath
            #exit
            $RegressionTests = (Join-Path -Path $Home -ChildPath 'BasicRegressionTests')
            $Save = Get-AbsolutePath $Save
            $RegressionTests = Get-AbsolutePath $RegressionTests
            Invoke-RegressionTest -Products $Products -OutResultsPath $Out -SaveResultsPath $Save -RegressionTestsPath $RegressionTests -VerboseOutput $VerboseOutput -Quiet $Quiet
        }
        'scuba' {
            Invoke-SCuBATest -Products $Products -OutResultsPath $Out -LogIn $true -Quiet $Quiet
        }
        Default {
            Write-Error "Unknown test type: '$TestType'"
        }
    }