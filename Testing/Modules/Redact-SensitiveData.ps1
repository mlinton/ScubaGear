function Invoke-RedactSensitiveData{
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -PathType Container $_})]
        [string]
        $InputPath,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -PathType Container $_})]
        [string]
        $OutputPath,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -PathType Container $_})]
        [string]
        $RedactionDataPath
    )

    function Set-Property {
        param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object]
        $Json,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string]
        $Value
    )
        $First, $Rest = $Path

        if ($Rest) {
            if ($First.StartsWith('[*]')){
                # Json starts with an anonomous array
                for ($Index = 0; $Index -lt $Json.length; $Index++){
                    Set-Property -Json $Json[$Index] -Path $rest -Value $Value
                }
            }
            elseif ($First.EndsWith('[*]')){
                $First = $First.Substring(0, $First.Length - 3)
                if ($Json.$First -is [array]){
                    foreach ($Item in $Json.$First){
                        Set-Property -Json $Item -Path $rest -Value $Value
                    }
                }else{
                    $Keys = (Get-Member -InputObject $Json.$First -MemberType NoteProperty).Name
                    ForEach ($Key in $Keys){
                        Set-Property -Json $($Json.$First).$Key -Path $rest -Value $Value
                   }
                }
            }
            else{
                Set-Property -Json $Json.$First -Path $Rest -Value $Value
            }
        } else {
            if ($First.EndsWith('[*]')){
                $First = $First.Substring(0, $First.Length - 3)
                if ($Json.$First -is [array]){
                    for ($Index = 0; $Index -lt $Json.$First.length; $Index++){
                        $Json.$First[$Index] = $Value
                    }
                }
            }
            else{
                $Json.$First = $Value
            }
        }
    }

    $TenantName = "Not Found"

    # Redact Provider Settings Export
    $InputFilePath = Join-Path -Path $InputPath -ChildPath 'ProviderSettingsExport.json'

    if (Test-Path -Path $InputFilePath -PathType Leaf){
        $InputData = Get-Content -Path $InputFilePath -Raw | ConvertFrom-Json
        $TenantName = $InputData.tenant_details.DisplayName
        $RedactionDataFilePath = Join-Path -Path $RedactionDataPath -ChildPath 'ProviderRedactionData.csv'

        if (Test-Path -Path $RedactionDataFilePath -PathType Leaf){
            $RedactionData = Get-Content -Path $RedactionDataFilePath -Raw | ConvertFrom-Csv

            foreach ($Property in $RedactionData){
                $PropertyPath =  $Property.name.Split('.')
                Set-Property -Json $InputData -Path $PropertyPath -Value $Property.Value
            }

            $OutputFileName = Join-Path -Path $OutputPath -ChildPath "ProviderExport-$TenantName.json"
                $InputData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFileName
        }
        else{
            Write-Error "Provider settings redaction file not found at path: $RedactionDataPath"
        }
    }
    else {
        Write-Error "Provider settings export not found at path: $InputPath"
    }

    # Redact Test Results
    $InputFilePath = Join-Path -Path $InputPath -ChildPath 'TestResults.json'

    if (Test-Path -Path $InputFilePath -PathType Leaf){
        $InputData = Get-Content -Path $InputFilePath -Raw | ConvertFrom-Json
        $RedactionDataFilePath = Join-Path -Path $RedactionDataPath -ChildPath 'ResultsRedactionData.csv'

        if (Test-Path -Path $RedactionDataFilePath -PathType Leaf){
            $RedactionData = Get-Content -Path $RedactionDataFilePath -Raw | ConvertFrom-Csv

            foreach ($Property in $RedactionData){
                $PropertyPath =  $Property.name.Split('.')
                Set-Property -Json $InputData -Path $PropertyPath -Value $Property.Value
            }

            $OutputFileName = Join-Path -Path $OutputPath -ChildPath "TestResults-$TenantName.json"
                $InputData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFileName
        }
        else{
            Write-Error "Test results redaction file not found at path: $RedactionDataPath"
        }
    }
    else {
        Write-Error "Test results not found at path: $InputPath"
    }
}
