
<#
.Synopsis
	Tests the Mdbc module and custom objects
#>

Import-Module Mdbc

$property = @{n='_id'; e='Id'}, 'Name', 'StartTime', 'WorkingSet64'

### One custom object as an argument
$custom = Get-Process mongod | Select-Object $property -First 1
$document = New-MdbcData $custom
if ($document.GetType().FullName -ne 'Mdbc.Dictionary') { throw }

### Many custom objects from pipeline
$documents = Get-Process svchost | Select-Object $property | New-MdbcData
foreach($_ in $documents) {	if ($_.GetType().FullName -ne 'Mdbc.Dictionary') { throw } }
