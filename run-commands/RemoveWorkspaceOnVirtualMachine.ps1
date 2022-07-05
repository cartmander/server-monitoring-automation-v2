param(
    [string] $workspaceId
)

$agent = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
$agent.RemoveCloudWorkspace($workspaceId)
$agent.ReloadConfiguration()