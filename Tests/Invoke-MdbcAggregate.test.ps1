
. ./Zoo.ps1

task Invalid {
	Connect-Mdbc
	Test-Error { Invoke-MdbcAggregate $null } -Text ([Mdbc.Res]::ParameterPipeline)
	Test-Error { Invoke-MdbcAggregate -Pipeline bad } '*: "Invalid JSON."'
}

# Data: current process names and memory working sets
task InitHelpExample {
	Connect-Mdbc . test test -NewCollection
	$script:Collection = $Collection
	Get-Process | Add-MdbcData -Property Name, WorkingSet
}

#_131016_142302 see help example
task HelpExample1 InitHelpExample, {
	# Group by names, count, sum memory, get top 3
	$r = Invoke-MdbcAggregate -As PS @(
		# group ny name, count and sum memory
		@{ '$group' = @{
			_id = '$Name'
			Count = @{ '$sum' = 1 }
			Memory = @{ '$sum' = '$WorkingSet' }
		}}
		# rename _id -> Name (add Name and omit _id)
		@{ '$project' = [ordered]@{
			Name = '$_id'
			Count = '$Count'
			Memory = '$Memory'
			_id = $false # omit
		}}
		# sort by memory descending
		@{ '$sort' = @{Memory = -1} }
		# and finally get top 5
		@{ '$limit' = 5 }
	)
	$r | Format-Table | Out-String
	equals $r.Count 5
}

task HelpExample2 InitHelpExample, {
	$r = Invoke-MdbcAggregate -As PS @(
		'{ $group: { _id : "$Name", Count : { $sum : 1 }, Memory : { $sum : "$WorkingSet" } } }'
		'{ $sort : { Memory : -1 } }'
		'{ $limit : 5 }'
	)
	$r | Format-Table | Out-String
	equals $r.Count 5
}

task HelpExample3 InitHelpExample, {
	$r = Invoke-MdbcAggregate -As PS @'
[
	{ $group: { _id : "$Name", Count : { $sum : 1 }, Memory : { $sum : "$WorkingSet" } } },
	{ $sort : { Memory : -1 } },
	{ $limit : 5 }
]
'@
	$r | Format-Table | Out-String
	equals $r.Count 5
}

task GroupNoId {
	Connect-Mdbc -NewCollection
	1..9 | .{process{ @{n = $_} }} | Add-MdbcData
	$expected = '{ "min" : 1, "max" : 9, "avg" : 5.0 }'

	$r = Invoke-MdbcAggregate -Group '{min: {$min: "$n"}, max: {$max: "$n"}, avg: {$avg: "$n"}}'
	equals "$r" $expected

	$r = Invoke-MdbcAggregate -Group ([ordered]@{
		min = @{'$min' = '$n'}
		max = @{'$max' = '$n'}
		avg = @{'$avg' = '$n'}
	})
	equals "$r" $expected
}

task GroupWithId {
	Connect-Mdbc -NewCollection
	1..9 | .{process{ @{n = $_; c = $_ % 2} }} | Add-MdbcData
	$expected = '{ "_id" : 0, "count" : 4 } { "_id" : 1, "count" : 5 }'

	$r = Invoke-MdbcAggregate -Group '{_id: "$c", count: {$sum: 1}}' | Sort-Object {$_._id}
	equals "$r" $expected

	$r = Invoke-MdbcAggregate -Group ([ordered]@{
		_id = '$c'
		count = @{'$sum' = 1}
	}) | Sort-Object {$_._id}
	equals "$r" $expected
}

task FixGroupAltersInput {
	Connect-Mdbc -NewCollection
	$d = New-MdbcData
	$d.count = @{'$sum' = 1}
	$r = Invoke-MdbcAggregate -Group $d
	equals $r $null
	equals $d.Count 1 #! was 2 due to added _id
}
