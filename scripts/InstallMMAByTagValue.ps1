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
    [string] $workspaceKey
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
                $shouldAddWorkspace = $false

                Write-Output "Workspace ID: $workspaceId is already connected to Virtual Machine: $virtualMachineName and will not attempt to reconnect anymore"
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

        az vm run-command invoke --command-id RunPowerShellScript `
        --name $virtualMachineName `
        --resource-group $resourceGroup `
        --scripts "@run-commands/EnableMachineReadiness.ps1"

        Write-Output "Workspace ID: $workspaceId attempted to connect to Virtual Machine: $virtualMachineName"
    }
}

try
{
    Write-Output "Running the script..."

    az account set --subscription $subscription

    $virtualMachines = ValidateVirtualMachines
    
    foreach ($virtualMachine in $virtualMachines)
    {
        $workspaceIdList = ListVirtualMachineWorkspaces $virtualMachine.name
        UpdateVirtualMachineWorkspaces $virtualMachine.name $workspaceIdList
    }

    Write-Output "Done running the script..."
}

catch 
{
    Write-Output $_
}