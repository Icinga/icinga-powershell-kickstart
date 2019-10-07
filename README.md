# Icinga Framework Kickstarter

This PowerShell Script will provide an easy way to get the Icinga Framework including the Agent fully installed and configured on your system.

This Script will download a PowerShell script file from either GitHub or from a custom source you provide.

Once loaded, it will be executed and asking you plenty of questions on how and where to install the PowerShell Framework for Icinga and where to get it.

## Installation

1. Start a PowerShell with administrative privileges
2. Run the following command

```powershell
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11";
$ProgressPreference = "SilentlyContinue";

$Script = (Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/LordHepipud/icinga-framework-kickstart/master/script/icinga-framework-kickstart.ps1').Content;

Invoke-Command -ScriptBlock ([Scriptblock]::Create($Script));
```
