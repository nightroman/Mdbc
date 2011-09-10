
Import-Module Mdbc
$collection = Connect-Mdbc . test test -NewCollection

# make a document with arrays
$$ = New-MdbcData
$$._id = 1234
$$.Array1 = @(
	, @(1, 2)
	, @(3, 4)
)
$$.Array2 = 1..4

# test document data
if ("$$" -ne '{ "_id" : 1234, "Array1" : [[1, 2], [3, 4]], "Array2" : [1, 2, 3, 4] }') { throw "$$" }
if ($$.Array1.Count -ne 2) { throw }
if ($$.Array2.Count -ne 4) { throw }

# add the document
$$ | Add-MdbcData $collection

# Pull expression
#_110727_194907 "Array1" : [1, 2] -- argument is a single (!) item which is array (not two arguments!)
$updates = (update Array1 -Pull @(1, 2)), (update Array2 -Pull @(1, 2))

# update and get back
$$ | Update-MdbcData $collection $updates
$$ = Get-MdbcData $collection

# test: removed from Array1 and not removed from Array2
if ("$$" -ne '{ "Array1" : [[3, 4]], "Array2" : [1, 2, 3, 4], "_id" : 1234 }') { throw "$$" }
if ($$.Array1.Count -ne 1) { throw }
if ($$.Array2.Count -ne 4) { throw }
