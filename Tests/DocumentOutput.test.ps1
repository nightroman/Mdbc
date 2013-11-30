
<#
.Synopsis
	Common tests for Get-MdbcData, Import-MdbcData, Invoke-MdbcMapReduce
#>

. .\Zoo.ps1
Import-Module Mdbc
Connect-Mdbc -NewCollection
Set-StrictMode -Version Latest

# To be sure the enum values are fine, e.g. PSObject was a bad name for enum
# value. Also, if this fails update the manuals.
task Enum {
	assert ([enum]::GetValues([Mdbc.OutputType]).Count -eq 4)
	assert (0 -eq [Mdbc.OutputType]::Default)
	assert (1 -eq [Mdbc.OutputType]::Lazy)
	assert (2 -eq [Mdbc.OutputType]::Raw)
	assert (3 -eq [Mdbc.OutputType]::PS)
}

task As {
	# input data
	$data = @{_id = 1; document = @{array = 1, 2}}
	$data | Add-MdbcData
	$data | Export-MdbcData z.bson

	$testMembers = $true
	function Test-Memebers {
		if ($testMembers) {
			Test-Type $r.document Mdbc.Dictionary
			Test-Type $r.document.array Mdbc.Collection
		}
	}

	Invoke-Test {
		Test-Error { test -As bad } '*Default, Lazy, Raw, PS"*'

		'Default 1'
		$r = test
		Test-Type $r Mdbc.Dictionary
		Test-Memebers

		'Default 2'
		$r = test -As Default
		Test-Type $r Mdbc.Dictionary
		Test-Memebers

		'Lazy'
		$r = test -As Lazy
		Test-Type $r Mdbc.LazyDictionary
		Test-Type $r.ToBsonDocument() MongoDB.Bson.LazyBsonDocument
		Test-Memebers

		'Raw'
		$r = test -As Raw
		Test-Type $r Mdbc.RawDictionary
		Test-Type $r.ToBsonDocument() MongoDB.Bson.RawBsonDocument
		Test-Memebers

		'PS'
		$r = test -As PS
		Test-Type $r System.Management.Automation.PSCustomObject

		'BsonDocument'
		$r = test -As ([MongoDB.Bson.BsonDocument])
		Test-Type $r MongoDB.Bson.BsonDocument
	}{
		function test($As) { Get-MdbcData @PSBoundParameters }
	}{
		function test($As) { Import-MdbcData z.bson @PSBoundParameters }
	}{
		$map = 'function() { emit(this._id, this) }'
		$reduce = 'function(key, emits) { return emits }'
		$testMembers = $false
		function test($As) { Invoke-MdbcMapReduce $map, $reduce @PSBoundParameters }
	}

	Remove-Item z.bson
}
