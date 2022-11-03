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
    [string] $workspaceKey,

    [Parameter(Mandatory=$true)]
    [string] $hasPowerStateCycling
)

function InstallLinuxWorkspace
{
    param(
        [object] $virtualMachine
    )

    foreach ($resource in $virtualMachine.resources)
    {
        if ($resource.typePropertiesType -eq "OmsAgentForLinux")
        {
            Write-Host "Virtual Machine: $virtualMachineName (Linux) is already connected to a workspace and will attempt to disconnect"
            
            az vm extension delete --resource-group $virtualMachine.resourceGroup --vm-name $virtualMachine.name --name $resource.name
            
            Write-Host "Virtual Machine: $virtualMachineName (Linux) has been disconnected from its previous workspace"
        }
    }

    $protected_settings = "{'workspaceKey': '$workspaceKey'}"
    $settings = "{'workspaceId': '$workspaceId'}"

    az vm extension set `
    --resource-group $resourceGroup `
    --vm-name $virtualMachineName `
    --name "OmsAgentForLinux" `
    --publisher "Microsoft.EnterpriseCloud.Monitoring" `
    --protected-settings $protected_settings `
    --settings $settings `
    --version "1.13"

    Write-Host "Workspace ID: $workspaceId has connected to Virtual Machine: $virtualMachineName (Linux)" -ForegroundColor Green
}

function InstallWindowsWorkspace
{
    param(
        [string] $virtualMachineName,
        [string[]] $workspaceIdList
    )

    $shouldAddWorkspace = "true"

    if ($workspaceIdList.Count -ge 4)
    {
        Write-Error "Virtual Machine: $virtualMachineName (Windows) has at least four (4) workspaces already"
        return
    }

    if ($workspaceIdList.Count -gt 0)
    {
        foreach ($id in $workspaceIdList)
        {
            if ($id -eq $workspaceId)
            {
                $shouldAddWorkspace = "false"

                Write-Host "Workspace ID: $workspaceId is already connected to Virtual Machine: $virtualMachineName (Windows)" -ForegroundColor Yellow
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
        Write-Host "Workspace ID: $workspaceId has connected to Virtual Machine: $virtualMachineName (Windows)" -ForegroundColor Green
    }
}

function ListWindowsWorkspaces
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

function EvaluateVirtualMachine
{
    param(
        [object] $virtualMachine
    )

    $osType = $virtualMachine.storageProfile.osDisk.osType

    if ($osType -eq "Windows")
    {
        $workspaceIdList = ListWindowsWorkspaces $virtualMachineName
        InstallWindowsWorkspace $virtualMachineName $workspaceIdList
    }

    elseif ($osType -eq "Linux")
    {
        InstallLinuxWorkspace $virtualMachine
    }
}

function PowerVirtualMachine
{
    param(
        [bool] $shouldPowerVM
    )

    if ($shouldPowerVM)
    {
        az vm start --name $virtualMachineName --resource-group $resourceGroup
        Write-Host "Virtual Machine: $virtualMachineName has been powered on"
    }

    else
    {
        az vm deallocate --name $virtualMachineName --resource-group $resourceGroup --no-wait
        Write-Host "Virtual Machine: $virtualMachineName is being deallocated"
    }
}

function ValidateVirtualMachine
{
    $virtualMachine = az vm list --resource-group $resourceGroup --query "[?contains(name, '$virtualMachineName')]" -d -o json | ConvertFrom-Json

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

    if ($hasPowerStateCycling -eq "true" -and $virtualMachine.powerState -ne "VM running")
    {
        PowerVirtualMachine $true
        EvaluateVirtualMachine $virtualMachine
        PowerVirtualMachine $false
    }

    else 
    {
        EvaluateVirtualMachine $virtualMachine
    }
}

catch
{
    Write-Host $_
    exit 1
}