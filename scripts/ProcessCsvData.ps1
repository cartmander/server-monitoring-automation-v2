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
}

try
{
    Write-Output "Running the script..."

    $csv = Import-Csv $csvFilePath

    ValidateCsv $csv

    foreach ($data in $csv)
    { 
        $column = $data | Get-Member -MemberType Properties
        
        $object = @{
            "Subscription" = $null
            "ResourceGroup" = $null
            "VirtualMachine" = $null
            "WorkspaceId" = $null
            "WorkspaceKey" = $null
        }

        for($i = 0; $i -lt $column.Count; $i++)
        {
            $columnName = $column[$i].Name
            $columnValue = $data | Select-Object -ExpandProperty $columnName

            #Create an object with onboarding properties
        }

        ./MonitoringAgentInstallation -resourceGroup
    }

    Write-Output "Done running the script..."
}

catch 
{
    Write-Output $_
}