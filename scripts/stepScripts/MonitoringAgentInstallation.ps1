param(
    [string] $subscription,
    [string] $resourceGroup,
    [string] $virtualMachineName,
    [string] $workspaceId,
    [string] $workspaceKey
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
            Write-Host "##[warning]Virtual Machine: $virtualMachineName (Linux) is already connected to a workspace and will attempt to disconnect"
            
            az vm extension delete --resource-group $virtualMachine.resourceGroup --vm-name $virtualMachine.name --name $resource.name
            
            Write-Host "##[warning]Virtual Machine: $virtualMachineName (Linux) has been disconnected from its previous workspace"
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

    Write-Host "##[section]Workspace ID: $workspaceId has connected to Virtual Machine: $virtualMachineName (Linux)"
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
        Write-Host "##[warning]Virtual Machine: $virtualMachineName (Windows) has at least four (4) workspaces already"
        return
    }

    if ($workspaceIdList.Count -gt 0)
    {
        foreach ($id in $workspaceIdList)
        {
            if ($id -eq $workspaceId)
            {
                $shouldAddWorkspace = "false"

                Write-Host "##[warning]Workspace ID: $workspaceId is already connected to Virtual Machine: $virtualMachineName (Windows)"
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
        Write-Host "##[section]Workspace ID: $workspaceId has connected to Virtual Machine: $virtualMachineName (Windows)"
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

function ValidateVirtualMachine
{
    $virtualMachine = az vm list --resource-group $resourceGroup --query "[?contains(name, '$virtualMachineName')  &&  powerState=='VM running']" -d -o json | ConvertFrom-Json

    if ($null -eq $virtualMachine)
    {
        Write-Host "##[error]No Results: Subscription - $subscription | Resource Group - $resourceGroup | Virtual Machine Name - $virtualMachineName"
        Write-Host "##[error]Either the server does not exist or is not on a running state. Make sure you have the right privileges to read resources"
        exit 1
    }

    return $virtualMachine
}

function ValidateArguments
{
    if ([string]::IsNullOrEmpty($subscription) -or
    [string]::IsNullOrEmpty($resourceGroup) -or 
    [string]::IsNullOrEmpty($virtualMachineName) -or 
    [string]::IsNullOrEmpty($workspaceId) -or 
    [string]::IsNullOrEmpty($workspaceKey))
    {
        Write-Host "##[error]Required parameters for onboarding servers were not properly supplied with arguments"
        exit 1
    }
}

try
{
    az account set --subscription $subscription

    ValidateArguments
    $virtualMachine = ValidateVirtualMachine

    EvaluateVirtualMachine $virtualMachine
}

catch
{
    exit 1
}