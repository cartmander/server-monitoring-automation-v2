param(
    [string] $workspaceId,
    [string] $workspaceKey,
    [string] $shouldAddWorkspace # For some reasons, run-command can't take in boolean arguments
)

begin 
{
    if ($shouldAddWorkspace -eq "true")
    {
        try
        {
            # Add Workspace on Virtual Machine
            $agent = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
            $agent.AddCloudWorkspace($workspaceId, $workspaceKey)
            $agent.ReloadConfiguration()
        }
    
        catch
        {
            Write-Warning "$($error[0].Exception.Message)"
        }
    }

    try
    {
        # Removal of Atos scheduled patching for SCCM
        $Today = [datetime]::Today.ToString('MM/dd/yyyy')
        $WTWRegPath = "HKLM:\SOFTWARE\WTW\Patching"
        $PatchSchd = "AZR-UPD-MGR-CEG"
        $RequestedBy = "Cloud Ops Team"

        if (!(Test-Path $WTWRegPath)) {
            New-Item -Name "WTW" -Path 'HKLM:\SOFTWARE\' -type Directory
            New-Item -Name "Patching" -Path 'HKLM:\SOFTWARE\WTW' -type Directory
        }

        Set-ItemProperty -Path "$WTWRegPath" -Name Patchschd -Value $PatchSchd
        Set-ItemProperty -Path "$WTWRegPath" -Name RequestDate -Value $Today
        Set-ItemProperty -Path "$WTWRegPath" -Name RequestedBy -Value $RequestedBy
        Set-ItemProperty -Path "$WTWRegPath" -Name ChangeStamp -Value $Today
    }

    catch
    {
        Write-Warning "$($error[0].Exception.Message)"
    }
}

process
{
    # Enable Machine Readiness
    try 
    {
        $StoppingServiceTime = (Get-Date).AddSeconds(30)

        do 
        {
            Stop-Service HealthService -Verbose
            Write-Host "Waiting for Service to be stopped completely before continuing"
            $ServiceStatus = (Get-Service -Name HealthService).Status
        } 
        until ($ServiceStatus -eq "Stopped" -or (New-TimeSpan -End $StoppingServiceTime))
    }

    catch 
    {
        Write-Host "$($error[0].Exception.Message)"
    }

    Write-Host "HealthService is now $ServiceStatus, SCOM monitoring will be stopped as well." -ForegroundColor Yellow

    try 
    {
        Remove-Item `
            -path "HKLM:\SOFTWARE\Microsoft\HybridRunbookWorker" `
            -Recurse `
            -Force `
            -ErrorAction Stop
    }

    catch 
    { 
        Write-Warning "$($error[0].Exception.Message)"
    }

    try 
    {
        $currentuser = whoami.exe
        $acl = Get-Acl "C:\Program Files\Microsoft Monitoring Agent\Agent\Health Service State"
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentuser, "FullControl", "Allow")
        $acl.SetAccessRule($AccessRule)
        $acl | Set-Acl "C:\Program Files\Microsoft Monitoring Agent\Agent\Health Service State"


        Remove-Item `
            -Path "C:\Program Files\Microsoft Monitoring Agent\Agent\Health Service State" `
            -Recurse `
            -Force `
            -ErrorAction Stop
    }

    catch 
    {
        Write-Warning "$($error[0].Exception.Message)"
    }

    try 
    {
        $StartingServiceTime = (Get-Date).AddSeconds(30)

        do 
        {
            Start-Service HealthService
            Write-Host "Waiting for HealthService to be started completely before continuing"
            $StartedServiceStatus = (Get-Service -Name HealthService).Status
        } 
        until ($StartedServiceStatus -eq "Running" -or (New-TimeSpan -End $StartingServiceTime))
    }

    catch 
    {
        Write-Host "$($error[0].Exception.Message)"
    }

    Write-Host "HealthService is now $($StartedServiceStatus) , SCOM monitoring will be resumed as well." -ForegroundColor Green
    
}

end
{
    Write-Host "Script completed. Please check the Azure Automation account SYSTEM Hybrid workers" -ForegroundColor Green
}