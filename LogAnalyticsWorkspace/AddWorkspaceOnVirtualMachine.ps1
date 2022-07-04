param(
    [string] $workspaceId,
    [string] $workspaceKey
)

$newAgent = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
$newAgent.AddCloudWorkspace($workspaceId, $workspaceKey)
$newAgent.ReloadConfiguration()