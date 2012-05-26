
<#
.Synopsis
	How to use Add-MdbcCollection for a capped collection.
#>

Import-Module Mdbc
Connect-Mdbc . test
$null = $Database.DropCollection('capped')

# add a capped collection (10 documents)
Add-MdbcCollection capped -MaxSize 1mb -MaxDocuments 10

# add 20 documents
$Collection = $Database.GetCollection('capped')
1..20 | %{@{Value=$_}} | Add-MdbcData

# test: expected 10 last documents
$data = Get-MdbcData
if ($data.Count -ne 10) {throw}
if ($data[0].Value -ne 11) {throw}
if ($data[9].Value -ne 20) {throw}

# try to add again, test the error
$message = ''
try {
	Add-MdbcCollection capped -MaxSize 1mb -MaxDocuments 10
}
catch {
	$message = "$_"
}
if ($message -ne @'
Command 'create' failed: collection already exists (response: { "errmsg" : "collection already exists", "ok" : 0.0 })
'@) {throw}
