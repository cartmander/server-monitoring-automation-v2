param(
    [string] $subscription,
    [string] $workspaceId,
    [string] $workspaceKey,
    [string] $resourceGroup,
    [bool] $shouldReplaceExisting = $false
)

function ValidateVirtualMachines
{
    $virtualMachines = az vm list --resource-group $resourceGroup --query "[?powerState=='VM running']" -d -o json | ConvertFrom-Json
    
    if ($null -eq $virtualMachines)
    {
        Write-Error "Resource Group: $resourceGroup does not exist or does not have a running virtual machine"
        exit 1
    }

    return $virtualMachines
}

function ListVirtualMachineWorkspaces
{
    param(
        [string] $virtualMachineName
    )

    $getWorkspaces = az vm run-command invoke --command-id RunPowerShellScript `
    --name $virtualMachineName `
    --resource-group $resourceGroup `
    --scripts "@run-commands/GetWorkspacesFromVirtualMachine.ps1" | ConvertFrom-Json

    $workspaceIdList = $getWorkspaces.value[0].message.Split()

    return $workspaceIdList
}

function UpdateVirtualMachineWorkspaces
{
    param(
        [string] $virtualMachineName,
        [string[]] $workspaceIdList
    )

    if ($workspaceIdList.Count -eq 4 -and !$shouldReplaceExisting) 
    {
        Write-Error "Virtual Machine: $virtualMachineName has four (4) workspaces already"
        exit 1
    }

    if ($workspaceIdList.Count -gt 0)
    {
        foreach ($id in $workspaceIdList)
        {
            if ($shouldReplaceExisting)
            {
                az vm run-command invoke --command-id RunPowerShellScript `
                --name $virtualMachineName `
                --resource-group $resourceGroup `
                --scripts "@run-commands/RemoveWorkspaceOnVirtualMachine.ps1" `
                --parameters "workspaceId=$id"
            }

            elseif ($id -eq $workspaceId -and !$shouldReplaceExisting)
            {
                Write-Output "Workspace ID: $workspaceId is already connected to Virtual Machine: $virtualMachineName"
            }
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

    $virtualMachines = ValidateVirtualMachines
    
    foreach ($virtualMachine in $virtualMachines)
    {
        $workspaceIdList = ListVirtualMachineWorkspaces $virtualMachine.name
        UpdateVirtualMachineWorkspaces $virtualMachine.name $workspaceIdList
    }
}

catch 
{
    Write-Output $_
}
