param(
    [Parameter(Mandatory=$true)]
    [string] $username,

    [Parameter(Mandatory=$true)]
    [string] $password
)
$init = {
    function MonitoringAgentInstallation {
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

        if ($null -eq $virtualMachine -or [string]::IsNullOrEmpty($virtualMachine.name))
        {
            Write-Error "No Results: Subscription - $subscription | Resource Group - $resourceGroup | Virtual Machine Name - $virtualMachineName"
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
        --scripts "@C:\\scripts\ServerOnboardingAutomation\GetWorkspacesFromVirtualMachine.ps1" | ConvertFrom-Json

        $workspaceIdList = $getWorkspaces.value[0].message.Split()

        return $workspaceIdList
    }

    function UpdateVirtualMachineWorkspaces
    {
        param(
            [string] $virtualMachineName,
            [string[]] $workspaceIdList
        )

        $shouldAddWorkspace = "true"

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
                    $shouldAddWorkspace = "false"

                    Write-Host "Workspace ID: $workspaceId is already connected to Virtual Machine: $virtualMachineName" -ForegroundColor Yellow
                    break
                }
            }
        }

        az vm run-command invoke --command-id RunPowerShellScript `
        --name $virtualMachineName `
        --resource-group $resourceGroup `
        --scripts "@C:\\scripts\ServerOnboardingAutomation\OnboardVirtualMachine.ps1" `
        --parameters "workspaceId=$workspaceId" "workspaceKey=$workspaceKey" "shouldAddWorkspace=$shouldAddWorkspace"

        if ($shouldAddWorkspace -eq "true")
        {
            Write-Host "Workspace ID: $workspaceId has connected to Virtual Machine: $virtualMachineName" -ForegroundColor Green
        }
    }

    try
    {
        az account set --subscription $subscription

        $virtualMachine = ValidateVirtualMachine
        $virtualMachineName = $virtualMachine.name
        $workspaceIdList = ListVirtualMachineWorkspaces $virtualMachineName
        UpdateVirtualMachineWorkspaces $virtualMachineName $workspaceIdList
    }

    catch 
    {
        Write-Host $_
        exit 1
    }
}

}
function ValidateCsv
{
    param(
        [object] $csv
    )

    $requiredHeaders = "Subscription", "ResourceGroup", "VirtualMachineName", "WorkspaceId", "WorkspaceKey"
    $csvHeaders = $csv[0].PSObject.Properties.Name.Split()

    foreach ($header in $csvHeaders)
    {
        if (-not $requiredHeaders.Contains($header))
        {
            Write-Error "CSV contains invalid headers"
            exit 1
        }
    }
}

function JobLogging {
    $JobTable = Get-Job | Wait-Job | Where-Object {$_.Name -like "*OnboardingJob"}
    $JobTable | ForEach-Object -Process {
        $_.ChildJobs[0].Name = $_.Name.Replace("OnboardingJob","ChildJob")
    }
    $ChildJobs = Get-Job -IncludeChildJob | Where-Object {$_.Name -like "*ChildJob"}
    $ChildJobs | Receive-Job -Keep
    $ChildJobs | ForEach-Object -Process {
        if ($_.State -eq "Completed") {
            Write-Host "$($_.Name) finished executing with `"$($_.State)`" state" -ForegroundColor Green
        }
        elseif ($_.State -eq "Stopped") {
            Write-Host "$($_.Name) finished executing with `"$($_.State)`" state" -ForegroundColor Red
        }
        else {
            Write-Host "$($_.Name) finished executing with `"$($_.State)`" state" -ForegroundColor Yellow
        }
    }
}



try
{
    az login -u $username -p $password

    Write-Host "Initializing automation..." -ForegroundColor Green

    $csv = Import-Csv ".\csv\VirtualMachines.csv" 
    ValidateCsv $csv
    $csv | ForEach-Object -Process {
        Start-Job -Name "$($_.VirtualMachineName)OnboardingJob" -ErrorAction Stop -InitializationScript $init -ScriptBlock {
            $MMAInstallationParameters = @{
                subscription = $Using:_.Subscription
                resourceGroup = $Using:_.ResourceGroup 
                virtualMachineName = $Using:_.VirtualMachineName 
                workspaceId = $Using:_.WorkspaceId
                workspaceKey = $Using:_.WorkspaceKey
            }

            MonitoringAgentInstallation @MMAInstallationParameters
            
        }
    } 


    JobLogging

    Write-Host "Done running the automation..." -ForegroundColor Green
}

catch 
{
    Write-Output $_
}