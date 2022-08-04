begin {
    try {
        Stop-Service HealthService -Verbose
    }
    catch {
        Write-Error "$($error[0].Exception.Message)"
        Write-Host "Stopping script. We need to stop the HealthService properly."
        Break
    }

    $StoppingServiceTime = (Get-Date).AddSeconds(30)
    do {
        Write-Host "Waiting for Service to be stopped completely before continuing"
        $ServiceStatus = (Get-Service -Name HealthService).Status
    } until ($ServiceStatus -eq "Stopped" -or (New-TimeSpan -End $StoppingServiceTime))

    Write-Host "HealtService is now $ServiceStatus, SCOM monitoring will be stopped as well." -ForegroundColor Yellow
}

process {
    Try {
        Remove-Item `
            -path "HKLM:\SOFTWARE\Microsoft\HybridRunbookWorker" `
            -Recurse `
            -Force `
            -ErrorAction Stop
    }
    catch { 
        Write-Warning "$($error[0].Exception.Message)"
    }

    Try {

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
    catch {
        Write-Warning "$($error[0].Exception.Message)"
    }

    $StartingServiceTime = (Get-Date).AddSeconds(30)
    Start-Service HealthService
    do {
        Write-Host "Waiting for HealthService to be started completely before continuing"
        $StartedServiceStatus = (Get-Service -Name HealthService).Status
    } until ($StartedServiceStatus -eq "Running" -or (New-TimeSpan -End $StartingServiceTime))

    Write-Host "HealtService is now $($StartedServiceStatus) , SCOM monitoring will be resumed as well." -ForegroundColor Green
}


end {
    Write-Host "Script completed. Please check the Azure Automation account SYSTEM Hybrid workers" -ForegroundColor Green
}