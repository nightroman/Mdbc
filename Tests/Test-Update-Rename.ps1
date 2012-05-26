
Import-Module Mdbc
Connect-Mdbc . test test -NewCollection

# add a document with Name1
$$ = New-MdbcData -Id 1
$$.Name1 = 42
$$ | Add-MdbcData

# update (rename Name1 to Name2) and get back
$$ | Update-MdbcData (New-MdbcUpdate Name1 -Rename Name2)
$$ = Get-MdbcData

# test: Name2 gets 42, i.e. renamed
if ($$.Name2 -ne 42) { throw }
