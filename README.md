# Server Onboarding Automation

This is the unofficial Server Onboarding tool (testing phase)

## How to Use?: Repository

Make sure you branch out from "feature/AutoOnboarding" branch by going to the branch dropdown and selecting "+ New Branch".

Provide the following:
- Name - feature/{your_name}{date}{time} (ex. feature/Kevin82020221227PM)
- Based on - feature/AutoOnboarding

## Creating a list of servers to onboard:
- Open a csv on your local, then plot out the necessary servers to onboard. You may download the csv in the repository to know the properties that you need to provide.
- Save the csv, then edit it on a notepad, then copy everything.
- Go back to the repository and look for "csv/VirtualMachines.csv". 
- Go to the file and paste in the csv contents you copied.
- Click commit to save the changes under your newly created branch.

## How to Use?: Pipeline
Go to the designated pipeline of this repository:
https://dev.azure.com/wtw-irrndg/Indigo%20Cloud%20Operations/_build?definitionId=241

Click Run pipeline, then provide the following values as arguments:
- Branch/tag - point to your newly created branch
- username - Your ADM username (ex. kevin3349_adm@willistowerswatson.com)
- password - Your password

In the future, we are going to use a service principal instead of using our ADM accounts.

Finally, click Run and let the pipeline run the automation and wait for it to be finished.

## Expected Output:

By the end of a pipeline run, if no errors were found along the way, you should expect the list of servers to be onboarded to its assigned Log Analytics Workspace along with a few scripts that we usually run in the portal:
- Removal of Atos scheduled patching for SCCM
- Machine Readiness

## How to Verify?:

You can verify if the servers youre onboarded properly by doing the following options:
- If the Log Analytics Workspace is connected to an Automation Account, go to the Automation Account and you should see the servers under Update management.
- You can query the servers in the Logs of Log Analytics Workspace.

## Guidelines to follow:
- Before you use the automation, make sure the necessary access is already set (ex. PIM activation). You can only onboard servers that our ADM accounts have access to. Otherwise, the automation will not see the resources.
- You can only onboard running Windows servers. Linux and stopped servers will not be onboarded.
- Run the automation with a max of 30 servers only. Though the pipeline can run up to 6 hours. It's highly recommended to onboard the servers in batches.
- When modifying a csv file, make sure to pass the actual casing of the resource groups and server names (except subscription) you see in Azure portal. For some reasons, Azure CLI queries are case-sensitive. (ex. In Azure Portal: n20-os-vscn001d, so in CSV, it should be n20-os-vscn001d as well and not N20-OS-VSCN001D)
- The pipeline has 4 agents that are running in the cloud and can run asynchronously. If all agents are busy, the following pipeline executions will have to queue and wait.
- Make sure you don't have conflicting server assignments when onboarding to avoid pipeline execution failures.