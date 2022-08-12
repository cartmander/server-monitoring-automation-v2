param(
    [string] $workspaceId,
    [string] $workspaceKey
)
begin
{
    Write-Host ""
}

process
{
    # Add Workspace on Virtual Machine
    $agent = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
    $agent.AddCloudWorkspace($workspaceId, $workspaceKey)
    $agent.ReloadConfiguration()

    # Remove From SCCM Collection
    $Today = [datetime]::Today.ToString('MM/dd/yyyy')
    $WTWRegPath = "HKLM:\SOFTWARE\WTW\Patching"
    $PatchSchd = "AZR-UPD-MGR"
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

end
{

}

