
. ./Zoo.ps1

task Invalid {
	Connect-Mdbc
	Test-Error { Invoke-MdbcAggregate $null } $ErrorPipeline
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
