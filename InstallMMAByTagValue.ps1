param(
    [Parameter(Mandatory=$true)]
    [string] $subscription,

    [Parameter(Mandatory=$true)]
    [string] $resourceGroup,

    [Parameter(Mandatory=$true)]
    [string] $tagValue,

    [Parameter(Mandatory=$true)]
    [string] $workspaceId,

    [Parameter(Mandatory=$true)]
    [string] $workspaceKey,
    
    [bool] $shouldReplaceExisting = $false
)

function ValidateVirtualMachines
{
    $virtualMachines = az vm list --resource-group $resourceGroup --query "[?contains(storageProfile.osDisk.osType, 'Windows') && tags.Onboarding == '$tagValue' && powerState=='VM running']" -d -o json | ConvertFrom-Json
    
    if ($null -eq $virtualMachines)
    {
        Write-Error "Tag Value: $tagValue does not exist or does not have a running Windows virtual machine"
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

    $shouldAddWorkspace = $true

    if ($workspaceIdList.Count -eq 4 -and !$shouldReplaceExisting) 
    {
        Write-Error "Virtual Machine: $virtualMachineName has four (4) workspaces already"
        break
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

    if ($workspaceIdList.Count -lt 4 -and $shouldAddWorkspace)
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
    Write-Output "Running the script"
    
    az account set --subscription $subscription

    $virtualMachines = ValidateVirtualMachines
    
    foreach ($virtualMachine in $virtualMachines)
    {
        $workspaceIdList = ListVirtualMachineWorkspaces $virtualMachine.name
        UpdateVirtualMachineWorkspaces $virtualMachine.name $workspaceIdList
    }

    Write-Output "Done running the script"
}

catch 
{
    Write-Output $_
}