
<#
.Synopsis
	How to use Add-MdbcCollection for a capped collection.
#>

Import-Module Mdbc
$database = Connect-Mdbc . test
$null = $database.DropCollection('capped')

# add a capped collection (10 documents)
Add-MdbcCollection $database capped -MaxSize 1mb -MaxDocuments 10

# add 20 documents
$collection = $database.GetCollection('capped')
1..20 | %{@{Value=$_}} | Add-MdbcData $collection

# test: expected 10 last documents
$data = Get-MdbcData $collection
if ($data.Count -ne 10) {throw}
if ($data[0].Value -ne 11) {throw}
if ($data[9].Value -ne 20) {throw}

# try to add again, test the error
$message = ''
try {
	Add-MdbcCollection $database capped -MaxSize 1mb -MaxDocuments 10
}
catch {
	$message = "$_"
}
if ($message -ne @'
Command 'create' failed: collection already exists (response: { "errmsg" : "collection already exists", "ok" : 0.0 })
'@) {throw}
