<#
.Synopsis
	Assorted tests.
#>

. ./Zoo.ps1

# Quick start code from README, ensure it works
task README {
	$r = $(
		# Load the module
		Import-Module Mdbc

		# Connect the new collection test.test
		Connect-Mdbc . test test -NewCollection

		# Add two documents
		@{_id = 1; value = 42}, @{_id = 2; value = 3.14} | Add-MdbcData

		# Get documents as PS objects
		Get-MdbcData -As PS | Format-Table

		# Get the document by _id
		Get-MdbcData @{_id = 1}

		# Update the document, set 'value' to 100
		Update-MdbcData @{_id = 1} @{'$set' = @{value = 100}}

		# Get the document again, 'value' is 100
		$doc = Get-MdbcData @{_id = 1}

		# Remove the document
		$doc | Remove-MdbcData

		# Count documents, 1
		Get-MdbcData -Count
	)
	equals $r[-1] 1L
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

# Only these types are exposed
task PublicTypes {
	($types = [Reflection.Assembly]::GetAssembly(([Mdbc.Dictionary])).GetTypes() | .{process{ if ($_.IsPublic) {$_.Name} }} | Sort-Object)
	Test-List $types @(
		'Abstract'
		'AbstractClientCommand'
		'AbstractCollectionCommand'
		'AbstractDatabaseCommand'
		'AbstractDatabaseCommand2'
		'AbstractSessionCommand'
		'AddCollectionCommand'
		'AddDataCommand'
		'Api'
		'Collection'
		'ConnectCommand'
		'Dictionary'
		'ExportDataCommand'
		'FileFormat'
		'GetCollectionCommand'
		'GetDatabaseCommand'
		'GetDataCommand'
		'ImportDataCommand'
		'InvokeAggregateCommand'
		'InvokeCommandCommand'
		'ModuleAssemblyInitializer'
		'NewDataCommand'
		'OutputType'
		'RegisterClassMapCommand'
		'RemoveCollectionCommand'
		'RemoveDatabaseCommand'
		'RemoveDataCommand'
		'RenameCollectionCommand'
		'Res'
		'SetDataCommand'
		'UpdateDataCommand'
		'UseTransactionCommand'
		'WatchChangeCommand'
	)
}
