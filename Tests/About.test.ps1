
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
	Get-MdbcData -AsCustomObject | Format-Table -AutoSize | Out-String

	# Get saved data of the process 'mongod' (expected at least one)
	$data = Get-MdbcData (New-MdbcQuery Name -EQ mongod)
	$data

	# Update these data (let's just set the WorkingSet to 12345)
	$data | Update-MdbcData (New-MdbcUpdate WorkingSet -Set 12345)

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

# Test the function Test-Dictionary
task Test-Dictionary {
	Test-Error { Test-Dictionary @{x=1} @{} } 'Different counts: 1 and 0.'
	Test-Error { Test-Dictionary @{x=1} @{y=1} } "Second dictionary is missing key 'x'."
	Test-Error { Test-Dictionary @{x=1} @{x=2} } "Key 'x' has different values: '1' and '2'."
	Test-Error { Test-Dictionary @{x=$null} @{x=2} } "Key 'x' has different nulls: True and False."
	Test-Error { Test-Dictionary @{x='One'} @{x=2} } "Key 'x' has different types: string and int."
	Test-Dictionary @{x=@{x=1}} @{x=@{x=1}}
}

# Test the function Invoke-Test
task Invoke-Test {
	$log = [Collections.Generic.List[string]]@()

	# default context
	$end = {$log.Add('do end 0')}

	# the first test script is invoked after each context script
	Invoke-Test {
		# test script
		$log.Add('test begin')
		. $begin

		$log.Add('test end')
		. $end
	}{
		# context script 1
		$begin = {
			$log.Add('do begin1')
		}
		$end = {
			$log.Add('do end1')
		}
	}{
		# context script 2
		$begin = {
			$log.Add('begin2')
		}
	}

	# show and test the log
	$log
	Test-Array $log @(
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
