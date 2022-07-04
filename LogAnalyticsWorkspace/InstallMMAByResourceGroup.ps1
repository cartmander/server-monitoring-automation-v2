param(
    [string] $subscription,
    [string] $workspaceId,
    [string] $workspaceKey,
    [string] $resourceGroup,
    [bool] $shouldReplaceExisting = $false
)

function GetVirtualMachinesByResourceGroup
{
    $virtualMachines = az vm list --resource-group $resourceGroup --query "[?powerState=='VM running']" -d -o json | ConvertFrom-Json
    return $virtualMachines
}

function UpdateVirtualMachineAgents
{
    param(
        [object] $virtualMachines
    )

    foreach ($virtualMachine in $virtualMachines)
    {
        foreach ($resource in $virtualMachine.resources)
        {
            if($shouldReplaceExisting -and $resource.typePropertiesType -eq "MicrosoftMonitoringAgent")
            {
                az vm extension delete -g $virtualMachine.resourceGroup --vm-name $virtualMachine.name -n $resource.name
            }
        }

        az vm run-command invoke --command-id RunPowerShellScript --name $virtualMachine.name --resource-group $resourceGroup --scripts "@AddWorkspaceOnVirtualMachine.ps1" --parameters "workspaceId=$workspaceId" "workspaceKey=$workspaceKey"
    }
}

try
{
    az account set --subscription $subscription

    $virtualMachines = GetVirtualMachinesByResourceGroup
    
    UpdateVirtualMachineAgents $virtualMachines
}

catch 
{
    Write-Output $_
}
