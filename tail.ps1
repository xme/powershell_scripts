#
# File Name	: tail.ps1
# Author	: Xavier Mertens <xavier@rootshell.be>
# Prerequisite	: PowerShell v1
# Example	: tail.ps1 -log Security,System -verbose -pattern ERROR
#
# History
# 2013/09/17	: Created
# 2019/10/17	: Modified
#
param(
	[string]$log = "Security",
	[string]$eventid = "",
	[string]$pattern = "",
	[switch]$details = $false,
	[switch]$colour  = $false,
	[switch]$verbose = $false,
	[switch]$help = $false
)

if ($help -eq $true)
{
	Write-Host "Usage: tail.ps1 [-log=<eventlog>,<eventlog>,...]
                [-eventid=<id>,<id>,...]
                [-pattern=<regex>]
                [-colour]
                [-details]
                [-verbose]
                [-help]
				
                e.g. 
                tail -log ""My Service"" => reads new messages from My Service event source. C3 Service is the default.
                tail -pattern ERROR => shows only the lines matching the word ""ERROR""
                tail -pattern ""New ERROR"" => shows only the lines matching ""New ERROR""
                tail -pattern word_I_want_to_look_for -colour => shows all the lines and the matching ones in red
                "
	exit
}

$eventlogs = $log.split(",")
$eventids = $eventid.split(",")
$idx = 0
$old = new-object object[] 10
$new = new-object object[] 10

if ($verbose) { Write-Host "*** Processing event log(s): $log" }

foreach($eventlog in $eventlogs) 
{
  $old[$idx] = (get-eventlog -LogName $eventlog -Newest 1).Index
  $idx++
}

# $idx = (get-eventlog -LogName System -Newest 1).Index

while ($true)
{
  start-sleep -Seconds 1
  $idx = 0
  foreach($eventlog in $eventlogs)
  {  
    $new[$idx] = (Get-EventLog -LogName $eventlog -newest 1).index
    if ($new[$idx] -gt $old[$idx])
    {
      if ($verbose) { Write-Host "*** Read new event(s) from $eventlog" }
      foreach($id in $eventids)
      {
        if ($id.length -eq 0) {
          $data = get-eventlog -logname $eventlog -newest ($new[$idx] - $old[$idx]) | sort index
        }
        else {
          $data = get-eventlog -logname $eventlog -newest ($new[$idx] - $old[$idx]) | ?{$_.eventid -eq $id} | sort index
        }
        foreach($line in $data) {
          if ($pattern.length -eq 0) {
            if ($details -eq $false) {
              $line
            }
            else {
              $line | format-list
            }
          }
          else {
            if ($colour) {
              if ($line.message -match $pattern) {
                [Console]::ForegroundColor = "red"
                $line
                [Console]::ResetColor()
              }
              else {
                $line
              }
            }
            else {
              if ($line.message -match $pattern) {
                $line
              }
            }
          }
        }
      }
    }
    $old[$idx] = $new[$idx]
    $idx++;
  }
}
