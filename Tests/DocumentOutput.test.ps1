<#
.Synopsis
	Common tests for cmdlets with parameter -As
#>

. ./Zoo.ps1
Connect-Mdbc -NewCollection
Set-StrictMode -Version Latest

# To be sure the enum values are fine, e.g. PSObject was a bad name for enum
# value. Also, if this fails update the manuals.
task Enum {
	assert ([enum]::GetValues([Mdbc.OutputType]).Count -eq 2)
	assert (0 -eq [Mdbc.OutputType]::Default)
	assert (1 -eq [Mdbc.OutputType]::PS)
}

task As {
	# input data
	$data = @{_id = 1; document = @{array = 1, 2}}
	$data | Add-MdbcData
	$data | Export-MdbcData z.bson

	$testMembers = $true
	function Test-Member {
		if ($testMembers) {
			Test-Type $r.document Mdbc.Dictionary
			Test-Type $r.document.array Mdbc.Collection
		}
	}

	Invoke-Test {
		Test-Error { test -As bad } '*"As": "Cannot convert the "bad" value of type "System.String" to type "System.Type"."'

		'Default 1'
		$r = test
		Test-Type $r Mdbc.Dictionary
		Test-Member

		'Default 2'
		$r = test -As Default
		Test-Type $r Mdbc.Dictionary
		Test-Member

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
	}

	Remove-Item z.bson
}
