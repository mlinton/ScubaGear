function Invoke-RedactSensitiveData{
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -PathType Leaf $_})]
        [string]
        $InputFilePath,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -PathType Container $_})]
        [string]
        $OutputFilePath,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -PathType Leaf $_})]
        [string]
        $RedactionDataFilePath
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
            if ($First.EndsWith('[*]')){
                $First = $First.Substring(0, $First.Length - 3)
                if ($Json.$First -is [array]){
                    foreach ($Item in $Json.$First){
                        Set-Property -Json $Item -Path $rest -Value $Value
                    }
                }else{
                    foreach ($Object in $Json.$First){
                        $ObjectName = $($Object | Get-Member -MemberType *Property).Name
                        Set-Property -Json $($Json.$First).$ObjectName -Path $rest -Value $Value
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

    $InputData = Get-Content -Path $InputFilePath -Raw | ConvertFrom-Json
    $RedactionData = Get-Content -Path $RedactionDataFilePath -Raw | ConvertFrom-Csv

    foreach ($Property in $RedactionData){
        $PropertyPath =  $Property.name.Split('.')
        Set-Property -Json $InputData -Path $PropertyPath -Value $Property.Value
    }

    $TenantName = $InputData.tenant_details.DisplayName
    $OutputFileName = Join-Path -Path $OutputFilePath -ChildPath "ProviderExport-$TenantName.json"
    $InputData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFileName
}
