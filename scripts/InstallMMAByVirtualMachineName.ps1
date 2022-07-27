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
    
    [bool] $shouldReplaceExisting = $false
)

function ValidateVirtualMachine
{
    $virtualMachine = az vm list --resource-group $resourceGroup --query "[?contains(storageProfile.osDisk.osType, 'Windows') && contains(name, '$virtualMachineName') &&  powerState=='VM running']" -d -o json | ConvertFrom-Json

    if ($null -eq $virtualMachine)
    {
        Write-Error "Virtual Machine: $virtualMachineName does not exist or is not running"
        exit 1
    }
}

function ListVirtualMachineWorkspaces
{
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
        [string[]] $workspaceIdList
    )

    $shouldAddWorkspace = $true

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
                $shouldAddWorkspace = $false
                Write-Output "Workspace ID: $workspaceId is already connected to Virtual Machine: $virtualMachineName"
                break
            }
        }
    }

    if ($shouldAddWorkspace)
    {
        az vm run-command invoke --command-id RunPowerShellScript `
        --name $virtualMachineName `
        --resource-group $resourceGroup `
        --scripts "@run-commands/AddWorkspaceOnVirtualMachine.ps1" `
        --parameters "workspaceId=$workspaceId" "workspaceKey=$workspaceKey"
    }
}

try
{
    Write-Output "Running the script..."

    az account set --subscription $subscription

    ValidateVirtualMachine

    $workspaceIdList = ListVirtualMachineWorkspaces
    UpdateVirtualMachineWorkspaces $workspaceIdList

    Write-Output "Done running the script..."
}

catch 
{
    Write-Output $_
}