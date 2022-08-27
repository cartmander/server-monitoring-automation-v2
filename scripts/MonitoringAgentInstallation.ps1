param(
    [Parameter(Mandatory=$true)]
    [string] $subscription,

    [Parameter(Mandatory=$true)]
    [string] $resourceGroup,

    [Parameter(Mandatory=$true)]
    [string] $virtualMachineName,

    [Parameter(Mandatory=$true)]
    [string] $workspaceId,

    [Parameter(Mandatory=$true)]
    [string] $workspaceKey
)

function ValidateVirtualMachine
{
    $virtualMachine = az vm list --resource-group $resourceGroup --query "[?contains(storageProfile.osDisk.osType, 'Windows') && contains(name, '$virtualMachineName') &&  powerState=='VM running']" -d -o json | ConvertFrom-Json

    if ($null -eq $virtualMachine -or [string]::IsNullOrEmpty($virtualMachine.name))
    {
        Write-Error "No Results: Subscription - $subscription | Resource Group - $resourceGroup | Virtual Machine Name - $virtualMachineName"
        Write-Error "Query does not have a running Windows virtual machine or does not exist"
        exit 1
    }

    return $virtualMachine
}

function ListVirtualMachineWorkspaces
{
    param(
        [string] $virtualMachineName
    )

    $getWorkspaces = az vm run-command invoke --command-id RunPowerShellScript `
    --name $virtualMachineName `
    --resource-group $resourceGroup `
    --scripts "@C:\\scripts\ServerOnboardingAutomation\GetWorkspacesFromVirtualMachine.ps1" | ConvertFrom-Json

    $workspaceIdList = $getWorkspaces.value[0].message.Split()

    return $workspaceIdList
}

function UpdateVirtualMachineWorkspaces
{
    param(
        [string] $virtualMachineName,
        [string[]] $workspaceIdList
    )

    $shouldAddWorkspace = "true"

    if ($workspaceIdList.Count -gt 3)
    {
        Write-Error "Virtual Machine: $virtualMachineName has more than three (3) workspaces already"
        return
    }

    if ($workspaceIdList.Count -gt 0)
    {
        foreach ($id in $workspaceIdList)
        {
            if ($id -eq $workspaceId)
            {
                $shouldAddWorkspace = "false"

                Write-Host "Workspace ID: $workspaceId is already connected to Virtual Machine: $virtualMachineName" -ForegroundColor Yellow
                break
            }
        }
    }

    az vm run-command invoke --command-id RunPowerShellScript `
    --name $virtualMachineName `
    --resource-group $resourceGroup `
    --scripts "@C:\\scripts\ServerOnboardingAutomation\OnboardVirtualMachine.ps1" `
    --parameters "workspaceId=$workspaceId" "workspaceKey=$workspaceKey" "shouldAddWorkspace=$shouldAddWorkspace"

    if ($shouldAddWorkspace -eq "true")
    {
        Write-Host "Workspace ID: $workspaceId has connected to Virtual Machine: $virtualMachineName" -ForegroundColor Green
    }
}

try
{
    az account set --subscription $subscription

    $virtualMachine = ValidateVirtualMachine
    $virtualMachineName = $virtualMachine.name
    $workspaceIdList = ListVirtualMachineWorkspaces $virtualMachineName
    UpdateVirtualMachineWorkspaces $virtualMachineName $workspaceIdList
}
catch
{
    Write-Host $_
    exit 1
}