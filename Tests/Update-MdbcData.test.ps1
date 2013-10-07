
Import-Module Mdbc

function Enter-BuildTask {
	Connect-Mdbc . test test -NewCollection
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
		New-MdbcUpdate p1 -Set 2
		New-MdbcUpdate p2 -Set 2
		New-MdbcUpdate p3 -Set 2
	)
	$$ = Get-MdbcData

	# test: 2, 2, 2
	assert ($$.p1 -eq 2)
	assert ($$.p2 -eq 2)
	assert ($$.p3 -eq 2)

	# update 2 fields and get back
	$something = $false
	$$ | Update-MdbcData @(
		New-MdbcUpdate p1 -Set 3
		if ($something) {
			New-MdbcUpdate p2 -Set 3
		}
		New-MdbcUpdate p3 -Set 3
	)
	$$ = Get-MdbcData

	# update 1 field and get back
	$$ | Update-MdbcData (New-MdbcUpdate p2 -Set 3)
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
	$$ | Update-MdbcData (New-MdbcUpdate Array -PopLast)
	$$ = Get-MdbcData

	# test: 3 is removed; 1, 2 are there
	assert ($$.Array.Count -eq 2)
	assert ($$.Array[0] -eq 1)
	assert ($$.Array[1] -eq 2)

	# update (PopFirst) and get back
	$$ | Update-MdbcData (New-MdbcUpdate Array -PopFirst)
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
	$updates = (New-MdbcUpdate Array1 -Pull @(1, 2)), (New-MdbcUpdate Array2 -Pull @(1, 2))

	# update and get back
	$$ | Update-MdbcData $updates
	$$ = Get-MdbcData

	# test: removed from Array1 and not removed from Array2
	assert ("$$" -eq '{ "Array1" : [[3, 4]], "Array2" : [1, 2, 3, 4], "_id" : 1234 }') "$$"
	assert ($$.Array1.Count -eq 1)
	assert ($$.Array2.Count -eq 4)
}

task Update-MdbcData.-PullAll {
	# make and add a document
	$$ = New-MdbcData -Id 1
	$$.Array = 1, 2, 3, 4, 1, 2, 3, 4
	$$ | Add-MdbcData

	# update (PullAll) and get back
	$$ | Update-MdbcData (New-MdbcUpdate Array -PullAll 1, 2)
	$$ = Get-MdbcData

	# test: 1, 2 are removed; 3, 4 are there
	assert ($$.Array.Count -eq 4)
	assert ($$.Array[0] -eq 3)
	assert ($$.Array[1] -eq 4)
	assert ($$.Array[2] -eq 3)
	assert ($$.Array[3] -eq 4)

	# update (Pull) and get back
	$$ | Update-MdbcData (New-MdbcUpdate Array -Pull 3)
	$$ = Get-MdbcData

	# test: 3 is removed; 4 is there
	assert ($$.Array.Count -eq 2)
	assert ($$.Array[0] -eq 4)
	assert ($$.Array[1] -eq 4)
}

task Update-MdbcData.-Rename {
	# add a document with Name1
	$$ = New-MdbcData -Id 1
	$$.Name1 = 42
	$$ | Add-MdbcData

	# update (rename Name1 to Name2) and get back
	$$ | Update-MdbcData (New-MdbcUpdate Name1 -Rename Name2)
	$$ = Get-MdbcData

	# test: Name2 gets 42, i.e. renamed
	assert ($$.Name2 -eq 42)
}
