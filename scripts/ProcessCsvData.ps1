param(
    [Parameter(Mandatory=$true)]
    [string] $username,

    [Parameter(Mandatory=$true)]
    [string] $password
)
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