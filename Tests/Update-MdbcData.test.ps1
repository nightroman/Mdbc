
. .\Zoo.ps1
Import-Module Mdbc

function Enter-BuildTask {
	Connect-Mdbc -NewCollection
}

task Update-MdbcData.-AddToSet {
	# add data
	@{_id = 1310110108; value = 1; array = @(1310110108)} | Add-MdbcData

	# try to add to non array #! try $null (fixed)
	Test-Error { Update-MdbcData (New-MdbcUpdate -AddToSet @{value = $null}) 1310110108 } '*Cannot apply $addToSet modifier to non-array*'

	# add to array
	Update-MdbcData (New-MdbcUpdate -AddToSet @{array = $null}) 1310110108
	$d = Get-MdbcData

	assert ($d.array.Count -eq 2)
	assert ($d.array[0] -eq 1310110108)
	assert ($d.array[1] -eq $null)
}

task Update-MdbcData.-Set {
	# add data
	$$ = New-MdbcData -Id 1
	$$.p1 = 1
	$$.p2 = 1
	$$.p3 = 1
	$$ | Add-MdbcData

	# update 3 fields and get back
	$$ | Update-MdbcData @(
		New-MdbcUpdate @{
			p1 = 2
			p2 = 2
			p3 = 2
		}
	)
	$$ = Get-MdbcData

	# test: 2, 2, 2
	assert ($$.p1 -eq 2)
	assert ($$.p2 -eq 2)
	assert ($$.p3 -eq 2)

	# update 2 fields and get back
	$something = $false
	$$ | Update-MdbcData @(
		New-MdbcUpdate @{p1 = 3}
		if ($something) {
			New-MdbcUpdate @{p2 = 3}
		}
		New-MdbcUpdate @{p3 = 3}
	)
	$$ = Get-MdbcData

	# update 1 field and get back
	$$ | Update-MdbcData (New-MdbcUpdate @{p2 = 3})
	$$ = Get-MdbcData

	# test: 3, 3, 3
	assert ($$.p1 -eq 3)
	assert ($$.p2 -eq 3)
	assert ($$.p3 -eq 3)
}

task Update-MdbcData.-PopLast.-PopFirst {
	# make a document
	$$ = New-MdbcData -Id 1
	$$.Array = 1, 2, 3
	$$ | Add-MdbcData

	# update (PopLast) and get back
	$$ | Update-MdbcData (New-MdbcUpdate -PopLast Array)
	$$ = Get-MdbcData

	# test: 3 is removed; 1, 2 are there
	assert ($$.Array.Count -eq 2)
	assert ($$.Array[0] -eq 1)
	assert ($$.Array[1] -eq 2)

	# update (PopFirst) and get back
	$$ | Update-MdbcData (New-MdbcUpdate -PopFirst Array)
	$$ = Get-MdbcData

	# test: 1 is removed; 2 is there
	assert ($$.Array.Count -eq 1)
	assert ($$.Array[0] -eq 2)
}

task Update-MdbcData.-Pull {
	# make a document with arrays
	$$ = New-MdbcData
	$$._id = 1234
	$$.Array1 = @(
		, @(1, 2)
		, @(3, 4)
	)
	$$.Array2 = 1..4

	# test document data
	assert ("$$" -eq '{ "_id" : 1234, "Array1" : [[1, 2], [3, 4]], "Array2" : [1, 2, 3, 4] }') "$$"
	assert ($$.Array1.Count -eq 2)
	assert ($$.Array2.Count -eq 4)

	# add the document
	$$ | Add-MdbcData

	# Pull expression
	#_110727_194907 "Array1" : [1, 2] -- argument is a single (!) item which is array (not two arguments!)
	$updates = (New-MdbcUpdate -Pull @{Array1 = 1, 2}), (New-MdbcUpdate -Pull @{Array2 = 1, 2})

	# update and get back
	$$ | Update-MdbcData $updates
	$$ = Get-MdbcData

	# test: removed from Array1 and not removed from Array2
	assert ("$$" -eq '{ "Array1" : [[3, 4]], "Array2" : [1, 2, 3, 4], "_id" : 1234 }') "$$"
	assert ($$.Array1.Count -eq 1)
	assert ($$.Array2.Count -eq 4)
}

task Update-MdbcData.-Pull.Null {
	@{_id = 131011; array = 1, $null, 2, $null} | Add-MdbcData
	Update-MdbcData (New-MdbcUpdate -Pull @{array = $null}) 131011
	$d = Get-MdbcData
	assert ($d.array.Count -eq 2)
	assert ($d.array[0] -eq 1)
	assert ($d.array[1] -eq 2)
}

task Update-MdbcData.-PullAll {
	# make and add a document
	$$ = New-MdbcData -Id 1
	$$.Array = 1, 2, 3, 4, 1, 2, 3, 4
	$$ | Add-MdbcData

	# update (PullAll) and get back
	$$ | Update-MdbcData (New-MdbcUpdate -PullAll @{Array = 1, 2})
	$$ = Get-MdbcData

	# test: 1, 2 are removed; 3, 4 are there
	assert ($$.Array.Count -eq 4)
	assert ($$.Array[0] -eq 3)
	assert ($$.Array[1] -eq 4)
	assert ($$.Array[2] -eq 3)
	assert ($$.Array[3] -eq 4)

	# update (Pull) and get back
	$$ | Update-MdbcData (New-MdbcUpdate -Pull @{Array = 3})
	$$ = Get-MdbcData

	# test: 3 is removed; 4 is there
	assert ($$.Array.Count -eq 2)
	assert ($$.Array[0] -eq 4)
	assert ($$.Array[1] -eq 4)
}

task Update-MdbcData.-Push {
	# add data
	@{_id = 1310110138; value = 1; array = @(1310110138)} | Add-MdbcData

	# try to push to non array #! try $null (fixed)
	Test-Error { Update-MdbcData (New-MdbcUpdate -Push @{value = $null}) 1310110138 } '*Cannot apply $push/$pushAll modifier to non-array*'

	# add to array
	Update-MdbcData (New-MdbcUpdate -Push @{array = $null}) 1310110138
	$d = Get-MdbcData

	assert ($d.array.Count -eq 2)
	assert ($d.array[0] -eq 1310110138)
	assert ($d.array[1] -eq $null)
}

task Update-MdbcData.-Rename {
	# add a document with Name1
	$$ = New-MdbcData -Id 1
	$$.Name1 = 42
	$$ | Add-MdbcData

	# update (rename Name1 to Name2) and get back
	$$ | Update-MdbcData (New-MdbcUpdate -Rename @{Name1 = 'Name2'})
	$$ = Get-MdbcData

	# test: Name2 gets 42, i.e. renamed
	assert ($$.Name2 -eq 42)
}

#1310111530
task Update-MdbcData.JSON-like {
	@{_id = 42 } | Add-MdbcData
	Update-MdbcData @{'$set' = @{ p1 = 123; p2 = 456}} @{_id = 42}
	$d = Get-MdbcData
	assert ($d.p1 -eq 123 -and $d.p2 -eq 456)
}
