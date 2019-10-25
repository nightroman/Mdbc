
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

task Constructors {
	# default
	$r = New-Object Mdbc.Dictionary
	equals $r.Count 0
	assert $r.ToBsonDocument()

	# from an object as _id
	$r = [Mdbc.Dictionary]42
	equals $r.Count 1
	equals $r._id '42'

	# from an existing document
	$d = New-Object MongoDB.Bson.BsonDocument
	$r = [Mdbc.Dictionary]$d.Add('name', 'name1') # `Add` gets the document
	equals $r.Count 1
	equals $r.name name1

	# from a bad object
	Test-Error { [Mdbc.Dictionary]$Host } '*cannot be mapped to a BsonValue.*'
}

# v4.8.0
task GetMissing {
	$d = New-MdbcData

	# get missing as null by []
	equals $d['missing']

	# dot notation fails in strict mode
	$$ = try { $d.missing } catch {$_}
	# v2,3 : Property...
	# v4   : The property...
	assert ($$ -like "*property 'missing' cannot be found on this object.*")
}

# $null should be preserved
task SetNull {
	$d = New-MdbcData @{x = 1; y = 2}
	$d.x = $null
	equals $d.Count 2
	equals $d.x
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
}

task Binary {
	# byte[] ~ BsonBinaryData
	$data1 = [Mdbc.Dictionary]([byte[]](1..5))
	$id1 = $data1._id
	equals ($id1.ToString()) Binary:0x0102030405
	equals ($id1.GetType().FullName) MongoDB.Bson.BsonBinaryData

	# comparison operator works
	$data2 = [Mdbc.Dictionary]([byte[]](1..5))
	assert ($id1 -eq $data2._id)

	# but UUID ~ guid
	$data3 = [Mdbc.Dictionary]([guid]'9c700f34-e28d-416d-8aa8-eb55f7781565')
	equals ($data3._id.ToString()) 9c700f34-e28d-416d-8aa8-eb55f7781565
	equals ($data3._id.GetType().FullName) System.Guid
	$doc3 = $data3.ToBsonDocument()
	equals ($doc3['_id'].SubType) ([MongoDB.Bson.BsonBinarySubType]::UuidStandard)

	# assign from .NET to document
	$data4 = [Mdbc.Dictionary]$id1
	$data4.p1 = $id1
	equals $data4._id $id1
	equals $data4.p1 $id1
}
