<#
.Synopsis
	Covers some how-to cases.
#>

. .\Zoo.ps1
Import-Module Mdbc

# Synopsis: Create unique index. #15
# https://docs.mongodb.com/manual/reference/command/createIndexes/#dbcmd.createIndexes
task CreateUniqueIndex {
	Connect-Mdbc -NewCollection

	### How to create an index
	$r = Invoke-MdbcCommand -Command ([ordered]@{
		createIndexes = 'test'
		indexes = @(
			@{
				key = @{
					'tax-id' = 1
				}
				name = "tax-id"
				unique = "true"
			}
		)
	})
	$r.Print()

	equals $r.numIndexesBefore 1
	equals $r.numIndexesAfter 2

	### How to get indexes
	$r = Invoke-MdbcCommand '{ "listIndexes": "test" }'
	$r.Print()

	$ii = $r.cursor.firstBatch
	equals $ii.Count 2
	equals $ii[0].name _id_
	equals $ii[0]['unique'] $null
	equals $ii[1].name tax-id
	equals $ii[1].unique $true
}

# Test the simplified scenario of Update-MongoFiles.ps1
task DataChangeWithLogging {
	# V1 is slightly simpler but it changes input ($data.time = $time).
	# And if it makes a copy of $data then it is not simpler.
	function Test-DataChangeWithLoggingV1($data, $time) {
		# query main data and set the time
		$r = Update-MdbcData $data @{'$set' = @{time = $time}} -Result

		# if modified then data are the same and the time is set -> done
		if ($r.ModifiedCount) {
			'same'
			return
		}

		# new data are different -> set or add
		$data.time = $time
		$r = Set-MdbcData @{_id = $data._id} $data -Add -Result
		if ($r.ModifiedCount) {
			'changed'
		}
		else {
			'added'
		}
	}

	# V2 does not change input, it uses aggregate update expression
	function Test-DataChangeWithLoggingV2($data, $time) {
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

	# now test different version
	Invoke-Test {
		Connect-Mdbc -NewCollection

		# data1, time1
		$data1 = @{_id = 1; p1 = 1}
		$r = Test-DataChangeWithLogging $data1 1
		equals $r added
		$r = Get-MdbcData
		equals $r.p1 1
		equals $r.time 1

		# data1, time2
		$data1 = @{_id = 1; p1 = 1}
		$r = Test-DataChangeWithLogging $data1 2
		equals $r same
		$r = Get-MdbcData
		equals $r.p1 1
		equals $r.time 2

		# data2, time3
		$data1 = @{_id = 1; p1 = 2}
		$r = Test-DataChangeWithLogging $data1 3
		equals $r changed
		$r = Get-MdbcData
		equals $r.p1 2
		equals $r.time 3
	}{
		Set-Alias Test-DataChangeWithLogging Test-DataChangeWithLoggingV1
	}{
		Set-Alias Test-DataChangeWithLogging Test-DataChangeWithLoggingV2
	}
}

# How to use SHA1 hashes as _id
task BinaryId {
	Connect-Mdbc -NewCollection

	# sample data
	$data = 'Hello', 'World'

	# hash data and save with _id=hash
	$hash = [System.Security.Cryptography.SHA1]::Create()
	foreach($_ in $data) {
		# hash bytes
		$bytes = $hash.ComputeHash(([char[]]$_))

		# new document with binary _id from bytes
		$d = [Mdbc.Dictionary]$bytes
		$d.data = $_

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
	$qid = [Mdbc.Dictionary]([MongoDB.Bson.BsonUtils]::ParseHexString('70c07ec18ef89c5309bbb0937f3a6342411e1fdd'))
	$r = Get-MdbcData $qid
	equals $r.data World

	# query -As PS should give the same _id
	$r = Get-MdbcData $qid -As PS
	equals ($r.GetType().Name) PSCustomObject
	equals $r._id $qid._id
	equals $r.data World
}
