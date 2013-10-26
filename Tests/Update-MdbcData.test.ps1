
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

task Update-MdbcData.-AddToSet {
	Invoke-Test {
		# add data
		@{_id = 1310110108; value = 1; array = @(1310110108)} | Add-MdbcData

		# try to add to non array #! try $null (fixed)
		Test-Error { Update-MdbcData (New-MdbcUpdate -AddToSet @{value = $null}) 1310110108 } $1310110108

		# add to array
		Update-MdbcData (New-MdbcUpdate -AddToSet @{array = $null}) 1310110108
		$d = Get-MdbcData

		assert ($d.array.Count -eq 2)
		assert ($d.array[0] -eq 1310110108)
		assert ($d.array[1] -eq $null)
	}{
		Connect-Mdbc -NewCollection
		$1310110108 = '*Cannot apply $addToSet modifier to non-array*'
	}{
		Open-MdbcFile
		$1310110108 = 'Value "value" must be array.'
	}
}

task Update-MdbcData.-Set {
	Invoke-Test {
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
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Update-MdbcData.-PopLast.-PopFirst {
	Invoke-Test {
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
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Update-MdbcData.-Pull {
	Invoke-Test {
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
		Test-Table -Force $$ @{_id=1234; Array1=@(,@(3, 4)); Array2=1, 2, 3, 4}
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Update-MdbcData.-Pull.Null {
	Invoke-Test {
		@{_id = 131011; array = 1, $null, 2, $null} | Add-MdbcData
		Update-MdbcData (New-MdbcUpdate -Pull @{array = $null}) 131011
		$d = Get-MdbcData
		assert ($d.array.Count -eq 2)
		assert ($d.array[0] -eq 1)
		assert ($d.array[1] -eq 2)
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Update-MdbcData.-PullAll {
	Invoke-Test {
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
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Update-MdbcData.-Push {
	Invoke-Test {
		# add data
		@{_id = 1310110138; value = 1; array = @(1310110138)} | Add-MdbcData

		# try to push to non array #! try $null (fixed)
		Test-Error { Update-MdbcData (New-MdbcUpdate -Push @{value = $null}) 1310110138 } $1310110138

		# add to array
		Update-MdbcData (New-MdbcUpdate -Push @{array = $null}) 1310110138
		$d = Get-MdbcData

		assert ($d.array.Count -eq 2)
		assert ($d.array[0] -eq 1310110138)
		assert ($d.array[1] -eq $null)
	}{
		Connect-Mdbc -NewCollection
		$1310110138 = '*Cannot apply $push/$pushAll modifier to non-array*'
	}{
		Open-MdbcFile
		$1310110138 = 'Value "value" must be array.'
	}
}

task Update-MdbcData.-Rename {
	Invoke-Test {
		# add a document with Name1
		$$ = New-MdbcData -Id 1
		$$.Name1 = 42
		$$ | Add-MdbcData

		# update (rename Name1 to Name2) and get back
		$$ | Update-MdbcData (New-MdbcUpdate -Rename @{Name1 = 'Name2'})
		$$ = Get-MdbcData

		# test: Name2 gets 42, i.e. renamed
		assert ($$.Name2 -eq 42)
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Update-MdbcData.JSON-like {
	Invoke-Test {
		@{_id = 42 } | Add-MdbcData
		Update-MdbcData @{'$set' = @{ p1 = 123; p2 = 456}} @{_id = 42}
		$d = Get-MdbcData
		assert ($d.p1 -eq 123 -and $d.p2 -eq 456)

		#_131102_084424 Fixed PSObject cannot be mapped to a BsonValue
		Update-MdbcData @{x=Get-Date} -Query @{} #_131103_204607
		$r = Get-MdbcData
		Test-Type $r.x 'System.DateTime'

		#_131102_111738 Invalid type, weird error: A positional parameter cannot be found that accepts argument 'bad'.
		Test-Error { Update-MdbcData bad @{} } '*Invalid update object type: System.String. Valid types: update(s), dictionary(s).*'

		# Invalid type (was no weird error)
		Test-Error { Update-MdbcData bad -Query @{} } '*Invalid update object type: System.String. Valid types: update(s), dictionary(s).*'
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task ChangeId {
	# Native data deny _id changes

	Connect-Mdbc -NewCollection
	@{_id = 1} | Add-MdbcData
	Test-Error { Update-MdbcData (New-MdbcUpdate -Set @{_id = 42; x = 1}) @{} } '*"Mod on _id not allowed", "code" : 10148,*'
	Test-Error { Update-MdbcData (New-MdbcUpdate -Unset _id) @{} } '*"Mod on _id not allowed", "code" : 10148,*'
	$r = Get-MdbcData
	assert ($r.Count -eq 1 -and $r._id -eq 1)

	# Normal data deny _id changes

	Open-MdbcFile
	@{_id = 1} | Add-MdbcData
	Test-Error { Update-MdbcData (New-MdbcUpdate -Set @{_id = 42; x = 1}) @{} } '*Modification of _id is not allowed.'
	Test-Error { Update-MdbcData (New-MdbcUpdate -Unset _id) @{} } '*Modification of _id is not allowed.'
	$r = Get-MdbcData
	assert ($r.Count -eq 1 -and $r._id -eq 1)

	# Simple data allow _id changes

	Open-MdbcFile -Simple
	@{_id = 1} | Add-MdbcData

	Update-MdbcData (New-MdbcUpdate -Set @{_id = 42}) @{}
	$r = Get-MdbcData
	assert ($r.Count -eq 1 -and $r._id -eq 42)

	Update-MdbcData (New-MdbcUpdate -Unset _id) @{}
	$r = Get-MdbcData
	assert ($r.Count -eq 0)
}

task Errors {
	Connect-Mdbc -NewCollection
	# makes test data
	$init = {
		"`n$args"
		$e = $r = $null
		Connect-Mdbc -NewCollection
		@{_id=1; n=0},  # good, `a` will be changed
		@{_id=2; n='bad'}, # bad, update chokes at it
		@{_id=3; n=0} | # good but is not changed
		Add-MdbcData
	}

	# checks that data are partially changed
	$test = {
		$d = Get-MdbcData -SortBy _id
		"$d"
		assert ($d[0].n -eq 1) # changed
		assert ($d[2].n -eq 0) # not changed
	}

	# update which causes an error in the middle of data
	$update = New-MdbcUpdate -Inc @{n=1}
	"$update"

	. $init 'Acknowledged, ErrorAction Continue'
	$r = Update-MdbcData $update @{} -Modes Multi -Result -ErrorAction 0 -ErrorVariable e
	assert ($e.Count -eq 1) # error
	$e[0].ToString()
	assert ($r) # result
	#bug driver DocumentsAffected should be 1
	assert ($r.DocumentsAffected -eq 0)
	. $test

	. $init 'Acknowledged, ErrorAction Stop'
	$r = .{ try { Update-MdbcData $update @{} -Modes Multi -Result -ErrorAction Stop -ErrorVariable $e } catch {} }
	assert ($null -eq $e) # no error due to exception
	assert ($null -eq $r) # no result
	. $test

	. $init 'Unacknowledged, ErrorAction Stop (irrelevant)'
	$r = Update-MdbcData $update @{} -Modes Multi -Result -WriteConcern ([MongoDB.Driver.WriteConcern]::Unacknowledged) -ErrorAction Stop -ErrorVariable e
	assert ($e.Count -eq 0) # no error
	assert ($null -eq $r) # no result
	. $test
}

task Upsert {
	Invoke-Test {
		Update-MdbcData (New-MdbcUpdate -Set @{x=42}) (New-MdbcQuery _id miss) -Modes Upsert
		$r = Get-MdbcData
		assert ($r._id = 'miss')
		assert ($r.x = 42)
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Multi {
	$data = {
		@{_id=1; x=1}, @{_id=2; x=1} | Add-MdbcData
	}
	Invoke-Test {
		# Default - one is changed
		. $$
		Update-MdbcData (New-MdbcUpdate -Set @{x=42}) @{}
		$r1, $r2 = Get-MdbcData
		assert ($r1._id -eq 1 -and $r1.x -eq 42) # changed
		assert ($r2._id -eq 2 -and $r2.x -eq 1) # not changed

		# Multi - two are changed
		. $$
		Update-MdbcData (New-MdbcUpdate -Set @{x=42}) @{} -Modes Multi
		$r1, $r2 = Get-MdbcData
		assert ($r1._id -eq 1 -and $r1.x -eq 42) # changed
		assert ($r2._id -eq 2 -and $r2.x -eq 42) # changed
	}{
		$$ = { Connect-Mdbc -NewCollection; . $data }
	}{
		$$ = { Open-MdbcFile; . $data }
	}
}
