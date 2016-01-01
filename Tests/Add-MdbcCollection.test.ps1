
. .\Zoo.ps1
Import-Module Mdbc

# How to create a capped collection by Add-MdbcCollection
task Capped {
	# add a capped collection (10 documents)
	Connect-Mdbc -NewCollection
	Add-MdbcCollection test -MaxSize 1mb -MaxDocuments 10

	# add 20 documents
	1..20 | .{process{ @{Value=$_}} } | Add-MdbcData

	# test: expected 10 last documents
	$data = Get-MdbcData
	equals $data.Count 10
	equals $data[0].Value 11
	equals $data[9].Value 20

	# try to add again, test the error
	Test-Error {Add-MdbcCollection test -MaxSize 1mb -MaxDocuments 10} "Command 'create' failed: collection already exists*"
}

task AutoIndexId {
	# AutoIndexId 0
	Connect-Mdbc -NewCollection
	Add-MdbcCollection test -AutoIndexId 0

	$Collection = $Database['test']
	@{n = 1} | Add-MdbcData
	$d = Get-MdbcData
	assert ($d._id)
	$i = @($Collection.GetIndexes())
	equals $i.Count 0 # was 1, fixed https://jira.mongodb.org/browse/CSHARP-841

	# default collection
	Connect-Mdbc -NewCollection
	Add-MdbcCollection test

	$Collection = $Database['test']
	@{n = 1} | Add-MdbcData
	$d = Get-MdbcData
	assert ($d._id)
	$i = @($Collection.GetIndexes())
	equals $i.Count 1
}
