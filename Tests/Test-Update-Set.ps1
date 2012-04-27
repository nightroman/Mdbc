
Import-Module Mdbc
$collection = Connect-Mdbc . test test -NewCollection

# add data
$$ = New-MdbcData -DocumentId 1
$$.p1 = 1
$$.p2 = 1
$$.p3 = 1
$$ | Add-MdbcData $collection

# update 3 fields and get back
$$ | Update-MdbcData $collection @(
	New-MdbcUpdate p1 -Set 2
	New-MdbcUpdate p2 -Set 2
	New-MdbcUpdate p3 -Set 2
)
$$ = Get-MdbcData $collection

# test: 2, 2, 2
if ($$.p1 -ne 2) { throw }
if ($$.p2 -ne 2) { throw }
if ($$.p3 -ne 2) { throw }

# update 2 fields and get back
$something = $false
$$ | Update-MdbcData $collection @(
	New-MdbcUpdate p1 -Set 3
	if ($something) {
		New-MdbcUpdate p2 -Set 3
	}
	New-MdbcUpdate p3 -Set 3
)
$$ = Get-MdbcData $collection

# update 1 field and get back
$$ | Update-MdbcData $collection (New-MdbcUpdate p2 -Set 3)
$$ = Get-MdbcData $collection

# test: 3, 3, 3
if ($$.p1 -ne 3) { throw }
if ($$.p2 -ne 3) { throw }
if ($$.p3 -ne 3) { throw }
