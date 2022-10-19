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

function UpdateVirtualMachineWorkspaces
{
    param(
        [string] $virtualMachineName,
        [string[]] $workspaceIdList
    )

    $shouldAddWorkspace = "true"

    if ($workspaceIdList.Count -ge 4)
    {
        Write-Error "Virtual Machine: $virtualMachineName has at least four (4) workspaces already"
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

function EvaluateWorkspaces
{
    param(
        [string] $virtualMachineName
    )

    $workspaceIdList = ListVirtualMachineWorkspaces $virtualMachineName
    UpdateVirtualMachineWorkspaces $virtualMachineName $workspaceIdList
}

function PowerVirtualMachine
{
    param(
        [bool] $shouldPowerVM
    )

    if ($shouldPowerVM)
    {
        az vm start --name $virtualMachineName --resource-group $resourceGroup
    }

    else
    {
        az vm deallocate --name $virtualMachineName --resource-group $resourceGroup --no-wait
    }
}

function ValidateVirtualMachine
{
    $virtualMachine = az vm list --resource-group $resourceGroup --query "[?contains(storageProfile.osDisk.osType, 'Windows') && contains(name, '$virtualMachineName')]" -d -o json | ConvertFrom-Json

    if ($null -eq $virtualMachine -or [string]::IsNullOrEmpty($virtualMachine.name))
    {
        Write-Error "No Results: Subscription - $subscription | Resource Group - $resourceGroup | Virtual Machine Name - $virtualMachineName"
        exit 1
    }

    return $virtualMachine
}


try
{
    az account set --subscription $subscription

    $virtualMachine = ValidateVirtualMachine
    $virtualMachineName = $virtualMachine.name

    if ($virtualMachine.powerState -ne "VM running")
    {
        PowerVirtualMachine $true
        EvaluateWorkspaces $virtualMachineName
        PowerVirtualMachine $false
    }

    else 
    {
        EvaluateWorkspaces $virtualMachineName
    }
}

catch
{
    Write-Host $_
    exit 1
}