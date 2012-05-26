
<#
.Synopsis
	Quick start code used in the README.md
#>

.{
	# Load the module
	Import-Module Mdbc

	# Connect the database 'test' and the new collection 'test'
	Connect-Mdbc . test test -NewCollection

	# Add some data (Name and WorkingSet of currently running processes)
	Get-Process | New-MdbcData -Id {$_.Id} -Property Name, WorkingSet | Add-MdbcData

	# Query all saved data back and print them formatted
	Get-MdbcData -AsCustomObject | Format-Table -AutoSize | Out-String

	# Get saved data of the process 'mongod' (there should be at least one)
	$data = Get-MdbcData (New-MdbcQuery Name -EQ mongod)
	$data

	# Update these data (let's just set the WorkingSet to 12345)
	$data | Update-MdbcData (New-MdbcUpdate WorkingSet -Set 12345)

	# Query again in order to take a look at the changed data
	Get-MdbcData (New-MdbcQuery Name -EQ mongod)

	# Remove these data
	$data | Remove-MdbcData

	# Query again, just get the count, 0 is expected
	Get-MdbcData (New-MdbcQuery Name -EQ mongod) -Count
}
