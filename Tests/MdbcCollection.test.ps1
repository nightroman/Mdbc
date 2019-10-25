
. ./Zoo.ps1

# How to create a capped collection by Add-MdbcCollection
task AddCapped {
	# add a capped collection (10 documents)
	Connect-Mdbc -NewCollection
	$options = New-Object MongoDB.Driver.CreateCollectionOptions
	$options.Capped = $true
	$options.MaxSize = 1mb
	$options.MaxDocuments = 10
	Add-MdbcCollection test -Options $options

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
	Test-Error {Add-MdbcCollection test -Options $options} "Command create failed: *collection *already exists*"
}

task RenameAndRemove {
	Connect-Mdbc . test

	# new test1 with one document
	$c1 = Get-MdbcCollection test1 -NewCollection
	Add-MdbcData @{_id = 16} -Collection $c1

	# new test2, empty
	$c2 = Get-MdbcCollection test2 -NewCollection

	# test1 -> test2, works without -Force because test2 is not yet created
	Rename-MdbcCollection test1 test2

	# $c1 ~ test1, it is empty; $c2 has 1 item _id = 16
	equals $c1.CollectionNamespace.CollectionName test1
	equals (Get-MdbcData -Collection $c1) $null
	equals (Get-MdbcData -Collection $c2)._id 16

	# add another item to test1 and repeat
	Add-MdbcData @{_id = 17} -Collection $c1

	# test1 -> test2, fails without -Force because test2 is not empty
	Test-Error { Rename-MdbcCollection test1 test2 } 'Command renameCollection failed: target namespace exists.'

	# test1 -> test2, works with -Force
	Rename-MdbcCollection test1 test2 -Force

	# test1 is empty; $c2 has 1 item _id = 17
	equals (Get-MdbcData -Collection $c1) $null
	equals (Get-MdbcData -Collection $c2)._id 17

	# remove test2
	Remove-MdbcCollection test2
	equals (Get-MdbcData -Collection $c2) $null
}
