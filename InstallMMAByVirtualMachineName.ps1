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

function ListVirtualMachineWorkspaces
{
    param(
        [object] $virtualMachine
    )

    $getWorkspaces = az vm run-command invoke --command-id RunPowerShellScript `
    --name $virtualMachine.name `
    --resource-group $resourceGroup `
    --scripts "@run-commands/GetWorkspacesFromVirtualMachine.ps1" | ConvertFrom-Json

    $workspaceIdList = $getWorkspaces.value[0].message.Split()

    return $workspaceIdList
}

function ValidateWorkspaces
{
    param(
        [string[]] $workspaceIdList
    )

    if ($workspaceIdList.Count -gt 0 -and $workspaceIdList.Count -lt 4)
    {
        foreach ($id in $workspaceIdList)
        {
            if ($id -eq $workspaceId -and !$shouldReplaceExisting)
            {
                Write-Error "Workspace ID: $workspaceId is already connected to Virtual Machine: $virtualMachineName"
                exit 1
            }
        }
    }

    elseif ($workspaceIdList.Count -eq 4) 
    {
        Write-Error "Virtual Machine: $virtualMachineName has four (4) workspaces already"
        exit 1
    }

    return
}

function UpdateVirtualMachineWorkspaces
{
    param(
        [string[]] $workspaceIdList
    )

    if($shouldReplaceExisting)
    {
        foreach ($id in $workspaceIdList)
        {
            az vm run-command invoke --command-id RunPowerShellScript `
            --name $virtualMachineName `
            --resource-group $resourceGroup `
            --scripts "@run-commands/RemoveWorkspaceOnVirtualMachine.ps1" `
            --parameters "workspaceId=$id"
        }
    }

    az vm run-command invoke --command-id RunPowerShellScript `
    --name $virtualMachineName `
    --resource-group $resourceGroup `
    --scripts "@run-commands/AddWorkspaceOnVirtualMachine.ps1" `
    --parameters "workspaceId=$workspaceId" "workspaceKey=$workspaceKey"
}

try
{
    az account set --subscription $subscription

    $virtualMachine = GetVirtualMachineByName
    $workspaceIdList = ListVirtualMachineWorkspaces $virtualMachine

    ValidateWorkspaces $workspaceIdList
    UpdateVirtualMachineWorkspaces $workspaceIdList

    Write-Output "Workspace connected successfully"
}

catch 
{
    Write-Output $_
}