. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

# Temp json file
$json = "$env:TEMP\test.json"

# Makes the temp json file
function JsonFile($Text) {
	[System.IO.File]::WriteAllText($json, $Text)
}

#! Use 2+ documents in this test to cover issues like missing EOL after documents.
task PreserveTypes {
	$1 = New-MdbcData -NewId
	$1.String = 'string1'
	$1.Int32 = 1
	$1.Int64 = [long]::MaxValue
	$1.Double = 3.14
	$1.Date = [datetime]'2000-01-01'
	$1.Guid = [guid]'12345678-1234-1234-1234-123456789012'

	$2 = New-MdbcData -NewId
	$2.String = 'string2'
	$2.Int32 = 2
	$2.Int64 = 2L
	$2.Double = 2.0
	$2.Date = [datetime]'2002-02-02'
	$2.Guid = [guid]'12345678-1234-1234-1234-123456789012'

	$data = $1, $2

	remove $json
	$data | Export-MdbcData $json
	$r = Import-MdbcData $json
	Test-List $data $r

	# use JsonCanonicalExtended (data look preserved better)
	Write-Build Cyan JsonCanonicalExtended
	$data | Export-MdbcData $json -FileFormat JsonCanonicalExtended
	$r = Import-MdbcData $json
	Test-List $data $r
	($r = Get-Content -LiteralPath $json)
	$r1, $r2 = $r | ConvertFrom-Json
	equals PSCustomObject ($r1.Double.GetType().Name)
	equals PSCustomObject ($r2.Int64.GetType().Name)

	# use JsonRelaxedExtended and see loss of some data types
	Write-Build Cyan JsonRelaxedExtended
	$data | Export-MdbcData $json -FileFormat JsonRelaxedExtended
	($r = Get-Content -LiteralPath $json)
	$r1, $r2 = $r | ConvertFrom-Json
	equals Double ($r1.Double.GetType().Name) #! Decimal in PS 5.1
	equals Int64 ($r2.Int64.GetType().Name) #! Int32 in PS 5.1
}

#!
task JsonAsPS {
	JsonFile @'
{ "_id" : 1, "x" : 1 }
{ "_id" : 2, "x" : 2 }

'@
	$r1, $r2 = Import-MdbcData $json -As PS
	equals $r1._id 1
	equals $r2._id 2
}

task FlexibleJson {
	JsonFile @'

{
    "x":  1
}

	{
	    "x":  2
	}

{
    "x":  3
}

	{
	    "x":  4
	}
	{
	    "x":  5
	}


'@

	$r = Import-MdbcData $json
	equals "$r" '{ "x" : 1 } { "x" : 2 } { "x" : 3 } { "x" : 4 } { "x" : 5 }'
}

task BadJson {
	JsonFile 'x'
	Test-Error { Import-MdbcData $json } "JSON reader was expecting a value but found 'x'."

	JsonFile ','
	Test-Error { Import-MdbcData $json } "JSON reader was expecting a value but found ','."

	JsonFile ' ]'
	Test-Error { Import-MdbcData $json } "JSON reader was expecting a value but found ']'."

	JsonFile ' [['
	Test-Error { Import-MdbcData $json } "Cannot deserialize a 'BsonDocument' from BsonType 'Array'."

	JsonFile '{x=1}'
	Test-Error { Import-MdbcData $json } "Invalid JSON input ''."
}

task Example.Import-MdbcData {
	$r = $(
		# Import data produced by ConvertTo-Json (PowerShell V3)
		$Host | ConvertTo-Json | Set-Content z.json
		Import-MdbcData z.json
	)
	equals $r.Name $Host.Name
	remove z.json
}
