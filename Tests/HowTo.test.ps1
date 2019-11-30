<#
.Synopsis
	Covers some how-to cases.
#>

. ./Zoo.ps1

# Synopsis: How to create a unique index and get indexes.
# Use Invoke-MdbcCommand when other cmdlets cannot help.
# https://docs.mongodb.com/manual/reference/command/createIndexes/#dbcmd.createIndexes
task CreateAndGetIndex {
	Connect-Mdbc -NewCollection

	# How to create an index
	$r = Invoke-MdbcCommand ([ordered]@{
		createIndexes = 'test'
		indexes = @(
			@{
				key = @{
					'my-index' = 1
				}
				name = "my-index"
				unique = "true"
			}
		)
	})
	$r.Print()

	equals $r.numIndexesBefore 1
	equals $r.numIndexesAfter 2

	# How to get indexes
	$r = Invoke-MdbcCommand '{ "listIndexes": "test" }'
	$r.Print()

	$ii = $r.cursor.firstBatch
	equals $ii.Count 2
	equals $ii[0].name _id_
	equals $ii[0]['unique'] $null
	equals $ii[1].name my-index
	equals $ii[1].unique $true
}

# Synopsis: How to use [regex] in $in expressions.
# In JSON regex may be defined using syntax /.../.
# In dictionary expressions use the [regex] type.
task OperatorInWithRegex {
	Connect-Mdbc -NewCollection

	# add documents with some names
	@{name = 'Apple'}, @{name = 'Banana'}, @{name = 'Lemon'}, @{name = 'Orange'} | Add-MdbcData

	# get names containing 'm' or 'p' using $in and regex
	$r = Get-MdbcData -Distinct name -Filter @{
		name = @{
			'$in' = @(
				[regex]'m'
				[regex]'p'
			)
		}
	}

	# Apple and Lemon
	equals $r.Count 2
	equals $r[0] Apple
	equals $r[1] Lemon
}

# Synopsis: How to use SHA1 hashes as _id.
task SHA1AsId {
	Connect-Mdbc -NewCollection

	# sample data
	$data = 'Hello', 'World'

	# hash data and save with _id=hash
	$hash = [System.Security.Cryptography.SHA1]::Create()
	foreach($_ in $data) {
		# hash bytes
		$bytes = $hash.ComputeHash(([char[]]$_))

		# new document with binary _id from bytes
		$d = New-MdbcData @{_id = $bytes; data = $_}

		# how _id looks
		"$($d._id)"

		# save
		Add-MdbcData $d
	}

	# query `Hello` by its SHA1 using BsonBinaryData
	$id = [MongoDB.Bson.BsonBinaryData]([MongoDB.Bson.BsonUtils]::ParseHexString('f7ff9e8b7bb2e09b70935a5d785e0cc5d9d0abf0'))
	$r = Get-MdbcData @{_id = $id}
	equals $r.data Hello

	# query 'World' a bit simpler
	$qId = New-MdbcData -Id ([MongoDB.Bson.BsonUtils]::ParseHexString('70c07ec18ef89c5309bbb0937f3a6342411e1fdd'))
	$r = Get-MdbcData $qId
	equals $r.data World

	# query -As PS should give the same _id
	$r = Get-MdbcData $qId -As PS
	equals ($r.GetType().Name) PSCustomObject
	equals $r._id $qId._id
	equals $r.data World
}

# Synopsis: How to update data with stamps and track changes.
# The simplified scenario of Update-MongoFiles.ps1
task DataChangeWithLogging {
	function Update-Data($data, $time) {
		# set time expression, used by two commands
		$set_time = @{'$set' = @{time = $time}}

		# query main data and set the time
		$r = Update-MdbcData $data $set_time -Result

		# if modified then data are the same and the time is set -> done
		if ($r.ModifiedCount) {
			'same'
			return
		}

		# new data are different -> update or add
		$r = Update-MdbcData @{_id = $data._id} (@{'$set' = $data}, $set_time) -Add -Result
		if ($r.ModifiedCount) {
			'changed'
		}
		else {
			'added'
		}
	}

	# now test the function
	Connect-Mdbc -NewCollection

	# data1, time1
	$data1 = @{_id = 1; p1 = 1}
	$r = Update-Data $data1 1
	equals $r added
	$r = Get-MdbcData
	equals $r.p1 1
	equals $r.time 1

	# data1, time2
	$data1 = @{_id = 1; p1 = 1}
	$r = Update-Data $data1 2
	equals $r same
	$r = Get-MdbcData
	equals $r.p1 1
	equals $r.time 2

	# data2, time3
	$data1 = @{_id = 1; p1 = 2}
	$r = Update-Data $data1 3
	equals $r changed
	$r = Get-MdbcData
	equals $r.p1 2
	equals $r.time 3
}

# Synopsis: Remove some documents from arrays, then remove documents with empty arrays.
# (like removing old log entries from `files_log` produced by Update-MongoFiles.ps1)
task RemoveDocumentsFromArraysThenEmpty {
	Connect-Mdbc -NewCollection

	# 3 documents with arrays of documents
	$(
		@{_id = 1; arr = @{p1 = 0}, @{p1 = 1}}
		@{_id = 2; arr = @{p1 = 10}, @{p1 = 11}}
		@{_id = 3; arr = @{p1 = 110}, @{p1 = 111}}
	) | Add-MdbcData

	# remove documents with .p1 <= 10 from .arr
	# (removed: 2, 1, 0 -> modified 2 documents)

	$r = Update-MdbcData -Many -Result @{} @{'$pull' = @{arr = @{p1 = @{'$lte' = 10}}}}
	equals $r.ModifiedCount 2L

	# remove documents with empty .arr
	# (removed 1 document)

	$r = Remove-MdbcData -Many -Result @{arr = @{'$size' = 0}}
	equals $r.DeletedCount 1L
	equals "$(Get-MdbcData)" '{ "_id" : 2, "arr" : [{ "p1" : 11 }] } { "_id" : 3, "arr" : [{ "p1" : 110 }, { "p1" : 111 }] }'
}
