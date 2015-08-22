#
# evt2ls.ps1
#
# Send Windows Event logs to a remote LogStash instance
# Note: Required PowerShell V3
#
# Author: Xavier Mertens <xavier(at)rootshell(dot).be>
# Copyright: GPLv3 (http://gplv3.fsf.org)
# Feel free to use the code but please share the changes you've made
#

# Change to match your setup
$LOGSTASH_SERVER = "192.168.254.65"
$LOGSTASH_PORT = 5001

Function Dump2Logstash {
	param (
		[ValidateNotNullOrEmpty()]
		[string] $server,
		[int] $port,
		$jsondata)

	$ip = [System.Net.Dns]::GetHostAddresses($server)
	$address = [System.Net.IPAddress]::Parse($ip)
	$socket = New-Object System.Net.Sockets.TCPClient($address, $port)
	$stream = $socket.GetStream()
	$writer = New-Object System.IO.StreamWriter($stream)

	# Convert the existing data into a JSON array to process events one by one
	$buffer = '{ "Events": ' + $jsondata + ' }' | ConvertFrom-Json
	foreach($event in $buffer.Events) {
		echo "Processing:"
		echo $event
		# Convert to a 1-line JSON event
		$x = $event | ConvertTo-Json -depth 3
		$x= $x -replace "`n",' ' -replace "`r",''

		$writer.WriteLine($x)
		$writer.Flush()
	}
	$stream.Close()
	$socket.Close()
}

# Change the maximum number of events to retrieve or the computer
# or the log to process. More details here:
# https://technet.microsoft.com/en-us/library/hh849682.aspx

# Send the last 1000 events
#$data =  Get-WinEvent -MaxEvents 1000 | ConvertTo-Json -depth 3

# Send events from the last hour
$starttime = (get-date).addhours(-1)
$data = Get-WinEvent -FilterHashtable @{logname="*"; starttime=$starttime} | ConvertTo-Json -depth 3
Dump2Logstash $LOGSTASH_SERVER $LOGSTASH_PORT "$data"
echo "Done!"
