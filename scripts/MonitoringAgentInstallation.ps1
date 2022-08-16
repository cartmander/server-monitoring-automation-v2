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

function ValidateVirtualMachines
{
    $virtualMachine = az vm list --resource-group $resourceGroup --query "[?contains(storageProfile.osDisk.osType, 'Windows') && contains(name, '$virtualMachineName') &&  powerState=='VM running']" -d -o json | ConvertFrom-Json
    
    if ($null -eq $virtualMachine)
    {
        Write-Error "Query: Subscription - $subscription | Resource Group - $resourceGroup | Virtual Machine Name - $virtualMachineName"
        Write-Error "Query does not have a running Windows virtual machine or does not exist"
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

    return $shouldOnboard
}

function ListOnboardedVirtualMachine
{
    param(
        [object] $virtualMachine
    )

    $onboardedVirtualMachine = New-Object -Type PSObject -Property @{
        'ResourceGroup' = $virtualMachine.resourceGroup
        'VirtualMachineName' = $virtualMachine.name
    }


    return $onboardedVirtualMachine
}

function DisplayOnboardedVirtualMachines
{
    param(
        [object[]] $onboardedVirtualMachinesList
    )

    $vmCount = $onboardedVirtualMachinesList.Count

    if ($vmCount -ne 0)
    {
        Write-Host "List of Onboarded Virtual Machines: $vmCount virtual machines" -ForegroundColor Green
        $onboardedVirtualMachinesList | Select-Object -Property ResourceGroup,VirtualMachineName | Sort-Object -Property ResourceGroup | Format-Table
    }

    else
    {
        Write-Host "No virtual machines were onboarded" -ForegroundColor Yellow
    }
}

try
{
    az account set --subscription $subscription

    $onboardedVirtualMachinesList = @()
    $virtualMachines = ValidateVirtualMachines
    $counter = 0
    
    foreach ($virtualMachine in $virtualMachines)
    {
        Write-Progress -Activity 'Processing Virtual Machine Onboarding...' -CurrentOperation $virtualMachine.name -PercentComplete (($counter++ / $virtualMachines.Count) * 100)
        $workspaceIdList = ListVirtualMachineWorkspaces $virtualMachine.name
        $isOnboarded = UpdateVirtualMachineWorkspaces $virtualMachine.name $workspaceIdList

        if($isOnboarded)
        {
            $onboardedVirtualMachine = ListOnboardedVirtualMachine $virtualMachine
            $onboardedVirtualMachinesList += $onboardedVirtualMachine
        }
    } 

    DisplayOnboardedVirtualMachines $onboardedVirtualMachinesList
}

catch 
{
    Write-Host $_
}