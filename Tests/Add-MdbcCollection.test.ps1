
Import-Module Mdbc

# How to create a capped collection by Add-MdbcCollection
task Add-MdbcCollection.Capped {
	Connect-Mdbc . test
	$null = $Database.DropCollection('capped')

	# add a capped collection (10 documents)
	Add-MdbcCollection capped -MaxSize 1mb -MaxDocuments 10

	# add 20 documents
	$Collection = $Database.GetCollection('capped')
	1..20 | %{@{Value=$_}} | Add-MdbcData

	# test: expected 10 last documents
	$data = Get-MdbcData
	assert ($data.Count -eq 10)
	assert ($data[0].Value -eq 11)
	assert ($data[9].Value -eq 20)

	# try to add again, test the error
	$message = ''
	try {
		Add-MdbcCollection capped -MaxSize 1mb -MaxDocuments 10
	}
	catch {
		$message = "$_"
	}
	assert ($message -eq @'
Command 'create' failed: collection already exists (response: { "ok" : 0.0, "errmsg" : "collection already exists" })
'@) $message

	# end
	$null = $Collection.Drop()
}
