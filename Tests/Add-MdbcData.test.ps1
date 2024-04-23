
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

task BadId {
	Connect-Mdbc -NewCollection
	$d = @{_id = 1,2}
	Test-Error { $d | Add-MdbcData } "*The '_id' value cannot be of type array*"
}

#_131119_113717
task Duplicate {
	Connect-Mdbc -NewCollection

	# true is not 1
	@{_id=1}, @{_id=$true} | Add-MdbcData

	# same 2 and 2L
	Test-Error { @{_id=2}, @{_id=2L} | Add-MdbcData } '*duplicate*'

	# same 3 and 3.0
	Test-Error { @{_id=3}, @{_id=3.0} | Add-MdbcData } '*duplicate*'

	# same documents
	Test-Error { @{_id=@{y=4}}, @{_id=@{y=4.0}} | Add-MdbcData } '*duplicate*'
}

task ErrorTargetObject {
	Connect-Mdbc -NewCollection

	# add one (OK) and two (KO, same _id)
	@{_id=1; x=1}, @{_id=1; x=2} | Add-MdbcData -ErrorAction 0 -ErrorVariable e
	assert ($e -like '*E11000 duplicate key error*dup key: { _id: 1 }*')
	equals $e.TargetObject.x 2

	# one is added two is not
	$r = Get-MdbcData
	Test-Table @{_id=1; x=1} $r
}

task BadSameId {
	Connect-Mdbc -NewCollection

	# New document
	$document = New-MdbcData -Id 131107103027
	$document.Name = 'Hello'

	# Add the document
	$document | Add-MdbcData

	# To add with the same _id and another Name
	$document.Name = 'World'

	# This throws an exception
	Test-Error {$document | Add-MdbcData -ErrorAction Stop} '*duplicate key*131107103027*'

	# This writes an error to the specified variable
	$document | Add-MdbcData -ErrorAction 0 -ErrorVariable e
	"$e"
	assert ($e -like '*duplicate key*131107103027*')

	# Test: Name is still 'Hello', 'World' is not added or saved
	$data = @(Get-MdbcData)
	equals $data.Count 1
	equals $data[0].Name 'Hello'
}

### Array and Many

$ManyCount = 20

function Get-DocumentMany {
	foreach($_ in 1 .. $ManyCount) {@{_id=$_}}
}

function Assert-DocumentMany {
	$r = Get-MdbcData
	equals $r.Count $ManyCount
	equals ($r[0].ToString()) '{ "_id" : 1 }'
	equals ($r[-1].ToString()) "{ `"_id`" : $ManyCount }"
}

# https://github.com/nightroman/Mdbc/issues/51
task AddArray {
	Connect-Mdbc -NewCollection
	Add-MdbcData (Get-DocumentMany)
	Assert-DocumentMany
}

# https://github.com/nightroman/Mdbc/issues/77
task AddManyArray {
	Connect-Mdbc -NewCollection
	Add-MdbcData (Get-DocumentMany) -Many
	Assert-DocumentMany
}

# https://github.com/nightroman/Mdbc/issues/77
task AddManyPipeline {
	Connect-Mdbc -NewCollection
	Get-DocumentMany | Add-MdbcData -Many
	Assert-DocumentMany
}
