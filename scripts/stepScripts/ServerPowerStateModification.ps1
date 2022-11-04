param(
    [string] $subscription,
    [string] $resourceGroup,
    [string] $virtualMachineName,
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
        Write-Host "##[section]Virtual Machine: $virtualMachineName has been powered on"
    }

    elseif (-not $shouldPowerOn -and $virtualMachine.powerState -eq "VM running")
    {
        az vm deallocate --name $virtualMachineName --resource-group $resourceGroup
        Write-Host "##[section]Virtual Machine: $virtualMachineName has been deallocated"
    }
}

function ValidateVirtualMachine
{
    $virtualMachine = az vm list --resource-group $resourceGroup --query "[?contains(name, '$virtualMachineName')]" -d -o json | ConvertFrom-Json

    if ($null -eq $virtualMachine)
    {
        Write-Host "##[error]No Results: Subscription - $subscription | Resource Group - $resourceGroup | Virtual Machine Name - $virtualMachineName"
        exit 1
    }

    return $virtualMachine
}

function ValidateArguments
{
    if ([string]::IsNullOrEmpty($subscription) -or 
    [string]::IsNullOrEmpty($resourceGroup) -or 
    [string]::IsNullOrEmpty($virtualMachineName))
    {
        Write-Host "##[warning]Required parameters for powering on/off servers were not properly supplied with arguments."
        exit 1
    }
}

try
{
    az account set --subscription $subscription

    ValidateArguments
    $virtualMachine = ValidateVirtualMachine

    PowerVirtualMachine $virtualMachine
}

catch
{
    exit 1
}