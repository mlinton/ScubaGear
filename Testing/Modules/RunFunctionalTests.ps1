[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Key',
Justification = 'variable is used in another scope')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'VerboseOutput',
Justification = 'variable is used in another scope')]

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
            $GoldenFolderPath = Join-Path -Path $(Get-AbsolutePath $RegressionTests) -ChildPath 'GoldenRegressionTests'
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
                $RedactionDataFilePath = $(Join-Path -Path $(Split-Path -Path $pwd) -ChildPath 'Functional')
                . .\Redact-SensitiveData.ps1
                try {
                    $RedactionParams = @{
                        'InputPath' = $(Join-Path -Path $Out -ChildPath $MostRecentFolder);
                        'OutputPath' = $FolderPath;
                        'RedactionDataPath' = $RedactionDataFilePath;
                    }
                    Invoke-RedactSensitiveData @RedactionParams
                }
                catch {
                    Write-Error "Unknown problem running 'Invoke-RedactSensitiveData', please report."
                    Write-Output $_
                    exit
                }
                Remove-Item -Recurse $MostRecentFolder
            }
            catch {
                Write-Error "Unknown problem running 'Invoke-SCuBA', please report."
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
            [boolean]$Quiet
        )

        $ExportFilename = Join-Path -Path $OutResultsPath -ChildPath 'ProviderSettingsExport.json'
        $VerboseString = ' '
        $FailString = ' '
        $TotalCount = 0
        $PassCount = 0

        foreach($Product in $Products) {
            $FilePath = Join-Path -Path $RegressionTestsPath -ChildPath $Product
            $ProviderExportFiles = Get-Filenames -FilePath $FilePath -Key 'ProviderExport'
            if ($ProviderExportFiles[0]) {
                $TotalCount += $ProviderExportFiles[1].Length
                foreach ($File in $ProviderExportFiles[1]) {
                    Copy-Item -Path $File -Destination $ExportFilename

                    if (Confirm-FileExists $ExportFilename) {
                        try {
                            $RunCachedParams = @{
                                'ExportProvider' = $false;
                                'Login' = $false;
                                'ProductNames' = $Product;
                                'M365Environment' = 'gcc';
                                'OPAPath' = $(Split-Path -Path $PSScriptRoot | Split-Path);
                                'OutPath' = $OutResultsPath;
                                'Quiet' = $Quiet;
                            }
                            Invoke-RunCached @RunCachedParams
                        }
                        catch {
                            Write-Error "Unknown problem running 'Invoke-RunCached', please report."
                            Write-Output $_
                            Remove-Item $ExportFilename
                            exit
                        }
                        $CompareParams = @{
                            'Filename' = $File;
                            'OutResultsPath' = $OutResultsPath;
                            'SaveResultsPath' = $SaveResultsPath;
                        }
                        $ResultString = Compare-TestResults @CompareParams
                        if ($ResultString.Contains('CONSISTENT')) {
                            $PassCount += 1
                        }
                        else {
                            $FailString += $ResultString
                        }

                        $VerboseString += $ResultString
                        Remove-Item $ExportFilename
                    }
                }
            }
            else {
                Write-Warning "$Product is missing, no files for Rego test found`nSkipping......`n" | Out-Host
            }
        }
        return $PassCount, $TotalCount, $VerboseString, $FailString
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
            [AllowEmptyString()]
            [string]$RegressionTests,

            [Parameter(Mandatory)]
            [switch]$VerboseOutput
        )
        #$Auto = $Auto.Substring(0,1).ToUpper()+$Auto.Substring(1).ToLower()
        $Filename = $(Join-Path -Path $(Split-Path -Path $pwd) -ChildPath "Functional\Auto\$($Auto)Test.txt")

        if($Auto -eq 'Extreme') {
            Write-Warning "File has 1957 tests!`n" | Out-Host
            if ((Confirm-UserSelection "Do you wish to continue [y/n]?") -eq $false) {
                Write-Output "Canceling....."
                exit
            }
            Write-Output "Continuing.....`nEnter Ctrl+C to cancel`n"
        }

        if (Confirm-FileExists $Filename) {
            foreach ($Products in Get-Content $Filename) {
                $IntegrationTestParams = @{
                    'Products' = $Products;
                    'TestType' = $TestType;
                    'Out' = $Out;
                    'Save' = $Save;
                    'VerboseOutput' = $VerboseOutput;
                    'Quiet' = $true;
                }

                Write-Output "`n`t=== Automatic Testing @($($Products -join ",")) ==="
                if ($RegressionTests -ne '') {
                    #Invoke-IntegrationTest @IntegrationTestParams -RegressionTests $RegressionTests
                    .\RunFunctionalTests.ps1 @IntegrationTestParams -RegressionTests $RegressionTests
                }
                else {
                    #Invoke-IntegrationTest @IntegrationTestParams
                    .\RunFunctionalTests.ps1 @IntegrationTestParams
                }
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
        $ResultString = ""

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
                $ResultString = "`n`t$(Split-Path -Path $ResultRegression -Leaf -Resolve) : DIFFERENT"
            }
            else {
                $ResultString = "`n`t$(Split-Path -Path $ResultRegression -Leaf -Resolve) : CONSISTENT"
            }
        }
        return $ResultString
    }

    function Write-RegoOutput {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [ValidateSet('aad', 'defender', 'exo', 'onedrive', 'powerplatform', 'sharepoint', 'teams', '*', IgnoreCase = $false)]
            [string[]]$Products,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string[]]$RegoResults,

            [Parameter(Mandatory)]
            [boolean]$VerboseOutput
        )

        if ($VerboseOutput) {
            Write-Output "`n`t=== Testing @($($Products -join ",")) ===$($RegoResults[2])"
        }
        elseif ($RegoResults[3] -ne "") {
            Write-Output "`n`t=== Testing @($($Products -join ",")) ===$($RegoResults[3])"
        }
        Write-Output "`n`tCONSISTENT $($RegoResults[0])/$($RegoResults[1])`n"
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

    Set-Location $(Split-Path -Path $PSScriptRoot | Split-Path)
    $ManifestPath = Join-Path -Path "./PowerShell" -ChildPath "ScubaGear"
    Remove-Module "ScubaGear" -ErrorAction "SilentlyContinue"
    Import-Module $ManifestPath -ErrorAction Stop
    Set-Location $PSScriptRoot

    New-Folders $Out
    $Out = Get-AbsolutePath $Out

    if ($Auto -ne '') {
        $IntegrationTestParams = @{
            'TestType' = $TestType;
            'Auto' = $Auto;
            'Out' = $Out;
            'Save' = $Save;
            'RegressionTests' = $RegressionTests;
            'VerboseOutput' = $VerboseOutput;
        }

        Invoke-AutomaticTest @IntegrationTestParams
        exit
    }

    if ($Products[0] -eq '*') {
        $UnitTestPath = $(Join-Path -Path $(Split-Path -Path $pwd) -ChildPath 'Unit\Rego')
        $Products = $((Get-ChildItem -Path $UnitTestPath -Recurse -Directory -Force -ErrorAction SilentlyContinue |
        Select-Object Name).Name).toLower()
    }

    switch ($TestType) {
        'regression' {
            $Out = Join-Path -Path $Out -ChildPath "Regression"
            New-Folders $Out,$Save
            $RegressionTests = Get-GoldenFiles -Products $Products -RegressionTestsPath $RegressionTestsPath
            #$RegressionTests = (Join-Path -Path $Home -ChildPath 'BasicRegressionTests')
            $Save = Get-AbsolutePath $Save
            #$RegressionTests = Get-AbsolutePath $RegressionTests
            $RegressionTest = @{
                'Products' = $Products;
                'OutResultsPath' = $Out;
                'SaveResultsPath' = $Save;
                'RegressionTestsPath' = $RegressionTests;
                'Quiet' = $Quiet;
            }
            Write-RegoOutput -Products $Products -RegoResults $(Invoke-RegressionTest @RegressionTest) -VerboseOutput $VerboseOutput
        }
        'scuba' {
            $SCuBATestParams = @{
                'Products' = $Products;
                'OutResultsPath' = $Out;
                'LogIn' = $true;
                'Quiet' = $Quiet;
            }
            Invoke-SCuBATest @SCuBATestParams
        }
        Default {
            Write-Error "Unknown test type: '$TestType'"
        }
    }