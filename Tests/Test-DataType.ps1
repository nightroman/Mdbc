
<#
.SYNOPSIS
	Tests data types

.NOTES
	DateTime
		(Get-Date) is used in order to test [DateTime] wrapped by [PSObject].
		NB: [DateTime]::Now really gets [DateTime].

	BsonArray
		# fails: (Get-Date) is a PSObject => use New-MdbcData
		[MongoDB.Bson.BsonArray]($true, (Get-Date), ..)

		# New-Object requires this syntax => use New-MdbcData
		New-Object MongoDB.Bson.BsonArray (, ($true, 1.1, 1, 1L))
#>

Set-StrictMode -Version 2

Import-Module Mdbc
$collection = Connect-Mdbc mongodb://localhost test test -NewCollection

function Test-Document($document) {

	### Simple type values are obtained directly.

	if ($document.Boolean.GetType().Name -ne 'Boolean') { throw }
	if ($document.DateTime.GetType().Name -ne 'DateTime') { throw }
	if ($document.Double.GetType().Name -ne 'Double') { throw }
	if ($document.Guid.GetType().Name -ne 'Guid') { throw }
	if ($document.Int32.GetType().Name -ne 'Int32') { throw }
	if ($document.Int64.GetType().Name -ne 'Int64') { throw }
	if ($document.String.GetType().Name -ne 'String') { throw }

	### Arrays and documents are obtained as Mdbc* wrappers.

	if ($document.Array.GetType().FullName -ne 'Mdbc.Collection') { throw }
	if ($document.Document.GetType().FullName -ne 'Mdbc.Dictionary') { throw }

	### Other complex type objects are obtained as Bson* types.

	if ($document._id.GetType().Name -ne 'BsonObjectId') { throw }

	### Nested complex data
	# Documents still provide dot-notation.
	# Simple type values are still as they are.

	if ($document.Array[1].GetType().Name -ne 'DateTime') { throw }
	if ($document.Document.DateTime.GetType().Name -ne 'DateTime') { throw }
}

### [Mdbc.Dictionary] wraps [BsonDocument] and enables dot-notation

$data = New-MdbcData

### Simple types (dot-notation gets the same values)

$data.Boolean = $true
$data.DateTime = (Get-Date)
$data.Double = 1.1
$data.Guid = [guid]'7972366c-fd4e-401d-9a53-4390114a2eba'
$data.Int32 = 1
$data.Int64 = 1L
$data.String = 'string 1'

### Complex types (converted to and returned as BSON types)

$data._id = [MongoDB.Bson.ObjectId]::GenerateNewId()
$data.Array = $true, (Get-Date), 1.1, $data.Guid, 1, 1L
$data.Document = @{ _id = 12345; DateTime = (Get-Date) }

# test the new document
Test-Document $data

# add the existing document
$data | Add-MdbcData $collection

# create/add a document on-the-fly
Add-MdbcData $collection @{
	Boolean = $false
	DateTime = (Get-Date)
	Double = 2.2
	Guid = [guid]'1b3f04e5-d3f5-4b2c-a75d-b639b91daf4f'
	Int32 = 2
	Int64 = 2L
	String = 'string 2'
	Array = @(
		$false
		(Get-Date)
	)
	Document = @{
		Boolean = $false
		DateTime = (Get-Date)
	}
}

# get the documents back
$data = Get-MdbcData $collection
if ($data.Count -ne 2) { throw }

# test requested documents
$data | %{ Test-Document $_ }
