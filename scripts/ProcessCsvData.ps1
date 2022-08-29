param(
    [Parameter(Mandatory=$true)]
    [string] $username,

    [Parameter(Mandatory=$true)]
    [string] $password
)

function VerifyJobState
{
    param(
        [object] $ChildJobs
    )

    $ChildJobs | ForEach-Object -Process 
    {
        Write-Host "=================================================="
        Write-Host "Job output for $($_.Name)"
        Write-Host "=================================================="

        $_ | Receive-Job -Keep
        if ($state -eq "Completed") 
        {
            Write-Host "$($_.Name) finished executing with `"$($_.State)`" state" -ForegroundColor Green
        }
    
        elseif ($_.State -eq "Stopped") 
        {
            Write-Host "$($_.Name) finished executing with `"$($_.State)`" state" -ForegroundColor Red
        }
        
        else 
        {
            Write-Host "$($_.Name.Replace('ChildJob','')) finished executing with `"$($_.State)`" state" -ForegroundColor Yellow
        }
    }
}

function JobLogging 
{
    Write-Host "Waiting for jobs to finish executing..."

    $JobTable = Get-Job | Wait-Job | Where-Object {$_.Name -like "*OnboardingJob"}
    $JobTable | ForEach-Object -Process 
    {
        $_.ChildJobs[0].Name = $_.Name.Replace("OnboardingJob", "ChildJob")
    }

    $ChildJobs = Get-Job -IncludeChildJob | Where-Object {$_.Name -like "*ChildJob"}

    VerifyJobState $ChildJobs

    $ChildJobs | Select-Object -Property Id, Name, State, PSBeginTime, PSEndTime | Format-Table
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
    az login -u $username -p $password

    Write-Host "Initializing automation..." -ForegroundColor Green
    
    $csv = Import-Csv ".\csv\VirtualMachines.csv"
    ValidateCsv $csv

    $csv | ForEach-Object -Process 
    {
        $MMAInstallationParameters = @(
            $_.Subscription
            $_.ResourceGroup
            $_.VirtualMachineName
            $_.WorkspaceId
            $_.WorkspaceKey
        )
        Start-Job -Name "$($_.VirtualMachineName)OnboardingJob" -ErrorAction Stop -FilePath .\scripts\MonitoringAgentInstallation.ps1 -ArgumentList $MMAInstallationParameters
        #Logging Function TODO: Improvements
    }

    JobLogging

    Write-Host "Done running the automation..." -ForegroundColor Green
}
catch 
{
    Write-Host $_
    exit $LASTEXITCODE
}