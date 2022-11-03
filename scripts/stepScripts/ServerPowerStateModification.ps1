param(
    [Parameter(Mandatory=$true)]
    [string] $subscription,

    [Parameter(Mandatory=$true)]
    [string] $resourceGroup,

    [Parameter(Mandatory=$true)]
    [string] $virtualMachineName,

    [Parameter(Mandatory=$true)]
    [bool] $shouldPowerOn
)

function PowerVirtualMachine
{
    param(
        [object] $virtualMachine
    )

    if ($shouldPowerOn -and $virtualMachine.powerState -ne "VM running")
    {
        az vm start --name $virtualMachineName --resource-group $resourceGroup
        Write-Host "Virtual Machine: $virtualMachineName has been powered on"
    }

    elseif (-not $shouldPowerOn -and $virtualMachine.powerState -eq "VM running")
    {
        az vm deallocate --name $virtualMachineName --resource-group $resourceGroup
        Write-Host "Virtual Machine: $virtualMachineName has been deallocated"
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

    PowerVirtualMachine $virtualMachine
}

catch
{
    Write-Host $_
    exit 1
}