param(
    [Parameter(Mandatory=$true)]
    [string] $username,

    [Parameter(Mandatory=$true)]
    [string] $password
)

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

try {
    $ErrorActionPreference = 'Continue'
    az account clear
    az logout
    az login -u $username -p $password

    Write-Host "Initializing automation..." -ForegroundColor Green

    $csv = Import-Csv ".\csv\VirtualMachines.csv"
    ValidateCsv $csv

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
catch {
    Write-Host "Catch block error:"
    $PSItem.ScriptStackTrace
}
