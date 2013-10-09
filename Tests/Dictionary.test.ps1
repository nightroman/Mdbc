
Import-Module Mdbc

function query($expected, $query) {
	$count = Get-MdbcData -Count $query
	if ($expected -ne $count) {
		Write-Error -ErrorAction 1 "Expected count: $expected, actual: $count."
	}
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

	Connect-Mdbc . test test -NewCollection
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
