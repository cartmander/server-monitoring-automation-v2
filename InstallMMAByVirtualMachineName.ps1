param(
    [string] $subscription,
    [string] $workspaceId,
    [string] $workspaceKey,
    [string] $resourceGroup,
    [string] $name,
    [bool] $shouldReplaceExisting = $false
)

function GetVirtualMachineByName
{
    $virtualMachine = az vm list --resource-group $resourceGroup --query "[?contains(name, '$name') &&  powerState=='VM running']" -d -o json | ConvertFrom-Json
    return $virtualMachine
}

function UpdateVirtualMachineAgents
{
    param(
        [object] $virtualMachine
    )

    foreach ($resource in $virtualMachine.resources)
    {
        if($shouldReplaceExisting -and $resource.typePropertiesType -eq "MicrosoftMonitoringAgent")
        {
            az vm extension delete -g $virtualMachine.resourceGroup --vm-name $virtualMachine.name -n $resource.name
        }
    }

    az vm run-command invoke --command-id RunPowerShellScript --name $virtualMachine.name --resource-group $resourceGroup --scripts "@AddWorkspaceOnVirtualMachine.ps1" --parameters "workspaceId=$workspaceId" "workspaceKey=$workspaceKey"
}

try
{
    az account set --subscription $subscription

    $virtualMachine = GetVirtualMachineByName
    
    UpdateVirtualMachineAgents $virtualMachine
}

catch 
{
    Write-Output $_
}