
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

task Constructors {
	# default
	$r = New-Object Mdbc.Dictionary
	assert ($r.Count -eq 0 -and $null -ne $r.ToBsonDocument())

	# from an object as _id
	$r = [Mdbc.Dictionary]42
	assert ($r.Count -eq 1 -and $r._id -eq 42)

	# from an existing document
	$d = New-Object MongoDB.Bson.BsonDocument
	$r = [Mdbc.Dictionary]$d.Add('name', 'name1') # `Add` gets the document
	assert ($r.Count -eq 1 -and $r.name -eq 'name1')

	# from a bad object
	Test-Error { [Mdbc.Dictionary]$Host } '*cannot be mapped to a BsonValue.*'
}

# v4.8.0
task GetMissing {
	$d = New-MdbcData

	# get missing as null by []
	assert ($null -eq $d['missing'])

	# dot notation fails in strict mode
	$$ = try { $d.missing } catch {$_}
	assert ($$ -like "Property 'missing' cannot be found on this object.*")
}

# $null should be preserved
task SetNull {
	$d = New-MdbcData @{x = 1; y = 2}
	$d.x = $null
	assert ($d.Count -eq 2 -and $d.x -eq $null)
}

task RawBson {

	# RawBsonDocument
	Connect-Mdbc -NewCollection
	@{array = 1, 2; document = @{name = 42}} | Add-MdbcData
	$raw = Get-MdbcData -As ([MongoDB.Bson.RawBsonDocument])
	Test-Type $raw MongoDB.Bson.RawBsonDocument

	#_131015_123005 New-MdbcData makes new even on read only RawBsonDocument
	$md = New-MdbcData $raw
	assert (!$md.IsFixedSize)
	assert (!$md.IsReadOnly)
	Test-Type $md.ToBsonDocument() MongoDB.Bson.BsonDocument

	#
	$md = [Mdbc.Dictionary]$raw
	assert ($md.IsFixedSize)
	assert ($md.IsReadOnly)
	Test-Type $md.ToBsonDocument() MongoDB.Bson.RawBsonDocument

	&{
		$a = $md.array
		assert ($a.IsFixedSize)
		assert ($a.IsReadOnly)
		assert ($a.Array().IsReadOnly) # fixed https://jira.mongodb.org/browse/CSHARP-842
		Test-Type $a.Array() MongoDB.Bson.RawBsonArray
		assert (![object]::ReferenceEquals($a.Array(), $md.array.Array()))
	}

	&{
		$d = $md.document
		assert ($d.IsFixedSize)
		assert ($d.IsReadOnly)
		Test-Type $d.ToBsonDocument() MongoDB.Bson.RawBsonDocument
		assert (![object]::ReferenceEquals($d.ToBsonDocument(), $md.document.ToBsonDocument()))
	}

	$md.Dispose(); $md.Dispose() #! twice is fine
}
