
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version 2

task DataTypes {
	Connect-Mdbc -NewCollection

	function Test-Document($document) {

		### Simple type values are obtained directly.

		Test-Type $document.Boolean System.Boolean
		Test-Type $document.DateTime System.DateTime
		Test-Type $document.Double System.Double
		Test-Type $document.Guid System.Guid
		Test-Type $document.Int32 System.Int32
		Test-Type $document.Int64 System.Int64
		Test-Type $document.String System.String

		### Arrays and documents are obtained as Mdbc* wrappers.

		Test-Type $document.Array Mdbc.Collection
		Test-Type $document.Document Mdbc.Dictionary

		### Other complex type objects are obtained as Bson* types.

		Test-Type $document._id MongoDB.Bson.ObjectId

		### Nested complex data
		# Documents still provide dot-notation.
		# Simple type values are still as they are.

		Test-Type $document.Array[1] System.DateTime
		Test-Type $document.Document.DateTime System.DateTime
	}

	### [Mdbc.Dictionary] wraps [BsonDocument] and enables dot-notation

	$data = New-MdbcData

	### Simple types (dot-notation gets the same values)

	$data.Boolean = $true
	$data.DateTime = (Get-Date)
	$data.Double = 1.1
	$data.Guid = [guid]'7972366c-fd4e-401d-9a53-4390114a2eba'
	$data.Int32 = 1
	$data.Int64 = 1L
	$data.String = 'string 1'

	### Complex types (converted to and returned as BSON types)

	$data._id = [MongoDB.Bson.ObjectId]::GenerateNewId()
	$data.Array = $true, (Get-Date), 1.1, $data.Guid, 1, 1L
	$data.Document = @{ _id = 12345; DateTime = (Get-Date) }

	# test the new document
	Test-Document $data

	# add the existing document
	$data | Add-MdbcData

	# create/add a document on-the-fly
	Add-MdbcData @{
		Boolean = $false
		DateTime = (Get-Date)
		Double = 2.2
		Guid = [guid]'1b3f04e5-d3f5-4b2c-a75d-b639b91daf4f'
		Int32 = 2
		Int64 = 2L
		String = 'string 2'
		Array = @(
			$false
			(Get-Date)
			@{ Boolean = $false; DateTime = (Get-Date) }
		)
		Document = @{
			Boolean = $false
			DateTime = (Get-Date)
			Array = $false, (Get-Date)
		}
	}

	# get the documents back
	$data = Get-MdbcData
	assert ($data.Count -eq 2)

	# test requested documents
	$data | %{ Test-Document $_ }

	# get as PS objects
	$data = Get-MdbcData -AsCustomObject
	assert ($data.Count -eq 2)
}

task New-MdbcData.HashtableToDocument {
	$HashToDocument = New-MdbcData @{ String = 'Hi'; Date = (Get-Date) }
	Test-Type $HashToDocument Mdbc.Dictionary

	$new = New-MdbcData
	$new.Document = @{ String = 'Hi'; Date = (Get-Date) }
	Test-Type $new.Document Mdbc.Dictionary

	#! fixed
	$new.Document = New-MdbcData @{ String = 'Hi'; Date = (Get-Date) }
	Test-Type $new.Document Mdbc.Dictionary
}

task New-MdbcData.-Value {
	Test-Type (New-MdbcData -Value $null) MongoDB.Bson.BsonNull

	Test-Type (New-MdbcData -Value $true) MongoDB.Bson.BsonBoolean
	Test-Type (New-MdbcData -Value (Get-Date)) MongoDB.Bson.BsonDateTime
	Test-Type (New-MdbcData -Value 1.1) MongoDB.Bson.BsonDouble
	Test-Type (New-MdbcData -Value ([guid]::NewGuid())) MongoDB.Bson.BsonBinaryData
	Test-Type (New-MdbcData -Value 1) MongoDB.Bson.BsonInt32
	Test-Type (New-MdbcData -Value 1L) MongoDB.Bson.BsonInt64
	Test-Type (New-MdbcData -Value text) MongoDB.Bson.BsonString

	Test-Type (New-MdbcData -Value @()) MongoDB.Bson.BsonArray
	Test-Type (New-MdbcData -Value @{}) MongoDB.Bson.BsonDocument
}

task New-MdbcData.PSCustomObject {
	$property = @{n='_id'; e='Id'}, 'Name', 'StartTime', 'WorkingSet64'

	### One custom object as an argument
	$custom = Get-Process mongod | Select-Object $property -First 1
	Test-Type (New-MdbcData $custom) Mdbc.Dictionary

	### Many custom objects from pipeline
	$documents = Get-Process svchost | Select-Object $property | New-MdbcData
	foreach($_ in $documents) {
		Test-Type $_ Mdbc.Dictionary
	}
}

task New-MdbcData.KeepNullValues {
	$d = 1 | Select-Object p1, p2 | New-MdbcData
	assert ($d.Count -eq 2 -and $d.Contains('p1') -and $d.Contains('p2'))

	$d = @{p1 = $null; p2 = $null} | New-MdbcData
	assert ($d.Count -eq 2 -and $d.Contains('p1') -and $d.Contains('p2'))
}

task New-MdbcData.KeepProblemValues {
	$d = (Get-Process -Id $Pid) | New-MdbcData -Property Name, ExitCode
	assert ($d.Count -eq 2 -and $d.Name -and $d.Contains('ExitCode') -and $null -eq $d.ExitCode)
}

task New-MdbcData.KeysMustBeStrings {
	$d = @{}
	$d[1] = 1
	Test-Error {$d | New-MdbcData} 'Dictionary keys must be strings.'
}

task New-MdbcData.MissingProperty {
	$d = New-MdbcData $Host -Property Name, Missing
	assert ($d.Count -eq 1 -and $d.Name)

	$d = @{Name = 'Name1'} | New-MdbcData -Property Name, Missing
	assert ($d.Count -eq 1 -and $d.Name)
}

# This code is used as example
task New-MdbcData.-Property {
	$p = Get-Process -Id $Pid
	$d = $p | New-MdbcData -Property `
	    Name,                     # existing property name
		Missing,                  # missing property name is ignored
		@{WS1='WS'},              # @{name = old name} - renamed property
		@{WS2={$_.WS}},           # @{name = scriptblock} - calculated field
		@{Ignored='Missing'},     # renaming of a missing property is ignored
		@{n='_id'; e='Id'},       # @{name=...; expression=...} like Select-Object does
		@{l='Code'; e='ExitCode'} # @{label=...; expression=...} another like Select-Object

	assert ($d.Count -eq 5)
	assert ($d.Name -eq $p.Name)
	assert ($d.WS1 -eq $p.WS)
	assert ($d.WS2 -eq $p.WS)
	assert ($d._id -eq $p.Id)
	assert ($d.Contains('Code') -and $null -eq $d.Code)
}

task New-MdbcData.-Convert {
	# error due to unknown data
	Test-Error {New-MdbcData $Host} ".NET type * cannot be mapped to a BsonValue."

	# error due to a bad converter
	Test-Error {New-MdbcData $Host -Convert {throw 'Oops'}} 'Converter script was called on "* cannot be mapped to a BsonValue." and failed with "Oops".'

	# convert unknown to nulls
	$r = New-MdbcData $Host -Convert {}
	assert ($r.Contains('Version') -and $null -eq $r.Version)

	# ditto
	$r = New-MdbcData $Host -Convert {$null}
	assert ($r.Contains('Version') -and $null -eq $r.Version)

	# convert unknowns to strings
	$r = New-MdbcData $Host -Convert {"$_"}
	Test-Type $r.Version System.String
}

task New-MdbcData.Cyclic {
	# dictionary
	$d = @{}
	$d.p1 = $d
	Test-Error { New-MdbcData $d } 'Cyclic reference.'

	# complex
	$d = New-Object PSObject -Property @{Document=$null}
	$d.Document = $d
	Test-Error { New-MdbcData $d } 'Cyclic reference.'

	# array
	$a = [Collections.ArrayList]@()
	$null = $a.Add($a)
	Test-Error { New-MdbcData -Value $a } 'Cyclic reference.'

	#! not a cycle
	$d = @{x = 1}
	$d = @{array = $d, $d} | New-MdbcData
	assert ($d.array.Count -eq 2)
}
