
Import-Module Mdbc
Connect-Mdbc . test test -NewCollection

# make a document
$$ = New-MdbcData -Id 1
$$.Array = 1, 2, 3
$$ | Add-MdbcData

# update (PopLast) and get back
$$ | Update-MdbcData (New-MdbcUpdate Array -PopLast)
$$ = Get-MdbcData

# test: 3 is removed; 1, 2 are there
if ($$.Array.Count -ne 2) { throw }
if ($$.Array[0] -ne 1) { throw }
if ($$.Array[1] -ne 2) { throw }

# update (PopFirst) and get back
$$ | Update-MdbcData (New-MdbcUpdate Array -PopFirst)
$$ = Get-MdbcData

# test: 1 is removed; 2 is there
if ($$.Array.Count -ne 1) { throw }
if ($$.Array[0] -ne 2) { throw }
