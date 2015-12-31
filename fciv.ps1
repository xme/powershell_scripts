#############################################################
## fciv.ps1
## version: 0.1
#############################################################
## HISTORY
## 30th/31st of December 2015
## Making changes so the Powershell v4 requirement is solved
## and detection of privileges happens + filehanlding
##
## 30th of August 2015
## Xavier Mertens (XME) did a post on his github.
## https://github.com/xme/powershell_scripts/blob/master/fciv.ps1
#############################################################
<#
. Name
  fciv

. SYNOPSIS
  fciv is a Microsoft application that allows you to calculate hashes on your
  entire operating system and store them in an xml file.

. NOTES
  Xavier Mertens's ISC blogpost: 
  https://isc.sans.edu/forums/diary/Detecting+file+changes+on+Microsoft+systems+with+FCIV/20091

  Download for the fciv tool
  http://www.microsoft.com/en-us/download/details.aspx?id=11533

. EXAMPLE
  fciv.ps1

  Calls the script and will ask you for the location of fciv.exe and where to write the output.

. TODO
  Do the parameter binding for the script so the parameters can be used and if no parameters are
  provided to the script, prompt user


#>

#############################################################

## Global variables ##
# Only rename if you are not happy with the logsource name
$logsource = "FCIV"

# Change this to the path of fciv.exe if you don't want to enter it all the time
# the default value is $null
$fcivlocation = $null

# Change this if your output directory for the database is always the same
# the default value is $null
$dblocation = $null

#############################################################
function Setup-Logs($logsource){
  <#
    .SYNOPSIS
        Sets up the Application log.

    .DESCRIPTION
        https://technet.microsoft.com/en-us/library/hh849768.aspx
        To use New-EventLog on Windows Vista and later versions of Windows, open Windows PowerShell with the "Run as administrator" option.
        To create an event source in Windows Vista, Windows XP Professional, or Windows Server 2003, you must be a member of the Administrators group on the computer.

    .EXAMPLE
        Setup-Logs

  #>
    
  if(-not [system.diagnostics.eventlog]::SourceExists($logsource)){
    New-EventLog -LogName Application -Source $logsource
    Write-EventLog -LogName Application -Source "$logsource" -EntryType Information -EventId 1 -Message "$logsource has been added to the Windows Application Windows Eventlog."
  }
}

#    $admin_role = [Security.Principal.WindowsBuiltInRole] 'Domain Admins'

function Check-Admin{
 <# 
    .SYNOPSIS
        Checks if the script is running in Administor Role

    .DESCRIPTION
        Checks if the script is running in Administor Role

    .EXAMPLE
    Check-Admin    
 #>
 $admin_role = [Security.Principal.WindowsBuiltInRole] 'Administrator'
 return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole($admin_role)

}

function Get-FileHashEx { 
    <#
        .SYNOPSIS
            Calculates the hash of a given file.

        . DESCRIPTION
            Calculates the hash of a given file.

            Origin of the code:  https://gallery.technet.microsoft.com/scriptcenter/Get-Hashes-of-Files-1d85de46

        .EXAMPLE
            Get-FileHash -Path %windir%\system32\notepad.exe -Algorithm MD5

        .EXAMPLE
            Get-FileHash -Path %windir%\system32\notepad.exe -Algorithm SHA256
    
    #>
        [CmdletBinding()]
    Param(
       [Parameter(Position=0,Mandatory=$true, ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True)]
       [Alias("PSPath","FullName")]
       [string[]]$Path, 

       [Parameter(Position=1)]
       [ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
       [string[]]$Algorithm = "SHA256"
    )
    Process {  
        ForEach ($item in $Path) { 
            $item = (Resolve-Path $item).ProviderPath
            If (-Not ([uri]$item).IsAbsoluteUri) {
                Write-Verbose ("{0} is not a full path, using current directory: {1}" -f $item,$pwd)
                $item = (Join-Path $pwd ($item -replace "\.\\",""))
            }
           If(Test-Path $item -Type Container) {
              Write-Warning ("Cannot calculate hash for directory: {0}" -f $item)
              Return
           }
           $object = New-Object PSObject -Property @{ 
                Path = $item
            }
            #Open the Stream
            $stream = ([IO.StreamReader]$item).BaseStream
            foreach($Type in $Algorithm) {                
                [string]$hash = -join ([Security.Cryptography.HashAlgorithm]::Create( $Type ).ComputeHash( $stream ) | 
                ForEach { "{0:x2}" -f $_ })
                $null = $stream.Seek(0,0)
                #If multiple algorithms are used, then they will be added to existing object                
                $object = Add-Member -InputObject $Object -MemberType NoteProperty -Name $Type -Value $Hash -PassThru
            }
            $object.pstypenames.insert(0,'System.IO.FileInfo.Hash')
            #Output an object with the hash, algorithm and path
            Write-Output $object

            #Close the stream
            $stream.Close()
        }
    }
}

function Check-ProcessActive(){
    <#
        .SYNOPSIS
            Checks if a process is running or has already terminated and keeps the script waiting while the external process is busy.

        . DESCRIPTION
            Checks if a process is running or has already terminated and keeps the script waiting while the external process is busy.

        .EXAMPLE
            Check-ProcessActive($processname) 

            Checks if the process is running every 5 seconds.    
    #>
    [CmdletBinding()]
        Param($processname)
    Process{
        try{
           # fetch the process id
           $process = Get-Process $processname -ErrorAction Stop
           $processid = $process.Id
            
        }
        catch [System.Management.Automation.ActionPreferenceStopException]
        {
            # when the error is triggered this means the process doesn't exist anymore
            # we set the process id to -1 since 0 is reserved for Idle
            $processid = -1
        }
        finally{
            # Check the value of the process id
            if($processid -ne -1){
                # when not -1 it means the process is running and we need to wait a bit
                $date = Get-Date -Format H:mm:ss
                Write-Output "$date $processname is still busy, be patient young grasshopper..."
                Start-Sleep -Seconds 5
                Check-ProcessActive($processname)
            }
        }
    }
}

function main(){
   # You need to execute it with domain admin rights or local admin rights   
  if(Check-Admin)
  {
    $starttime = Get-Date -Format MM/dd/yyyy-H:mm:ss
    $date = Get-Date -Format yyyyMMddHmmss
    Setup-Logs($logsource)
    Write-EventLog -LogName Application -Source "$logsource" -EntryType Information -EventId 1 -Message "$logsource has been started at $starttime."
    ###### Begin of your code ######
    
    # Check if the location of fciv.exe is set
    if ($fcivlocation -eq $null){
        $fcivlocation = Read-Host "In what directory can fciv.ps1 find fciv.exe?"
    }

    # Check if the location of the output directory is set
    if($dblocation -eq $null){
        $dblocation = Read-Host "In what directory shall fciv.ps1 save the output file?"
    }

    # The database name is set to the start time of the script and appended with hashdb.xml
    $dbname = $env:COMPUTERNAME
    $dbname += "-$date"
    $dbname += "-hashdb.xml"
    
    Write-output "Building the database and writing it to $dblocation\$dbname ... this will take a while"
    $process = "$fcivlocation\fciv.exe"
    $argumentlist = "-both -xml $dblocation\$dbname -r c:\ -type *.dll -type *.vxd -type *.ocx -type *.inf -type *.sys -type *.drv -type *.reg -type *.386 -type *.job -type *.acm -type *.ax -type *.cpl -type *.efi -type *.mui -type *.scr -type *.tsp"
    
    # The windowstyle is set to hidden so the popup of fciv doesn't happen
    Start-Process $process -ArgumentList $argumentlist -WindowStyle Hidden

    # Check if the process fciv is still active, if it is the script has to wait for 5 seconds
    Check-ProcessActive("fciv")
    
    # Check for the error file
    $errorfile = "fciv.err"
    $currentpath = Convert-Path -Path .
    if(Test-Path("$currentpath\$errorfile")){
        # error file exists
        $errorfilename = $env:COMPUTERNAME
        $errorfilename += "-$date"
        $errorfilename += "-$errorfile"
        # move the error file to the right location and rename at the same time
        Move-Item $currentpath\$errorfile $dblocation\$errorfilename
    }
            
    # Generate a hash of the database
    $hashfile = $null
    if($PSVersionTable.PSVersion.Major > 3){
        # Get-filehash is standard available since Powershell 4.0 
        $hashfile = get-filehash -path $dblocation\$dbname -algorithm sha1 
        # $dblocation\$dbname.sha1sum
    }else{
        # Use the get-filehashex for lower versions
        $hashfile = Get-FileHashEx -Path $dblocation\$dbname -Algorithm SHA1
        #$dblocation\$dbname.sha1sum
    }
    Write-Output "Calculating hash for $dblocation\$dbname : $hashfile"
    $hashfilename = $env:COMPUTERNAME
    $hashfilename += "-$date"
    $hashfilename += "-hashdb.sha1sum"
    $hashfile | Out-File -LiteralPath $dblocation\$hashfilename

    # For some reason if you don't have the right permission a file called 3 with the value 3 is generated
    # This is just a cleanup, no idea what 3 is but best guess it has to do with the errors.
    if(Test-Path "$currentpath\3"){
        Remove-Item "$currentpath\3"    
    }

    
    ###### End of your code ######
    $stoptime = Get-Date -Format MM/dd/yyyy-H:mm:ss
    Write-EventLog -LogName Application -Source "$logsource" -EntryType Information -EventId 1 -Message "$logsource has been ended at $stoptime."
  }
  else
  {
    Write-Output "$logsource needs administrator rights.\nPlease restart with domain admin rights."
  }
}

################## Boilerplate ##############################
main
