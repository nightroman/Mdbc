
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

# Temp json file
$json = "$env:TEMP\test.json"

# Makes the temp json file
function JsonFile($Text) {
	[System.IO.File]::WriteAllText($json, $Text)
}

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

	Open-MdbcFile $json
	$r = Get-MdbcData
	Test-List $data $r

	remove $json
	Open-MdbcFile
	$data | Add-MdbcData
	Save-MdbcFile $json
	$r = Import-MdbcData $json
	Test-List $data $r

	# use Strict and see loss of data types
	$old = [MongoDB.Bson.IO.JsonWriterSettings]::Defaults.OutputMode
	[MongoDB.Bson.IO.JsonWriterSettings]::Defaults.OutputMode = 'Strict'
	try {
		$data | Export-MdbcData $json
		($r = Get-Content -LiteralPath $json)
		$r1, $r2 = $r | ConvertFrom-Json
		if ($PSVersionTable.PSVersion.Major -ge 6) {
			equals Double ($r1.Double.GetType().Name)
			equals Int64 ($r2.Int64.GetType().Name)
		}
		else {
			equals Decimal ($r1.Double.GetType().Name)
			equals Int32 ($r2.Int64.GetType().Name)
		}
	}
	finally {
		[MongoDB.Bson.IO.JsonWriterSettings]::Defaults.OutputMode = $old
	}
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
