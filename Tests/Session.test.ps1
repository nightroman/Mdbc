
Import-Module Mdbc

task Basic {
	Connect-Mdbc -NewCollection
	$ses = $Client.StartSession()
	try {
		@{_id = 71} | Add-MdbcData -Session $ses
		$r = Get-MdbcData -Session $ses
		equals $r._id 71

		Set-MdbcData @{} @{p1 = 71} -Session $ses
		$r = Get-MdbcData -Session $ses
		equals $r.p1 71

		Update-MdbcData @{} @{'$set' = @{p1 = 72}} -Session $ses
		$r = Get-MdbcData -Session $ses
		equals $r.p1 72

		Remove-MdbcData @{} -Session $ses
		$r = Get-MdbcData -Count -Session $ses
		equals $r 0L
	}
	finally {
		$ses.Dispose()
	}
}
