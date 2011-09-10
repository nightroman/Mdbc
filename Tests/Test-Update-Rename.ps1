
Import-Module Mdbc
$collection = Connect-Mdbc . test test -NewCollection

# add a document with Name1
$$ = New-MdbcData -DocumentId 1
$$.Name1 = 42
$$ | Add-MdbcData $collection

# update (rename Name1 to Name2) and get back
$$ | Update-MdbcData $collection (update Name1 -Rename Name2)
$$ = Get-MdbcData $collection

# test: Name2 gets 42, i.e. renamed
if ($$.Name2 -ne 42) { throw }
