
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version 2

function query($expected, $query) {
	$count = Get-MdbcData -Count $query
	if ($expected -ne $count) {
		Write-Error -ErrorAction 1 "Expected count: $expected, actual: $count."
	}
}

# $null should be preserved
task Dictionary.SetNull {
	$d = New-MdbcData @{x = 1; y = 2}
	$d.x = $null
	assert ($d.Count -eq 2 -and $d.x -eq $null)
}

task Dictionary.RawBsonDocument.RawBsonArray {

	# RawBsonDocument
	Connect-Mdbc -NewCollection
	@{array = 1, 2; document = @{name = 42}} | Add-MdbcData
	$raw = Get-MdbcData -As ([MongoDB.Bson.RawBsonDocument])
	Test-Type $raw MongoDB.Bson.RawBsonDocument

	#_131015_123005 New-MdbcData makes new even on read only RawBsonDocument
	$md = New-MdbcData $raw
	assert (!$md.IsFixedSize)
	assert (!$md.IsReadOnly)
	Test-Type $md.Document() MongoDB.Bson.BsonDocument

	#
	$md = [Mdbc.Dictionary]$raw
	assert ($md.IsFixedSize)
	assert ($md.IsReadOnly)
	Test-Type $md.Document() MongoDB.Bson.RawBsonDocument

	&{
		$a = $md.array
		assert ($a.IsFixedSize)
		assert ($a.IsReadOnly)
		assert (!$a.Array().IsReadOnly) #todo driver bug
		Test-Type $a.Array() MongoDB.Bson.RawBsonArray
		assert (![object]::ReferenceEquals($a.Array(), $md.array.Array()))
	}

	&{
		$d = $md.document
		assert ($d.IsFixedSize)
		assert ($d.IsReadOnly)
		Test-Type $d.Document() MongoDB.Bson.RawBsonDocument
		assert (![object]::ReferenceEquals($d.Document(), $md.document.Document()))
	}

	$md.Dispose(); $md.Dispose() #! twice is fine
}

task Dictionary.Operators {
	$date = Get-Date
	$guid = [guid]'94a30dd6-6451-49fb-9c48-18e3f1509877'

	$d = New-MdbcData -NewId @{
		null = $null
		int = 42
		date = $date
		guid = $guid
	}

	Connect-Mdbc -NewCollection
	$d | Add-MdbcData

	### EQ

	query 1 @{missing = $null}
	query 1 (New-MdbcQuery missing -EQ $null)
	#??assert (1 -eq $d.EQ('missing', $null))

	query 0 @{missing = 12345}
	query 0 (New-MdbcQuery missing -EQ 12345)
	#??assert (0 -eq $d.EQ('missing', 12345))

	query 1 @{null = $null}
	query 1 (New-MdbcQuery null -EQ $null)
	#??assert (1 -eq $d.EQ('null', $null))

	#??assert $d.EQ('int', 42)
	#??assert $d.EQ('date', $date)
	#??assert $d.EQ('guid', $guid)
	#??assert $d.EQ('_id', $d._id)

	### NE
	query 0 @{missing = @{'$ne' = $null}}
	query 0 (New-MdbcQuery missing -NE $null)
	#??assert (0 -eq $d.NE('missing', $null))

	query 1 @{missing = @{'$ne' = 12345}}
	query 1 (New-MdbcQuery missing -NE 12345)
	#??assert (1 -eq $d.NE('missing', 12345))

	query 0 @{null = @{'$ne' = $null}}
	query 0 (New-MdbcQuery null -NE $null)
	#??assert (0 -eq $d.NE('null', $null))

	#??assert (!$d.NE('int', 42))
	#??assert (!$d.NE('date', $date))
	#??assert (!$d.NE('guid', $guid))
	#??assert (!$d.NE('_id', $d._id))

	#todo
}
