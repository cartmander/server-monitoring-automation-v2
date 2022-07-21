# Azure Agent Installation Automation

Running this Powershell script will allow you to add or update your virtual Machine/s to a certain scope of Virtual Machines under a current subscription in Azure.
## Terraform tfvars  variables

Provide the following values in .tfvars (please see the .example file):

- Subscription - (string) The subscription to be used
- Scope Type - (string) ResourceGroup | Tag
- Scope - (string) name_of_resource_group | value_of_a_terraform_key (Ex. Terraform: [value])

- Has Log Analytics Workspace - (bool) If Log Analytics Workspace should be installed for both Windows and Linux VMs
- Log Analytics Workspace ID - (string) ID of the new Log Analytics Workspace
- Log Analytics Workspace Key - (string) Key of the new Log Analytics Workspace

- Has Azure Monitor - (bool) If Azure Monitor should be installed for both Windows and Linux VMs
## Expected Output

Whatever Agent extensions you are allowing to be installed using this automation, the old Agent extensions of the VMs of a specified scope should now be replaced by the ones you provided in .tfvars. If there are no existing Agent extensions for certain VMs, they still should have the new Agent extensions.