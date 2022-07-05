param(
    [string] $subscription,
    [string] $workspaceId,
    [string] $workspaceKey,
    [string] $resourceGroup,
    [string] $virtualMachineName,
    [bool] $shouldReplaceExisting = $false
)

function GetVirtualMachineByName
{
    $virtualMachine = az vm list --resource-group $resourceGroup --query "[?contains(name, '$virtualMachineName') &&  powerState=='VM running']" -d -o json | ConvertFrom-Json

    if ($null -ne $virtualMachine)
    {
        return $virtualMachine
    }

    else
    {
        Write-Error "Virtual Machine: $virtualMachineName does not exist or is not running"
        exit 1
    }
    
}

function GetVirtualMachineWorkspaces
{
    param(
        [object] $virtualMachine
    )

    $getWorkspaces = az vm run-command invoke --command-id RunPowerShellScript --name $virtualMachine.name --resource-group $resourceGroup --scripts "@GetWorkspacesFromVirtualMachine.ps1" | ConvertFrom-Json
    $agents = $getWorkspaces.value[0].message
    
    return $agents
}

function UpdateVirtualMachineWorkspaces
{
    param(
        [object] $virtualMachine
    )

    foreach ($resource in $virtualMachine.resources)
    {
        if ($shouldReplaceExisting -and $resource.typePropertiesType -eq "MicrosoftMonitoringAgent")
        {
            az vm extension delete -g $virtualMachine.resourceGroup --vm-name $virtualMachine.name -n $resource.name
        }
    }

    az vm run-command invoke --command-id RunPowerShellScript --name $virtualMachine.name --resource-group $resourceGroup --scripts "@AddWorkspaceOnVirtualMachine.ps1" --parameters "workspaceId=$workspaceId" "workspaceKey=$workspaceKey"
}

try
{
    az account set --subscription $subscription

    $virtualMachine = GetVirtualMachineByName

    $agents = GetVirtualMachineWorkspaces $virtualMachine
    
    if ($agents -like "*$workspaceId*")
    {
        Write-Host "Workspace ID: $workspaceId is already connected to Virtual Machine: $virtualMachineName"
    }

    else
    {
        UpdateVirtualMachineWorkspaces $virtualMachine
    }
}

catch 
{
    Write-Output $_
}