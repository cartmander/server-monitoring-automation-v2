param(
    [string] $workspaceId,
    [string] $workspaceKey
)

$agent = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
$agent.AddCloudWorkspace($workspaceId, $workspaceKey)
$agent.ReloadConfiguration()