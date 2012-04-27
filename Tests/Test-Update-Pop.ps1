
Import-Module Mdbc
$collection = Connect-Mdbc . test test -NewCollection

# make a document
$$ = New-MdbcData -DocumentId 1
$$.Array = 1, 2, 3
$$ | Add-MdbcData $collection

# update (PopLast) and get back
$$ | Update-MdbcData $collection (New-MdbcUpdate Array -PopLast)
$$ = Get-MdbcData $collection

# test: 3 is removed; 1, 2 are there
if ($$.Array.Count -ne 2) { throw }
if ($$.Array[0] -ne 1) { throw }
if ($$.Array[1] -ne 2) { throw }

# update (PopFirst) and get back
$$ | Update-MdbcData $collection (New-MdbcUpdate Array -PopFirst)
$$ = Get-MdbcData $collection

# test: 1 is removed; 2 is there
if ($$.Array.Count -ne 1) { throw }
if ($$.Array[0] -ne 2) { throw }
