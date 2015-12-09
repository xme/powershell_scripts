#
# registerusbevent.ps1
#
# Register a new Windows event when a USB stick is inserted in a USB port.
# Kudos to Jose for the original version of the script ;-)
#
# Author: Xavier Mertens <xavier@rootshell.be>
# CopyRight: GPLv3 (http://gplv3.fsf.org)
# Free free to use the code but please share the changes you've made
#

$query = "SELECT * FROM __InstanceOperationEvent WITHIN 5 WHERE TargetInstance ISA 'Win32_LogicalDisk' AND TargetInstance.DriveType=2"

Register-WmiEvent -Query $query -SourceIdentifier RemovableDiskDetection -Action {

	$class = $eventArgs.NewEvent.__CLASS
	$device = $eventArgs.NewEvent.TargetInstance.DeviceID

	switch($class)
	{
		__InstanceCreationEvent {
			Write-Host "[DEBUG] Inserted, device id: $device "
			$path = $device + "\log\processing.log"
			Write-Host "[DEBUG] Checking the existence of the file $path"
			$ok = $false
                        
			# Test the presence of a CIRCLean logfile and check its age (must be < 2d)
			if(Test-Path -Path $path)
			{
				Write-Host "[DEBUG] Looking for the creation date of the file $path"
				$lastModification = (get-item $path).LastWriteTime
				$timeSpan = new-timespan -days 2
				if (((get-date) - $lastModification) -lt $timeSpan) {
					Write-Host "[DEBUG] The file $path has been created/modified in less than 2 days"
                        		$ok = $true
				} 
			}
			else {
				Write-Host "[DEBUG] Tag file does not exist."
			}

			# File not found or too old, eject and notify the user via a popup window
			if (!$ok)
			{
				$driveEject = New-Object -comObject Shell.Application
				$driveEject.Namespace(17).ParseName($device).InvokeVerb("Eject")
       				Write-Host "[DEBUG] The USB stick is considered NOT SAFE. In order to use it please scan it first using CIRCLean."
				(new-object -ComObject wscript.shell).Popup("This USB stick is considered NOT safe. Please scan it with CIRCLean!",0,"USB Cleaner",0x0)
			}
			else{
				Write-Host "[DEBUG] The USB stick is considered SAFE."
			}
        	}

		__InstanceDeletionEvent {
			Write-Host "[DEBUG] Removed, device id: $device "
		}
	}
}
