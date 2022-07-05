$agent = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
$getWorkspaces = $agent.GetCloudWorkspaces()

foreach ($workspace in $getWorkspaces)
{
	$workspace.workspaceId
}