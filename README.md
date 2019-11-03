# Icinga Powershell Framework Kickstarter

This PowerShell Script provides an easy way to get the Icinga Powershell Framework with plugins and the Icinga Agent fully installed and configured on your system.

This script downloads a PowerShell script file from either GitHub or from a custom source you provide.

Once loaded, it will be executed and asks all required questions on how and where to install the PowerShell Framework for Icinga and where to get it.

## Installation

1. Start a PowerShell with administrative privileges
2. Run the following command

```powershell
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11";
$ProgressPreference = "SilentlyContinue";

$global:IcingaFrameworkKickstartSource = 'https://raw.githubusercontent.com/Icinga/icinga-powershell-kickstart/master/script/icinga-framework-kickstart.ps1';

$Script = (Invoke-WebRequest -UseBasicParsing -Uri $global:IcingaFrameworkKickstartSource).Content;
$Script += "`r`n`r`n Start-IcingaFrameworkWizard;";

Invoke-Command -ScriptBlock ([Scriptblock]::Create($Script));
```
