
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
	# mongo 3.2.11 :: failed: collection already exists
	# mongo 3.4.1  :: failed: a collection 'test.test' already exists
	Test-Error {Add-MdbcCollection test -MaxSize 1mb -MaxDocuments 10} "Command create failed: *collection *already exists*"
}
