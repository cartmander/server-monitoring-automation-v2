param(
    [Parameter(Mandatory=$true)]
    [string] $username,

    [Parameter(Mandatory=$true)]
    [string] $password
)

function ValidateCsv
{
    param(
        [object] $csv
    )

    $requiredHeaders = "Subscription", "ResourceGroup", "VirtualMachineName", "WorkspaceId", "WorkspaceKey"
    $csvHeaders = $csv[0].PSObject.Properties.Name.Split()

    foreach ($header in $csvHeaders)
    {
        if (-not $requiredHeaders.Contains($header))
        {
            Write-Error "CSV contains invalid headers"
            exit 1
        }
    }

    return $csv
}

function BuildCsvData
{
    param(
        [object] $csvData,
        [string] $columnName,
        [string] $columnValue
    )

    $csvData.Add($columnName, $columnValue)

    return $csvData
}

function ProcessCsv
{
    param(
        [object] $csv
    )

    $counter = 0
    $csvObject = Import-Csv "csv/VirtualMachines.csv" | Measure-Object

    foreach ($data in $csv)
    {
        $column = $data | Get-Member -MemberType Properties
        $csvData = @{}

        Write-Progress -Activity 'Processing Virtual Machines Onboarding...' -CurrentOperation $virtualMachine.name -PercentComplete (($counter++ / $csvObject.Count) * 100) 

        for($i = 0; $i -lt $column.Count; $i++)
        {
            $columnName = $column[$i].Name
            $columnValue = $data | Select-Object -ExpandProperty $columnName

            $csvData = BuildCsvData $csvData $columnName $columnValue
        }

        .\scripts\MonitoringAgentInstallation.ps1 `
        -subscription $csvData.Subscription `
        -resourceGroup $csvData.ResourceGroup `
        -virtualMachineName $csvData.VirtualMachineName `
        -workspaceId $csvData.WorkspaceId `
        -workspaceKey $csvData.WorkspaceKey `
        -currentCount $counter `
        -total $csvObject.Count
    }
}

try
{

    az login -u $username -p $password

    Write-Host "Initializing automation..." -ForegroundColor Green

    $csv = Import-Csv "csv/VirtualMachines.csv"

    $validatedCsv = ValidateCsv $csv
    ProcessCsv $validatedCsv

    Write-Host "Done running the automation..." -ForegroundColor Green
}

catch 
{
    Write-Output $_
}