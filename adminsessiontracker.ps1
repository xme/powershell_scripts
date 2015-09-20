#
# adminsessiontracker.ps1
#
# Logon script to be deployed via GPO
# It asks the administrator to give information about the session and creates an EventLog
#
# Author: Xavier Mertens <xavier@rootshell.be>
# CopyRight: GPLv3 (http://gplv3.fsf.org)
# Free free to use the code but please share the changes you've made
#

Add-Type -AssemblyName System.Windows.Forms;

# ------------------------------
# Edit to match your environment
# ------------------------------
# Note: The "Security" log is only available from lsass.exe!
$eventLog    = "Application";
$eventSource = "AdminSessionTracker"; # No spaces allowed!?
$eventId     = 1;

function displayDialogBox() {
    [void][System.Reflection.Assembly]::LoadWithPartialName('Systems.Windows.Forms')
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
    
    $balloon = New-Object 'System.Windows.Forms.NotifyIcon';
    $path = Get-Process -id $pid | Select-Object -ExpandProperty Path
    $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path);
    $balloon.BalloonTipIcon = 'Info';
    $balloon.BalloonTipTitle = 'Admin Session Tracker';
    $balloon.BalloonTipText = 'The session tracker helps to track Administrator sessions on this host. Please describe while you are connected with privileged rights.';
    $balloon.Visible = $true;
    $balloon.ShowBalloonTip(20000);

    $form = New-Object "System.Windows.Forms.Form";
    $form.Width = 500;
    $form.Height = 200;
    $form.MaximizeBox = $false
    $form.FormBorderStyle = 'FixedDialog'
    $form.StartPosition = 'CenterScreen'
    $form.TopMost = $true;
    $form.AutoSizeMode = 'GrowAndShrink';
    $form.Text = "Administrator Session Description";

    $initialState = New-Object 'System.Windows.Forms.FormWindowState';
    $formStateCorrectionLoad = {
        $form.WindowState = $initialState;
    }

    $label = New-Object "System.Windows.Forms.Label";
    $label.Left = 10;
    $label.Top = 10;
    $label.Width = 470;
    $label.Text = "Please describe the reason(s) of this Administrator's session:";

    $textbox = New-Object "System.Windows.Forms.RichTextBox";
    $textbox.Left = 10;
    $textbox.Top = 35;
    $textbox.Width = 470;
    $textbox.Height = 80;
    $textbox.Text = "";

    $button = New-Object "System.Windows.Forms.Button";
    $button.Left = 200;
    $button.Top = 130;
    $button.Width = 100;
    $button.Text = "Submit";

    $eventHandler = [System.EventHandler] {
        $textbox.Text;
        $form.Close();
    }
    $button.Add_Click($eventHandler);

    $form.Controls.Add($button);
    $form.Controls.Add($label);
    $form.Controls.Add($textbox);
    $initialState = $form.WindowState;
    $form.add_Load($formStateCorrectionLoad);
    $ret = $form.ShowDialog();
    return($textbox.Text);
}

# Check if the user is admin
if (-NOT([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    # Silently exit
    exit; # Comment for debugging purpose (all users)
}

# Display the dialog box until the user gives some input
$formValue = "";
while ($formValue -eq "") {
    $formValue = displayDialogBox;
}
Write-Warning "Got input:$formValue";

# Before creating events from a new source, we must create it once
# Note: This requires admin rights but we are already :)
if ([System.Diagnostics.EventLog]::SourceExists($eventSource) -eq $false) {
    Write-Warning "Creating new source: $eventSource in $eventLog";
    New-EventLog -LogName $eventLog -Source $eventSource;
}

# Write-EventLog does not fill the User field by default. 
# Append it in the message
$msg = "User:"+$env:USERNAME+"|Domain:"+$env:USERDOMAIN+"|Message:"+$formValue;
Write-EventLog -LogName $eventLog -Source "$eventSource" -EventId $eventId -Message $msg;

Exit;

# $env:USERNAME

