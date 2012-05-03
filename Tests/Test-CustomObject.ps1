
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

### Convert back to custom objects with a helper and manually
$custom1 = $documents | Convert-MdbcData
$custom2 = $documents | %{ New-Object psobject -Property $_ }
$custom1 | Format-Table -AutoSize | Out-String
