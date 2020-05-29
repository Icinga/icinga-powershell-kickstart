function Start-IcingaFrameworkWizard()
{
    param(
        $RepositoryUrl       = $null,
        $ModuleDirectory     = $null,
        $AllowUpdate         = $null,
        [switch]$SkipWizard
    );

    if ((Test-AdministrativeShell) -eq $FALSE) {
        Write-IcingaConsoleError 'Please run this script from an administrative shell.';
        return;
    }

    [array]$InstallerArguments = @();

    # Ensure we ca communicate with GitHub
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11";
    # Disable the status bar as it will slow down the progress
    $ProgressPreference = "SilentlyContinue";

    if ([string]::IsNullOrEmpty($RepositoryUrl)) {
        if ((Read-IcingaWizardAnswerInput -Prompt 'Do you provide an own repository for the Icinga PowerShell Framework?' -Default 'n').result -eq 1) {
            $branch = (Read-IcingaWizardAnswerInput -Prompt 'Which version of the Icinga PowerShell Framework do you want to install? (release/snapshot)' -DefaultInput 'release' -Default 'v').answer;
            if ($branch.ToLower() -eq 'snapshot') {
                $RepositoryUrl = 'https://github.com/Icinga/icinga-powershell-framework/archive/master.zip';
            } else {
                $LatestRelease = (Invoke-WebRequest -Uri 'https://github.com/Icinga/icinga-powershell-framework/releases/latest' -UseBasicParsing).BaseResponse.ResponseUri.AbsoluteUri;
                $RepositoryUrl = $LatestRelease.Replace('/releases/tag/', '/archive/');
                $Tag           = $RepositoryUrl.Split('/')[-1];
                $RepositoryUrl = [string]::Format('{0}/{1}.zip', $RepositoryUrl, $Tag);
            }
        } else {
            $RepositoryUrl = (Read-IcingaWizardAnswerInput -Prompt 'Please enter the full path of the custom repository for the Icinga PowerShell Framework (location of zip file)' -Default 'v').answer
        }
        $InstallerArguments += "RepositoryUrl '$RepositoryUrl'";
    }

    if ([string]::IsNullOrEmpty($ModuleDirectory)) {
        $ModulePath   = ($Env:PSModulePath).Split(';');
        $DefaultIndex = $ModulePath.IndexOf('C:\Program Files\WindowsPowerShell\Modules');
        $Question     = [string]::Format('The following directories are available for installing PowerShell modules into:{0}', "`r`n");
        $Index        = 0;
        $ChoosenIndex = 0;
        foreach ($entry in $ModulePath) {
            if ([int]$DefaultIndex -eq [int]$Index) {
                $Question = [string]::Format('{0}[{1}]: {2} (Recommended){3}', $Question, $Index, $entry, "`r`n");
            } else {
                $Question = [string]::Format('{0}[{1}]: {2}{3}', $Question, $Index, $entry, "`r`n");
            }
            $Index   += 1;
        }

        $Question = [string]::Format('{0}Where do you want to install the Icinga PowerShell Framework into? ([0-{1}])', $Question, ($ModulePath.Count - 1));
        
        while ($TRUE) {
            $ChoosenIndex = (Read-IcingaWizardAnswerInput -Prompt $Question -DefaultInput $DefaultIndex -Default 'v').answer
            if ([string]::IsNullOrEmpty($ChoosenIndex) -Or $null -eq $ModulePath[$ChoosenIndex]) {
                Write-IcingaConsoleError ([string]::Format('Invalid option. Please choose between [0-{0}]', ($ModulePath.Count - 1)));
                continue;
            }
            break;
        }
        $ModuleDirectory = $ModulePath[$ChoosenIndex];
        $InstallerArguments += "ModuleDirectory '$ModuleDirectory'";
    }

    $InstallerArguments += "SkipWizard";

    $DownloadPath = (Join-Path -Path $ENv:TEMP -ChildPath 'icinga-powershell-framework-zip');
    Write-IcingaConsoleNotice ([string]::Format('Downloading Icinga PowerShell Framework into "{0}"', $DownloadPath));

    Invoke-WebRequest -UseBasicParsing -Uri $RepositoryUrl -OutFile $DownloadPath;

    Write-IcingaConsoleNotice ([string]::Format('Installing Icinga PowerShell Framework into "{0}"', ($ModuleDirectory)));
    $ModuleDir = Expand-IcingaFrameworkArchive -Path $DownloadPath -Destination $ModuleDirectory -AllowUpdate $AllowUpdate;
    if ($null -ne $ModuleDir) {
        $InstallerArguments += "AllowUpdate 1";
        Unblock-IcingaFramework -Path $ModuleDir;
        try {
            # First import the module into our current shell
            if ((Test-Path $ModuleDir)) {
                Import-Module (Join-Path -Path $ModuleDir -ChildPath 'icinga-powershell-framework.psm1');
            }
        } catch {
            # Todo: Log output
        }
    }

    try {
        # Try to load the framework now
        Use-Icinga;

        Write-IcingaConsoleNotice 'Icinga PowerShell Framework seems to be successfully installed';
        Write-IcingaConsoleNotice 'To use the Icinga PowerShell Framework in the future, please initialize it by running the command "Use-Icinga" inside your PowerShell';

        $global:IcingaFrameworkKickstartArguments = $InstallerArguments;

        if ($SkipWizard) {
            return;
        }

        if ((Read-IcingaWizardAnswerInput -Prompt 'Do you want to run the Icinga Agent installation wizard now? (You can do this later by running the command "Start-IcingaAgentInstallWizard")' -Default 'y').result -eq 1) {
            Write-IcingaConsoleNotice 'Starting Icinga Agent installation wizard';
            Write-IcingaConsoleNotice '=======';
            Start-IcingaAgentInstallWizard;
        }

        # Todo: Preparation for a later version of the module
        <#if ((Read-IcingaWizardAnswerInput -Prompt 'Do you want to install the framework on different hosts?' -Default 'y').result -eq 1) {
            $HostList = (Read-IcingaWizardAnswerInput -Prompt 'Please enter the hosts seperated by ","' -Default 'v').answer;
            Install-IcingaFrameworkRemoteHost -RemoteHosts $HostList.Split(',');
        }#>
    } catch {
        Write-IcingaConsoleError ([string]::Format('Unable to load the Icinga PowerShell Framework. Please check your PowerShell execution policies for possible problems. Error: {0}', $_.Exception));
    }
}

function Test-AdministrativeShell()
{
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent();
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity);

    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        return $FALSE;
    }
    return $TRUE;
}

function Unblock-IcingaFramework()
{
    param(
        $Path
    );

    if ([string]::IsNullOrEmpty($Path)) {
        Write-IcingaConsoleNotice 'Icinga PowerShell Framework directory was not found';
        return;
    }

    Write-IcingaConsoleNotice 'Unblocking Icinga PowerShell Framework files';
    Get-ChildItem -Path $Path -Recurse | Unblock-File; 
}

function Expand-IcingaFrameworkArchive()
{
    param(
        $Path,
        $Destination,
        $AllowUpdate = $null
    );

    Add-Type -AssemblyName System.IO.Compression.FileSystem;

    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $Destination);
    } catch {

    }

    $FolderContent = Get-ChildItem -Path $Destination;
    $Extracted     = '';

    foreach ($entry in $FolderContent) {
        if ($entry -eq 'icinga-powershell-framework') {
            return (Join-Path -Path $Destination -ChildPath $entry);
        }
        if ($entry -like 'icinga-powershell-framework*') {
            $Extracted = $entry;
        }
    }

    if ([string]::IsNullOrEmpty($Extracted)) {
        return $null;
    }

    $NewDirectory = (Join-Path -Path $Destination -ChildPath 'icinga-powershell-framework');
    $ExtractDir   = (Join-Path -Path $Destination -ChildPath $Extracted);
    $BackupDir    = (Join-Path -Path $ExtractDir -ChildPath 'previous');
    $OldBackupDir = (Join-Path -Path $NewDirectory -ChildPath 'previous');

    if ((Test-Path $NewDirectory)) {
        if ($null -eq $AllowUpdate) {
            if ((Read-IcingaWizardAnswerInput -Prompt 'It seems that the Icinga PowerShell Framework is already installed. Would you like to update it?' -Default 'y').result -eq 0) {
                return $null;
            }
            $AllowUpdate = $TRUE;
        }

        if ($AllowUpdate -eq $FALSE) {
            return $null;
        }

        if ((Test-Path (Join-Path -Path $NewDirectory -ChildPath 'cache'))) {
            Write-IcingaConsoleNotice 'Importing cache into new Icinga PowerShell Framework version...';
            Copy-Item -Path (Join-Path -Path $NewDirectory -ChildPath 'cache') -Destination $ExtractDir -Force -Recurse;
        }
        if ((Test-Path (Join-Path -Path $NewDirectory -ChildPath 'custom'))) {
            Write-IcingaConsoleNotice 'Importing custom modules into new Icinga PowerShell Framework version...';
            Copy-Item -Path (Join-Path -Path $NewDirectory -ChildPath 'custom') -Destination $ExtractDir -Force -Recurse;
        }
        Write-IcingaConsoleNotice 'Creating backup directory';
        if ((Test-Path $OldBackupDir)) {
            Write-IcingaConsoleNotice 'Importing old backups into new Icinga PowerShell Framework version...';
            Move-Item -Path $OldBackupDir -Destination $ExtractDir;
        } else {
            Write-IcingaConsoleNotice 'No previous backups found. Creating new backup space';
            New-Item -Path $BackupDir -ItemType Container | Out-Null;
        }
        Write-IcingaConsoleNotice 'Moving old Icinga PowerShell Framework into backup directory';
        Move-Item -Path $NewDirectory -Destination (Join-Path -Path $BackupDir -ChildPath (Get-Date -Format "MM-dd-yyyy-HH-mm-ffff"));
    }

    Write-IcingaConsoleNotice 'Installing new Icinga PowerShell Framework version';
    Move-Item -Path (Join-Path -Path $Destination -ChildPath $Extracted) -Destination $NewDirectory;

    return $NewDirectory;
}

function Install-IcingaFrameworkRemoteHost()
{
    param(
        [array]$RemoteHosts
    );

    $RemoteScript = {
        param($KickstartScript, $Arguments);
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11";
        $ProgressPreference = "SilentlyContinue";

        $global:IcingaFrameworkKickstartSource = $KickstartScript;

        $Script = (Invoke-WebRequest -UseBasicParsing -Uri $global:IcingaFrameworkKickstartSource).Content;
        $Script += "`r`n`r`n & Start-IcingaFrameworkWizard @Arguments;";

        Invoke-Command -ScriptBlock ([Scriptblock]::Create($Script));
    }

    foreach ($HostEntry in $RemoteHosts) {
        Invoke-Command -ComputerName $HostEntry -ScriptBlock $RemoteScript -ArgumentList @( $global:IcingaFrameworkKickstartSource, $global:IcingaFrameworkKickstartArguments );
    }
}

function Read-IcingaWizardAnswerInput()
{
    param(
        $Prompt,
        [ValidateSet("y","n","v")]
        $Default,
        $DefaultInput   = '',
        [switch]$Secure
    );

    $DefaultAnswer = '';

    if ($Default -eq 'y') {
        $DefaultAnswer = ' (Y/n)';
    } elseif ($Default -eq 'n') {
        $DefaultAnswer = ' (y/N)';
    } elseif ($Default -eq 'v') {
        if ([string]::IsNullOrEmpty($DefaultInput) -eq $FALSE) {
            $DefaultAnswer = [string]::Format(' (Defaults: "{0}")', $DefaultInput);
        }
    }

    if (-Not $Secure) {
        $answer = Read-Host -Prompt ([string]::Format('{0}{1}', $Prompt, $DefaultAnswer));
    } else {
        $answer = Read-Host -Prompt ([string]::Format('{0}{1}', $Prompt, $DefaultAnswer)) -AsSecureString;
    }

    if ($Default -ne 'v') {
        $answer = $answer.ToLower();

        $returnValue = 0;
        if ([string]::IsNullOrEmpty($answer) -Or $answer -eq $Default) {
            $returnValue = 1;
        } else {
            $returnValue = 0;
        }

        return @{
            'result' = $returnValue;
            'answer' = '';
        }
    }

    if ([string]::IsNullOrEmpty($answer)) {
        $answer = $DefaultInput;
    }

    return @{
        'result' = 2;
        'answer' = $answer;
    }
}

function Write-IcingaConsoleOutput()
{
    param (
        [string]$Message,
        [array]$Objects,
        [ValidateSet('Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow', 'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White')]
        [string]$ForeColor = 'White',
        [string]$Severity  = 'Notice'
    );

    $OutputMessage = $Message;
    [int]$Index    = 0;

    foreach ($entry in $Objects) {

        $OutputMessage = $OutputMessage.Replace(
            [string]::Format('{0}{1}{2}', '{', $Index, '}'),
            $entry
        );
        $Index++;
    }

    if ([string]::IsNullOrEmpty($Severity) -eq $FALSE) {
        Write-Host '[' -NoNewline;
        Write-Host $Severity -NoNewline -ForegroundColor $ForeColor;
        Write-Host ']: ' -NoNewline;
    }

    Write-Host $OutputMessage;
}

function Write-IcingaConsoleNotice()
{
    param (
        [string]$Message,
        [array]$Objects
    );

    Write-IcingaConsoleOutput `
        -Message $Message `
        -Objects $Objects `
        -ForeColor 'Green' `
        -Severity 'Notice';
}

function Write-IcingaConsoleError()
{
    param (
        [string]$Message,
        [array]$Objects
    );

    Write-IcingaConsoleOutput `
        -Message $Message `
        -Objects $Objects `
        -ForeColor 'Red' `
        -Severity 'Error';
}
