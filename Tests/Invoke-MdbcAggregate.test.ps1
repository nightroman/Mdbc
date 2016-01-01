
. .\Zoo.ps1
Import-Module Mdbc

task Invalid {
	Test-Error { Invoke-MdbcAggregate $null } "*'Pipeline' because it is null.*"
	Test-Error { Invoke-MdbcAggregate -Pipeline bad } '*Cannot convert System.String to a document.*'
}

#_131016_142302 see help example
task HelpExample {
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
	equals $r.Count 3
}
