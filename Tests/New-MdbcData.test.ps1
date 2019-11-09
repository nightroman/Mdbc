
. ./Zoo.ps1
Set-StrictMode -Version Latest

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
	equals $data.Count 2

	# test requested documents
	$data | .{process{ Test-Document $_ }}

	# get as PS objects
	$data = Get-MdbcData -As PS
	equals $data.Count 2
}

task HashtableToDocument {
	$HashToDocument = New-MdbcData @{ String = 'Hi'; Date = (Get-Date) }
	Test-Type $HashToDocument Mdbc.Dictionary

	$new = New-MdbcData
	$new.Document = @{ String = 'Hi'; Date = (Get-Date) }
	Test-Type $new.Document Mdbc.Dictionary

	#! fixed
	$new.Document = New-MdbcData @{ String = 'Hi'; Date = (Get-Date) }
	Test-Type $new.Document Mdbc.Dictionary
}

task PSCustomObject {
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

task KeepNullValues {
	$d = 1 | Select-Object p1, p2 | New-MdbcData
	equals $d.Count 2
	assert $d.Contains('p1')
	assert $d.Contains('p2')

	$d = @{p1 = $null; p2 = $null} | New-MdbcData
	equals $d.Count 2
	assert $d.Contains('p1')
	assert $d.Contains('p2')
}

task KeepProblemValues {
	$d = (Get-Process -Id $Pid) | New-MdbcData -Property Name, ExitCode
	equals $d.Count 2
	assert $d.Name
	assert $d.Contains('ExitCode')
	equals $d.ExitCode
}

task KeysMustBeStrings {
	$d = @{}
	$d[1] = 1
	Test-Error {$d | New-MdbcData} 'Dictionary keys must be strings.'
}

task MissingProperty {
	$d = New-MdbcData $Host -Property Name, Missing
	equals $d.Count 1
	assert $d.Name

	$d = @{Name = 'Name1'} | New-MdbcData -Property Name, Missing
	equals $d.Count 1
	assert $d.Name
}

# This code is used as example
task Property {
	$p = Get-Process -Id $Pid
	$d = $p | New-MdbcData -Property `
	    Name,                     # existing property name
		Missing,                  # missing property name is ignored
		@{WS1='WS'},              # @{name = old name} - renamed property
		@{WS2={$_.WS}},           # @{name = scriptblock} - calculated field
		@{Ignored='Missing'},     # renaming of a missing property is ignored
		@{n='_id'; e='Id'},       # @{name=...; expression=...} like Select-Object does
		@{l='Code'; e='ExitCode'} # @{label=...; expression=...} another like Select-Object

	equals $d.Count 5
	equals $d.Name $p.Name
	equals $d.WS1 $p.WS
	equals $d.WS2 $p.WS
	equals $d._id $p.Id
	assert $d.Contains('Code')
	equals $d.Code
}

task Convert {
	$zoo1 = Zoo1

	# error due to unknown data
	Test-Error {New-MdbcData @{data = $zoo1}} "Cannot convert 'Zoo1.T' to 'BsonValue'."

	# error due to a bad converter
	Test-Error {New-MdbcData @{data = $zoo1} -Convert {throw 'Oops'}} "Converter script was called for 'Zoo1.T' and failed with 'Oops'."

	# convert unknown to nulls
	$r = New-MdbcData @{p1 = 1; p2 = $Host} -Convert {}
	assert $r.Contains('p2')
	equals $r.p2

	# ditto
	$r = New-MdbcData @{p1 = 1; p2 = $Host} -Convert {$null}
	assert $r.Contains('p2')
	equals $r.p2

	# convert unknowns to strings
	$r = New-MdbcData @{p1 = 1; p2 = $Host} -Convert {"$_"}
	Test-Type $r.p2 System.String
}

task Cyclic {
	$message = '*Data exceed the default maximum serialization depth.'

	# dictionary
	$d = @{}
	$d.p1 = $d
	Test-Error { New-MdbcData $d } $message

	# complex
	$d = New-Object PSObject -Property @{Document=$null}
	$d.Document = $d
	Test-Error { New-MdbcData $d } $message

	#! not a cycle
	$d = @{x = 1}
	$d = @{array = $d, $d} | New-MdbcData
	equals $d.array.Count 2
}

<#
	Variable $_ is restored on invoking scripts
	+ 180402 https://github.com/nightroman/Mdbc/issues/19
		but it is not easy to make a test to cover #19,
		looks like it happens in interactive only
#>
task SetDollar {
	$log = [Collections.ArrayList]@(); function log {$null = $log.AddRange($args)}

	# loop make the $_
	'original' | .{process{
		# Id
		$null = New-MdbcData @{name = 'name1'} -Id {log $_.name; 42}
		equals $_ 'original'

		# Select
		$null = New-MdbcData @{name = 'name2'} -Property @{name2 = {log $_.name; 42}}
		equals $_ 'original'

		# Convert
		$null = New-MdbcData $host -Property Version -Convert {log $_.GetType().Name}
		equals $_ 'original'
	}}

	$log

	Test-List $log @(
		'name1'
		'name2'
		'Version'
	)
}
