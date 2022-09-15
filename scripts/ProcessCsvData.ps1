function VerifyJobState
{
    param(
        [object] $childJob
    )

    Write-Host "=================================================="
    Write-Host "Job output for $($childJob.Name)"
    Write-Host "=================================================="

    $childJob | Receive-Job -Keep
    Write-Host "$($childJob.Name) finished executing with `"$($childJob.State)`" state"
}

function JobLogging
{
    Write-Host "Waiting for jobs to finish executing..."

    $JobTable = Get-Job | Wait-Job | Where-Object {$_.Name -like "*OnboardingJob"}
    $JobTable | ForEach-Object -Process {
        $_.ChildJobs[0].Name = $_.Name.Replace("OnboardingJob", "ChildJob")
    }

    $ChildJobs = Get-Job -IncludeChildJob | Where-Object {$_.Name -like "*ChildJob"}
    $ChildJobs | ForEach-Object -Process {
        VerifyJobState $_
    }

    $ChildJobs | Select-Object -Property Id,Name, State, PSBeginTime,PSEndTime|Format-Table
}

function VerifySubscriptionAccess
{
    param(
        [object] $csv
    )

    $csv.Subscription | Select-Object -Unique | ForEach-Object -Process {
        $account_list = az account list | ConvertFrom-Json
        $no_subscription_access = 0

        if ($account_list.name -notcontains $_)
        {
            Write-Error "You don't have access to $($_). Please check PIM"
            $no_subscription_access += 1
        }

        else 
        {
            Write-Host "$($_) is visible from your account."
        }
    }

    if ($no_subscription_access -gt 0) 
    {
        exit 1
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

try 
{
    $ErrorActionPreference = 'Continue'

    Write-Host "Initializing automation..." -ForegroundColor Green
    
    $csv = Import-Csv ".\csv\VirtualMachines.csv"
    
    ValidateCsv $csv
    VerifySubscriptionAccess $csv

    $csv | ForEach-Object -Process {
        $MMAInstallationParameters = @(
            $_.Subscription
            $_.ResourceGroup
            $_.VirtualMachineName
            $_.WorkspaceId
            $_.WorkspaceKey
        )
        Start-Job -Name "$($_.VirtualMachineName)-OnboardingJob" -FilePath .\scripts\MonitoringAgentInstallation.ps1 -ArgumentList $MMAInstallationParameters
        #Logging Function TODO: Improvements
    }

    JobLogging
    Write-Host "Done running the automation..." -ForegroundColor Green
    exit 0
}

catch 
{
    Write-Host "Catch block error:"
    $PSItem.ScriptStackTrace
}