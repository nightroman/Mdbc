
#_131016_142302 see help example
task Invoke-MdbcAggregate.HelpExample {
	$r = .{
		# Data: current process names and memory working sets
		Connect-Mdbc . test test -NewCollection
		Get-Process | Add-MdbcData -Property Name, WorkingSet

		# Group by names, count, sum memory, get top 3
		Invoke-MdbcAggregate @(
			@{ '$group' = @{
				_id = '$Name'
				Count = @{ '$sum' = 1 }
				Memory = @{ '$sum' = '$WorkingSet' }
			}}
			@{ '$sort' = @{Memory = -1} }
			@{ '$limit' = 3 }
		)
	}
	assert ($r.Count -eq 3)
}
