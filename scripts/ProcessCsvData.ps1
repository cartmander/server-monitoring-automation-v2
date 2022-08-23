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
}

function ProcessCsvRow
{
    param(
        [object] $csv
    )


        .\scripts\MonitoringAgentInstallation.ps1 `
        -subscription $csvData.Subscription `
        -resourceGroup $csvData.ResourceGroup `
        -virtualMachineName $csvData.VirtualMachineName `
        -workspaceId $csvData.WorkspaceId `
        -workspaceKey $csvData.WorkspaceKey `
        -currentCount $counter `
        -total $csvObject.Count
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