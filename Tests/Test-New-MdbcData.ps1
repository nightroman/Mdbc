
Import-Module Mdbc
Set-StrictMode -Version 2

function Test-Type($Value, $TypeName, [switch]$Full) {
	$name = if ($Full) { $Value.GetType().FullName } else { $Value.GetType().Name }
	if ($name -ne $TypeName) {
		throw @"
Actual type   : $name
Expected type : $TypeName
"@
	}
}

### Convert hashtables to documents

$HashToDocument = New-MdbcData @{ String = 'Hi'; Date = (Get-Date) }
Test-Type $HashToDocument Mdbc.Dictionary -Full

$new = New-MdbcData
$new.Document = @{ String = 'Hi'; Date = (Get-Date) }
Test-Type $new.Document Mdbc.Dictionary -Full

# fixed
$new.Document = New-MdbcData @{ String = 'Hi'; Date = (Get-Date) }
Test-Type $new.Document Mdbc.Dictionary -Full

### Convert .NET types to BSON values

Test-Type (New-MdbcData $true) BsonBoolean
Test-Type (New-MdbcData (Get-Date)) BsonDateTime
Test-Type (New-MdbcData 1.1) BsonDouble
Test-Type (New-MdbcData ([guid]::NewGuid())) BsonBinaryData
Test-Type (New-MdbcData 1) BsonInt32
Test-Type (New-MdbcData 1L) BsonInt64
Test-Type (New-MdbcData text) BsonString

Test-Type (New-MdbcData @()) Collection
Test-Type (New-MdbcData @{}) Dictionary
