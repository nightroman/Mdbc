
<#
.Synopsis
	Assorted tests.
#>

. .\Zoo.ps1
Import-Module Mdbc

# Quick start code used in README.md
task About {
	# Load the module
	Import-Module Mdbc

	# Connect the new collection test.test
	Connect-Mdbc . test test -NewCollection

	# Add some test data
	@{_id=1; value=42}, @{_id=2; value=3.14} | Add-MdbcData

	# Get all data as custom objects and show them in a table
	Get-MdbcData -As PS | Format-Table -AutoSize | Out-String

	# Query a document by _id using a query expression
	$data = Get-MdbcData (New-MdbcQuery _id -EQ 1)
	$data

	# Update the document, set the 'value' to 100
	$data._id | Update-MdbcData (New-MdbcUpdate -Set @{value = 100})

	# Query the document using a simple _id query
	Get-MdbcData $data._id

	# Remove the document
	$data._id | Remove-MdbcData

	# Count remaining documents, 1 is expected
	Get-MdbcData -Count
}

# Test the function Test-Table
task Test-Table {
	Test-Error { Test-Table @{x=1} @{} } 'Different dictionary counts: 1 and 0.'
	Test-Error { Test-Table @{x=1} @{y=1} } 'Second dictionary (x) entry is missing.'
	Test-Error { Test-Table @{x=$null} @{x=2} } 'Different dictionary (x) nulls: True and False.'
	Test-Error { Test-Table @{x='One'} @{x=2} } 'Different dictionary (x) types: string and int.'
	Test-Error { Test-Table @{x=1} @{x=2} } 'Different dictionary (x) values: (1) and (2).'
	Test-Table @{x=@{x=1}} @{x=@{x=1}}
}

# Test the function Invoke-Test
task Invoke-Test {
	$log = [Collections.ArrayList]@()
	function log { $null = $log.AddRange($args) }

	# default context
	$end = {log 'do end 0'}

	# the first test script is invoked after each context script
	Invoke-Test {
		# test script
		log 'test begin'
		. $begin

		log 'test end'
		. $end
	}{
		# context script 1
		$begin = {
			log 'do begin1'
		}
		$end = {
			log 'do end1'
		}
	}{
		# context script 2
		$begin = {
			log 'begin2'
		}
	}

	# show and test the log
	$log
	Test-List $log @(
		'test begin'
		'do begin1'
		'test end'
		'do end1'
		'test begin'
		'begin2'
		'test end'
		'do end 0'
	)
}

# Variable $_ is restored on invoking scripts
task SetDollar {
	$log = [Collections.ArrayList]@(); function log {$null = $log.AddRange($args)}

	# loop make the $_
	'original' | .{process{
		# Id
		$null = New-MdbcData @{name = 'name1'} -Id {log $_.name; 42}
		assert ($_ -eq 'original')

		# Select
		$null = New-MdbcData @{name = 'name2'} -Property @{name2 = {log $_.name; 42}}
		assert ($_ -eq 'original')

		# Convert
		$null = New-MdbcData $host -Property Version -Convert {log $_.GetType().Name}
		assert ($_ -eq 'original')
	}}

	$log

	Test-List $log @(
		'name1'
		'name2'
		'Version'
	)
}

# Only these types are exposed
task PublicTypes {
	$types = [Reflection.Assembly]::GetAssembly(([Mdbc.Dictionary])).GetTypes() | .{process{ if ($_.IsPublic) {$_.Name} }} | Sort-Object
	Test-List $types @(
		'Abstract'
		'AbstractCollectionCommand'
		'AbstractDatabaseCommand'
		'AbstractWriteCommand'
		'AddCollectionCommand'
		'AddDataCommand'
		'Collection'
		'ConnectCommand'
		'Dictionary'
		'ExportDataCommand'
		'FileFormat'
		'GetDataCommand'
		'ImportDataCommand'
		'InvokeAggregateCommand'
		'InvokeCommandCommand'
		'InvokeMapReduceCommand'
		'LazyDictionary'
		'NewDataCommand'
		'NewQueryCommand'
		'NewUpdateCommand'
		'OpenFileCommand'
		'OutputType'
		'QueryCompiler'
		'RawDictionary'
		'RemoveDataCommand'
		'SaveFileCommand'
		'UpdateCompiler'
		'UpdateDataCommand'
	)
}
