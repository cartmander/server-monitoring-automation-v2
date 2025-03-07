# Server Onboarding Automation

This is the official Server Onboarding tool

## How to Use: Repository

Make sure you branch out from "master" branch by going to the branch dropdown and selecting "+ New Branch".

Provide the following:
- Name - feature/{your_name}
- Based on - master

## Creating a list of servers to onboard:
- Open a csv on your local, then plot out the necessary servers to onboard. You may download the csv in the repository to know the properties that you need to provide.
- Save the csv, then edit it on a notepad, then copy everything.
- Go back to the repository and look for "csv/VirtualMachines.csv". 
- Go to the file and paste in the csv contents you copied.
- Click commit to save the changes under your newly created branch.

## How to Use: Pipeline
Go to this variable group and set your ADM account and password. Don't forget to lock and save to encrypt your password:
https://dev.azure.com/wtw-irrndg/Indigo%20Cloud%20Operations/_library?itemType=VariableGroups&view=VariableGroupView&variableGroupId=48&path=SERVER-ONBOARDING-VARS

Next, go to the designated pipeline of this repository:
https://dev.azure.com/wtw-irrndg/Indigo%20Cloud%20Operations/_build?definitionId=241

Click Run pipeline, then provide the following values as arguments:
- Branch/tag - point to your newly created branch
- username - Your ADM username (ex. kevin3349_adm@willistowerswatson.com)

Choose the operation that you would like to perform:
- Power On Servers - powers on all servers
- Power Off Servers - powers off all servers
- Onboard Servers - onboards servers (assuming all servers are already up and running)
- Power On, Onboard, Power Off Servers - performs all three actions

Finally, click Run and let the pipeline run the automation and wait for it to be finished.

## Expected Output:

By the end of a pipeline run, if no errors were found, you should expect the list of servers to be onboarded to their assigned Log Analytics Workspace. The following scripts that we usually run on servers in the portal should have executed as well:
- Power On/Off servers
- Removal of Atos scheduled patching for SCCM
- Machine Readiness

## How to Verify:

You can verify if the servers were onboarded properly by doing the following options:
- Check in Azure if the servers were actually powered off/on 
- If the Log Analytics Workspace is connected to an Automation Account, go to the Automation Account and you should see the servers under Update management.
- You can query the servers in the Logs of Log Analytics Workspace.

## Guidelines to Follow:
- Before you use the automation, make sure the necessary access has already been set (ex. PIM activation). You can only onboard servers that our ADM accounts have access to. Otherwise, the automation will not see the resources.
- Your ADM account password is not yet expired.
- When modifying a csv file, make sure to pass the actual casing of the resource groups and server names (except subscription) you see in Azure portal. For some reasons, Azure CLI queries are case-sensitive. (ex. In Azure Portal: n20-os-vscn001d, so in CSV, it should be n20-os-vscn001d as well and not N20-OS-VSCN001D)
- The pipeline has 3 agents that are running in the cloud and can run asynchronously. If all agents are busy, the following pipeline executions will have to queue and wait.
- Make sure you don't have conflicting server assignments when onboarding to avoid pipeline execution failures.