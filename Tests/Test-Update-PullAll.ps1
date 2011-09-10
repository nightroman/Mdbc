
Import-Module Mdbc
$collection = Connect-Mdbc . test test -NewCollection

# make and add a document
$$ = New-MdbcData -DocumentId 1
$$.Array = 1, 2, 3, 4, 1, 2, 3, 4
$$ | Add-MdbcData $collection

# update (PullAll) and get back
$$ | Update-MdbcData $collection (update Array -PullAll 1, 2)
$$ = Get-MdbcData $collection

# test: 1, 2 are removed; 3, 4 are there
if ($$.Array.Count -ne 4) { throw }
if ($$.Array[0] -ne 3) { throw }
if ($$.Array[1] -ne 4) { throw }
if ($$.Array[2] -ne 3) { throw }
if ($$.Array[3] -ne 4) { throw }

# update (Pull) and get back
$$ | Update-MdbcData $collection (update Array -Pull 3)
$$ = Get-MdbcData $collection

# test: 3 is removed; 4 is there
if ($$.Array.Count -ne 2) { throw }
if ($$.Array[0] -ne 4) { throw }
if ($$.Array[1] -ne 4) { throw }
