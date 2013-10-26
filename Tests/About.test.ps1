
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

	# Connect the database 'test' and the new collection 'test'
	Connect-Mdbc . test test -NewCollection

	# Add some data (Id as _id, Name, and WorkingSet of current processes)
	Get-Process | Add-MdbcData -Id {$_.Id} -Property Name, WorkingSet

	# Query all data back as custom objects and print them formatted
	Get-MdbcData -As PS | Format-Table -AutoSize | Out-String

	# Get saved data of the process 'mongod' (expected at least one)
	$data = Get-MdbcData (New-MdbcQuery Name -EQ mongod)
	$data

	# Update these data (let's just set the WorkingSet to 12345)
	$data | Update-MdbcData (New-MdbcUpdate -Set @{WorkingSet = 12345})

	# Query again in order to take a look at the changed data
	Get-MdbcData (New-MdbcQuery Name -EQ mongod)

	# Remove these data
	$data | Remove-MdbcData

	# Query again, just get the count, 0 is expected
	Get-MdbcData (New-MdbcQuery Name -EQ mongod) -Count
}

# Test type names in Mdbc.Format.ps1xml
task ModuleFormatFile {
	Select-Xml -Path ..\Module\Mdbc.Format.ps1xml -XPath //TypeName | .{process{
		# create a type, it fails on not valid types
		Invoke-Expression "[$($_.Node.InnerText)]"
	}}
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

task Connect-Mdbc {
	Test-Error {Connect-Mdbc -DatabaseName test} 'ConnectionString parameter is null or missing.'
	Test-Error {Connect-Mdbc -CollectionName test} 'ConnectionString parameter is null or missing.'

	Connect-Mdbc
	Test-Type $Server MongoDB.Driver.MongoServer
	Test-Type $Database MongoDB.Driver.MongoDatabase
	Test-Type $Collection MongoDB.Driver.MongoCollection
	assert ($Database.Name -ceq 'test')
	assert ($Collection.Name -ceq 'test')
}

# Variable $_ is restored on invoking scripts
task SetDollar {
	$log = [Collections.ArrayList]@(); function log {$null = $log.AddRange($args)}

	# loop make the $_
	'SetDollar' | .{process{
		# Id
		$null = New-MdbcData @{name = 'name1'} -Id {log $_.name; 42}
		assert ($_ -eq 'SetDollar')

		# Select
		$null = New-MdbcData @{name = 'name2'} -Property @{name2 = {log $_.name; 42}}
		assert ($_ -eq 'SetDollar')

		# Convert
		$null = New-MdbcData $host -Property Runspace -Convert {log "$_"}
		assert ($_ -eq 'SetDollar')
	}}

	$log

	Test-List $log @(
		'name1'
		'name2'
		'System.Management.Automation.Runspaces.LocalRunspace'
	)
}

task PublicTypes {
	$types = [Reflection.Assembly]::GetAssembly(([Mdbc.Dictionary])).GetTypes() | ?{$_.IsPublic} | Sort-Object Name | Select-Object -ExpandProperty Name
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
