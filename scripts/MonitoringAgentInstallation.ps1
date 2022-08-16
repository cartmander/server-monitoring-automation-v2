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
    
    if ($null -eq $virtualMachine)
    {
        Write-Error "Query: Subscription - $subscription | Resource Group - $resourceGroup | Virtual Machine Name - $virtualMachineName"
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

                Write-Host "Workspace ID: $workspaceId is already connected to Virtual Machine: $virtualMachineName" -ForegroundColor Yellow
                break
            }
        }
    }

    $shouldOnboard = $workspaceIdList.Count -lt 4 -and $shouldAddWorkspace

    if ($shouldOnboard)
    {
        az vm run-command invoke --command-id RunPowerShellScript `
        --name $virtualMachineName `
        --resource-group $resourceGroup `
        --scripts "@run-commands/OnboardVirtualMachine.ps1" `
        --parameters "workspaceId=$workspaceId" "workspaceKey=$workspaceKey"

        az vm run-command invoke --command-id RunPowerShellScript `
        --name $virtualMachineName `
        --resource-group $resourceGroup `
        --scripts "@run-commands/EnableMachineReadiness.ps1"

        Write-Host "Workspace ID: $workspaceId has connected to Virtual Machine: $virtualMachineName" -ForegroundColor Green
    }

    return $x
}

function DisplayOnboardedVirtualMachine
{
    param(
        [string] $virtualMachineName,
        [bool] $x
    )

    if ($x)
    {
        Write-Host "Onboarded Virtual Machine:" -ForegroundColor Green
        $virtualMachineName | Select-Object -Property ResourceGroup,VirtualMachineName | Sort-Object -Property ResourceGroup | Format-Table
    }

    else
    {
        Write-Host "Virtual machine: $virtualMachineName was not onboarded" -ForegroundColor Yellow
    }
}

try
{
    az account set --subscription $subscription

    $virtualMachine = ValidateVirtualMachine
    $virtualMachineName = $virtualMachine.name

    Write-Host "Onboarding in progress for virtual machine: $virtualMachineName..." -ForegroundColor Cyan
    $workspaceIdList = ListVirtualMachineWorkspaces $virtualMachineName
    $x = UpdateVirtualMachineWorkspaces $virtualMachineName $workspaceIdList

    DisplayOnboardedVirtualMachine $virtualMachineName $x
}

catch 
{
    Write-Host $_
}