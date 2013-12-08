
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

$json = "$env:TEMP\test.json"

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

	Remove-Item -LiteralPath $json -ErrorAction 0
	$data | Export-MdbcData $json
	$r = Import-MdbcData $json
	Test-List $data $r

	Open-MdbcFile $json
	$r = Get-MdbcData
	Test-List $data $r

	Remove-Item -LiteralPath $json -ErrorAction 0
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
		$r = Get-Content -LiteralPath $json
		$r
		if ($PSVersionTable.PSVersion.Major -ge 3) {
			$r1, $r2 = $r | ConvertFrom-Json
			assert ($r1.Double -is [Decimal])
			assert ($r2.Int64 -is [Int32])
		}
	}
	finally {
		[MongoDB.Bson.IO.JsonWriterSettings]::Defaults.OutputMode = $old
	}
}
