
. .\Zoo.ps1
Import-Module Mdbc

function Enter-BuildTask {
	Connect-Mdbc -NewCollection
}

task Add-MdbcData.WithSameIdAndWithUpdate {
	# New document
	$document = New-MdbcData
	$document._id = 12345
	$document.Name = 'Hello'

	# Add the document
	$document | Add-MdbcData

	# To add with the same _id and another Name
	$document.Name = 'World'

	# This throws an exception
	Test-Error {$document | Add-MdbcData -ErrorAction Stop} 'WriteConcern detected an error*'

	# This writes an error to the specified variable
	$document | Add-MdbcData -ErrorAction 0 -ErrorVariable ev
	assert ("$ev" -like 'WriteConcern detected an error*')

	# This fails silently and returns nothing
	$result = $document | Add-MdbcData -Result -WriteConcern ([MongoDB.Driver.WriteConcern]::Unacknowledged)
	assert ($null -eq $result)

	# Test: Name is still 'Hello', 'World' is not added or saved
	$data = @(Get-MdbcData)
	assert ($data.Count -eq 1)
	assert ($data[0].Name -eq 'Hello')

	# Add again, this time with the Update switch
	$document.Name = 'World'
	$document | Add-MdbcData -Update

	# Test: Name is 'World', the document is updated
	$data = @(Get-MdbcData)
	assert ($data.Count -eq 1)
	assert ($data[0].Name -eq 'World')
}

task Add-MdbcData.ErrorAddSameId {
	# same _id
	$d1 = @{_id = 1; Name = 'name1'};
	$d2 = @{_id = 1; Name = 'name2'}

	# add and get result
	$d1, $d2 | Add-MdbcData -ErrorAction 0 -ErrorVariable e
	$r = Get-MdbcData

	assert ($e -like '*E11000 duplicate key error index: test.test.$_id_  dup key: { : 1 }*')
	assert ($PSVersionTable.PSVersion.Major -le 2 -or $e.TargetObject -eq $d2)
	Test-Dictionary $r $d1
}
