<#
.Synopsis
	Tests Watch-MdbcChange

.Description
	Change Events -- https://docs.mongodb.com/manual/reference/change-events/
	db.collection.watch() -- https://docs.mongodb.com/manual/reference/method/db.collection.watch/
#>

. ./Zoo.ps1
Set-StrictMode -Version 2

task Help {
	# get a new collection and watch its changes
	Connect-Mdbc -NewCollection
	$watch = Watch-MdbcChange -Collection $Collection
	try {
		# the first MoveNext "gets it ready"
		$null = $watch.MoveNext()

		# add and update some data
		@{_id = 'count'; value = 0} | Add-MdbcData
		Update-MdbcData @{_id = 'count'} @{'$inc' = @{value = 1}}

		# get two documents about insert and update
		if ($watch.MoveNext()) {
			foreach($change in $watch.Current) {
				"$change"
			}
		}
	}
	finally {
		# dispose after use
		$watch.Dispose()
	}
}

task Basic {
	Connect-Mdbc -NewCollection
	$watch = Watch-MdbcChange -Collection $Collection
	try {
		# before MoveNext, one item, $null
		$r = @($watch.Current)
		equals $r.Count 1
		equals $r[0] $null

		# first MoveNext "gets it ready"
		equals $watch.MoveNext() $true
		equals @($watch.Current).Count 0

		# add and update data
		@{_id = 'count'; value = 0} | Add-MdbcData
		Update-MdbcData @{_id = 'count'} @{'$inc' = @{value = 1}}
		equals $watch.MoveNext() $true
		equals @($watch.Current).Count 2

		# test [0], "insert"
		$r = @($watch.Current)[0]
		equals $r.operationType insert
		equals "$($r.fullDocument)" '{ "_id" : "count", "value" : 0 }'

		# test [1], "update"
		$r = @($watch.Current)[1]
		equals $r.operationType update
		equals "$($r.updateDescription)" '{ "updatedFields" : { "value" : 1 }, "removedFields" : [] }'

		# set data, test "replace"
		@{_id = 'count'; value = 2} | Set-MdbcData
		equals $watch.MoveNext() $true
		equals @($watch.Current).Count 1
		$r = @($watch.Current)[0]
		equals $r.operationType replace
		equals $r.fullDocument.value 2

		# remove data, test "delete"
		Remove-MdbcData @{_id = 'count'}
		equals $watch.MoveNext() $true
		equals @($watch.Current).Count 1
		$r = @($watch.Current)[0]
		equals $r.operationType delete
	}
	finally {
		$watch.Dispose()
	}
}

#! $project cannot remove _id, ~ "token required for resume"
task Pipeline {
	Connect-Mdbc -NewCollection
	$watch = Watch-MdbcChange -Collection $Collection @(
		@{'$match' = @{operationType = 'insert'}}
		@{'$project' = @{fullDocument = 1}}
	)
	try {
		$null = $watch.MoveNext()

		# add and update some data
		@{_id = 'count'; value = 0} | Add-MdbcData
		Update-MdbcData @{_id = 'count'} @{'$inc' = @{value = 1}}

		assert $watch.MoveNext()
		$r = @($watch.Current)
		equals $r.Count 1
		$r[0].Remove('_id')
		equals "$r" '{ "fullDocument" : { "_id" : "count", "value" : 0 } }'
	}
	finally {
		# dispose after use
		$watch.Dispose()
	}
}

task Database {
	Connect-Mdbc . test
	$c1 = Get-MdbcCollection test1 -NewCollection
	$c2 = Get-MdbcCollection test2 -NewCollection
	$watch = Watch-MdbcChange -Database $Database
	try {
		$null = $watch.MoveNext()

		@{_id = 1} | Add-MdbcData -Collection $c1
		@{_id = 2} | Add-MdbcData -Collection $c2

		Start-Sleep 1
		assert ($watch.MoveNext())
		$r = @($watch.Current)
		equals $r.Count 2
		equals $r[0].operationType insert
		equals $r[1].operationType insert
		equals $r[0].ns.ToString() '{ "db" : "test", "coll" : "test1" }'
		equals $r[1].ns.ToString() '{ "db" : "test", "coll" : "test2" }'

		Start-Sleep 1
		Remove-MdbcCollection test1
		Remove-MdbcCollection test2
		assert ($watch.MoveNext())
		$r = @($watch.Current)
		equals $r.Count 2
		equals $r[0].operationType drop
		equals $r[1].operationType drop
		equals $r[0].ns.ToString() '{ "db" : "test", "coll" : "test1" }'
		equals $r[1].ns.ToString() '{ "db" : "test", "coll" : "test2" }'
	}
	finally {
		$watch.Dispose()
	}
}

task Client {
	Connect-Mdbc .
	$d1 = Get-MdbcDatabase temp1
	$d2 = Get-MdbcDatabase temp2
	$c1 = Get-MdbcCollection test1 -NewCollection -Database $d1
	$c2 = Get-MdbcCollection test2 -NewCollection -Database $d2
	$watch = Watch-MdbcChange -Client $Client
	try {
		$null = $watch.MoveNext()

		@{_id = 1} | Add-MdbcData -Collection $c1
		@{_id = 2} | Add-MdbcData -Collection $c2

		Start-Sleep 1
		assert ($watch.MoveNext())
		$r = @($watch.Current)
		equals $r.Count 2
		equals $r[0].operationType insert
		equals $r[1].operationType insert
		equals $r[0].ns.ToString() '{ "db" : "temp1", "coll" : "test1" }'
		equals $r[1].ns.ToString() '{ "db" : "temp2", "coll" : "test2" }'

		Remove-MdbcDatabase temp1
		Remove-MdbcDatabase temp2

		Start-Sleep 1
		assert ($watch.MoveNext())
		$r = @($watch.Current)
		equals $r.Count 4
		equals $r[0].operationType drop
		equals $r[0].ns.ToString() '{ "db" : "temp1", "coll" : "test1" }'
		equals $r[1].operationType dropDatabase
		equals $r[1].ns.ToString() '{ "db" : "temp1" }'
		equals $r[2].operationType drop
		equals $r[2].ns.ToString() '{ "db" : "temp2", "coll" : "test2" }'
		equals $r[3].operationType dropDatabase
		equals $r[3].ns.ToString() '{ "db" : "temp2" }'
	}
	finally {
		$watch.Dispose()
	}
}
