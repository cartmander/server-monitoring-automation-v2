param(
    [string] $csvFilePath = "C:\Users\kevin3349\Downloads\VirtualMachines.csv"
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

function ProcessCsv
{
    param(
        [object] $csv
    )

    $counter = 0
    $csvObject = Import-Csv $csvFilePath | Measure-Object

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

        ./MonitoringAgentInstallation -subscription $csvData.Subscription `
        -resourceGroup $csvData.ResourceGroup `
        -virtualMachineName $csvData.VirtualMachineName `
        -workspaceId $csvData.WorkspaceId `
        -workspaceKey $csvData.WorkspaceKey
    }
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

try
{
    Write-Output "Running the script..."

    $csv = Import-Csv $csvFilePath

    $validatedCsv = ValidateCsv $csv
    ProcessCsv $validatedCsv

    Write-Output "Done running the script..."
}

catch 
{
    Write-Output $_
}