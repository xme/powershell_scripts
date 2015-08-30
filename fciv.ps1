#
# Generate a hash database of interesting files on the system
# Requirements:
# - PowerShell v4!
# - Must be executed with admin rights
#

# Generate the database name based on the current date
# D: is the drive where are locate useful files to not alter the local FS (ex: a USB key)
$date = get-date -format "yyyyMMdd"
$dbname = d:\hashdb-$date.xml

d:\bin\fciv.exe -both -xml $dbname -r c:\ -type *.dll -type *.vxd -type *.ocx -type *.inf -type *.sys -type *.drv -type *.reg -type *.386 -type *.job

# Generate a hash of the database
get-filehash -path $dbname -algorithm sha1 | foreach { $_.hash } >$dbname.sha1sum
