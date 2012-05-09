
<#
.Synopsis
	Quick start code used in the README.md
#>

.{
	# Import the module (if not yet):
	Import-Module Mdbc

	# Connect and get a new collection 'test' in the database 'test':
	$collection = Connect-Mdbc . test test -NewCollection

	# Add some data (Name and WorkingSet of currently running processes):
	Get-Process | New-MdbcData -DocumentId {$_.Id} -Property Name, WorkingSet | Add-MdbcData $collection

	# Query all saved data back and print them formatted:
	Get-MdbcData $collection -AsCustomObject | Format-Table -AutoSize | Out-String

	# Get saved data of the process 'mongod' (there should be at least one document):
	$data = Get-MdbcData $collection (New-MdbcQuery Name -EQ mongod)
	$data

	# Update these data (let's just set the WorkingSet to 12345):
	$data | Update-MdbcData $collection (New-MdbcUpdate WorkingSet -Set 12345)

	# Query again in order to take a look at the changed data:
	Get-MdbcData $collection (New-MdbcQuery Name -EQ mongod)

	# Remove these data:
	$data | Remove-MdbcData $collection

	# Query again, just get the count, it should be 0:
	Get-MdbcData $collection (New-MdbcQuery Name -EQ mongod) -Count
}
