
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

#_131121_104038
task Bad {
	# omitted update
	Test-Error { Update-MdbcData } 'Parameter Update must be specified and cannot be null.'

	# omitted query
	$m = 'Parameter Query must be specified and cannot be null.'
	Test-Error { Update-MdbcData @{} } $m
	Test-Error { $null | Update-MdbcData @{} } $m
}

task AddToSet {
	Invoke-Test {
		# add data
		@{_id = 1310110108; value = 1; array = @(1310110108)} | Add-MdbcData

		# try to add to non array #! try $null (fixed)
		Test-Error { Update-MdbcData (New-MdbcUpdate -AddToSet @{value = $null}) 1310110108 } $1310110108

		# add to array
		Update-MdbcData (New-MdbcUpdate -AddToSet @{array = $null}) 1310110108
		$d = Get-MdbcData

		equals $d.array.Count 2
		equals $d.array[0] 1310110108
		equals $d.array[1]
	}{
		Connect-Mdbc -NewCollection
		$1310110108 = '*Cannot apply $addToSet to a non-array field.*'
	}{
		Open-MdbcFile
		$1310110108 = 'Value "value" must be array.'
	}
}

task Set {
	Invoke-Test {
		# add data
		$r = New-MdbcData -Id 1
		$r.p1 = 1
		$r.p2 = 1
		$r.p3 = 1
		$r | Add-MdbcData

		# update 3 fields and get back
		$r | Update-MdbcData @(
			New-MdbcUpdate @{
				p1 = 2
				p2 = 2
				p3 = 2
			}
		)
		$r = Get-MdbcData

		# test: 2, 2, 2
		equals $r.p1 2
		equals $r.p2 2
		equals $r.p3 2

		# update 2 fields and get back
		$something = $false
		$r | Update-MdbcData @(
			New-MdbcUpdate @{p1 = 3}
			if ($something) {
				New-MdbcUpdate @{p2 = 3}
			}
			New-MdbcUpdate @{p3 = 3}
		)
		$r = Get-MdbcData

		# update 1 field and get back
		$r | Update-MdbcData (New-MdbcUpdate @{p2 = 3})
		$r = Get-MdbcData

		# test: 3, 3, 3
		equals $r.p1 3
		equals $r.p2 3
		equals $r.p3 3
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Pop {
	Invoke-Test {
		# make a document
		$r = New-MdbcData -Id 1
		$r.Array = 1, 2, 3
		$r | Add-MdbcData

		# update (PopLast) and get back
		$r | Update-MdbcData (New-MdbcUpdate -PopLast Array)
		$r = Get-MdbcData

		# test: 3 is removed; 1, 2 are there
		equals $r.Array.Count 2
		equals $r.Array[0] 1
		equals $r.Array[1] 2

		# update (PopFirst) and get back
		$r | Update-MdbcData (New-MdbcUpdate -PopFirst Array)
		$r = Get-MdbcData

		# test: 1 is removed; 2 is there
		equals $r.Array.Count 1
		equals $r.Array[0] 2
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Pull {
	Invoke-Test {
		# make a document with arrays
		$r = New-MdbcData
		$r._id = 1234
		$r.Array1 = @(
			, @(1, 2)
			, @(3, 4)
		)
		$r.Array2 = 1..4

		# test document data
		assert ("$r" -eq '{ "_id" : 1234, "Array1" : [[1, 2], [3, 4]], "Array2" : [1, 2, 3, 4] }') "$r"
		equals $r.Array1.Count 2
		equals $r.Array2.Count 4

		# add the document
		$r | Add-MdbcData

		# Pull expression
		#_110727_194907 "Array1" : [1, 2] -- argument is a single (!) item which is array (not two arguments!)
		$updates = (New-MdbcUpdate -Pull @{Array1 = 1, 2}), (New-MdbcUpdate -Pull @{Array2 = 1, 2})

		# update and get back
		$r | Update-MdbcData $updates
		$r = Get-MdbcData

		# test: removed from Array1 and not removed from Array2
		Test-Table -Force $r @{_id=1234; Array1=@(,@(3, 4)); Array2=1, 2, 3, 4}
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Pull.Null {
	Invoke-Test {
		@{_id = 131011; array = 1, $null, 2, $null} | Add-MdbcData
		Update-MdbcData (New-MdbcUpdate -Pull @{array = $null}) 131011
		$d = Get-MdbcData
		equals $d.array.Count 2
		equals $d.array[0] 1
		equals $d.array[1] 2
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task PullAll {
	Invoke-Test {
		# make and add a document
		$r = New-MdbcData -Id 1
		$r.Array = 1, 2, 3, 4, 1, 2, 3, 4
		$r | Add-MdbcData

		# update (PullAll) and get back
		$r | Update-MdbcData (New-MdbcUpdate -PullAll @{Array = 1, 2})
		$r = Get-MdbcData

		# test: 1, 2 are removed; 3, 4 are there
		equals $r.Array.Count 4
		equals $r.Array[0] 3
		equals $r.Array[1] 4
		equals $r.Array[2] 3
		equals $r.Array[3] 4

		# update (Pull) and get back
		$r | Update-MdbcData (New-MdbcUpdate -Pull @{Array = 3})
		$r = Get-MdbcData

		# test: 3 is removed; 4 is there
		equals $r.Array.Count 2
		equals $r.Array[0] 4
		equals $r.Array[1] 4
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Push {
	Invoke-Test {
		# add data
		@{_id = 1310110138; value = 1; array = @(1310110138)} | Add-MdbcData

		# try to push to non array #! try $null (fixed)
		Test-Error { Update-MdbcData (New-MdbcUpdate -Push @{value = $null}) 1310110138 } $1310110138

		# add to array
		Update-MdbcData (New-MdbcUpdate -Push @{array = $null}) 1310110138
		$d = Get-MdbcData

		equals $d.array.Count 2
		equals $d.array[0] 1310110138
		equals $d.array[1] $null
	}{
		Connect-Mdbc -NewCollection
		$1310110138 = "*The field 'value' must be an array*"
	}{
		Open-MdbcFile
		$1310110138 = 'Value "value" must be array.'
	}
}

task Rename {
	Invoke-Test {
		# add a document with Name1
		$r = New-MdbcData -Id 1
		$r.Name1 = 42
		$r | Add-MdbcData

		# update (rename Name1 to Name2) and get back
		$r | Update-MdbcData (New-MdbcUpdate -Rename @{Name1 = 'Name2'})
		$r = Get-MdbcData

		# test: Name2 gets 42, i.e. renamed
		equals $r.Name2 42
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task JSON-like {
	Invoke-Test {
		@{_id = 42 } | Add-MdbcData
		Update-MdbcData @{'$set' = @{ p1 = 123; p2 = 456}} @{_id = 42}
		$d = Get-MdbcData
		equals $d.p1 123
		equals $d.p2 456

		#_131102_084424 Fixed PSObject cannot be mapped to a BsonValue
		Update-MdbcData @{x=Get-Date} -Query @{} #_131103_204607
		$r = Get-MdbcData
		Test-Type $r.x 'System.DateTime'

		#_131122_164305
		$do = { Update-MdbcData @{x=Get-Date} -Query @{} -All }
		if ('test.test' -eq $Collection) {
			Test-Error $do '*multi update only works with $ operators*'
		}
		else {
			. $do
		}

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
	Test-Error { Update-MdbcData (New-MdbcUpdate -Set @{_id = 42; x = 1}) @{} } "*the (immutable) field '_id' was found*"
	Test-Error { Update-MdbcData (New-MdbcUpdate -Unset _id) @{} } "*the (immutable) field '_id' was found*"
	$r = Get-MdbcData
	equals $r.Count 1
	equals $r._id 1

	# Normal data deny _id changes

	Open-MdbcFile
	@{_id = 1} | Add-MdbcData
	Test-Error { Update-MdbcData (New-MdbcUpdate -Set @{_id = 42; x = 1}) @{} } '*Modification of _id is not allowed.'
	Test-Error { Update-MdbcData (New-MdbcUpdate -Unset _id) @{} } '*Modification of _id is not allowed.'
	$r = Get-MdbcData
	equals $r.Count 1
	equals $r._id 1

	# Simple data allow _id changes

	Open-MdbcFile -Simple
	@{_id = 1} | Add-MdbcData

	Update-MdbcData (New-MdbcUpdate -Set @{_id = 42}) @{}
	$r = Get-MdbcData
	equals $r.Count 1
	equals $r._id 42

	Update-MdbcData (New-MdbcUpdate -Unset _id) @{}
	$r = Get-MdbcData
	equals $r.Count 0
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
		equals $d[0].n 1 # changed
		equals $d[2].n 0 # not changed
	}

	# update which causes an error in the middle of data
	$update = New-MdbcUpdate -Inc @{n=1}
	"$update"

	. $init 'Acknowledged, ErrorAction Continue'
	$r = Update-MdbcData $update @{} -All -Result -ErrorAction 0 -ErrorVariable e
	equals $r # Driver 1.10
	equals $e.Count 1 # error
	$e[0].ToString()
	. $test

	. $init 'Acknowledged, ErrorAction Stop'
	$x = $null
	$r = .{ try { Update-MdbcData $update @{} -All -Result -ErrorAction Stop -ErrorVariable $e } catch { $x = $_ } }
	equals $e # no error due to exception
	equals $r # no result
	assert $x # exception
	. $test

	. $init 'Unacknowledged, ErrorAction Stop (irrelevant)'
	$r = Update-MdbcData $update @{} -All -Result -WriteConcern ([MongoDB.Driver.WriteConcern]::Unacknowledged) -ErrorAction Stop -ErrorVariable e
	equals $e.Count 0 # no error
	equals $r # no result
	. $test
}

task Upsert {
	Invoke-Test {
		Update-MdbcData (New-MdbcUpdate -Set @{x=42}) (New-MdbcQuery _id miss) -Add
		$r = Get-MdbcData
		assert ($r._id = 'miss')
		assert ($r.x = 42)
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task All {
	$data = {
		@{_id=1; x=1}, @{_id=2; x=1} | Add-MdbcData
	}
	Invoke-Test {
		# Default - one is changed
		. $init
		Update-MdbcData (New-MdbcUpdate -Set @{x=42}) @{}
		$r1, $r2 = Get-MdbcData
		# changed
		equals $r1._id 1
		equals $r1.x 42
		# not changed
		equals $r2._id 2
		equals $r2.x 1

		# All - two are changed
		. $init
		Update-MdbcData (New-MdbcUpdate -Set @{x=42}) @{} -All
		$r1, $r2 = Get-MdbcData
		# changed
		equals $r1._id 1
		equals $r1.x 42
		# changed
		equals $r2._id 2
		equals $r2.x 42
	}{
		$init = { Connect-Mdbc -NewCollection; . $data }
	}{
		$init = { Open-MdbcFile; . $data }
	}
}

task WriteConcernResult {
	$data = {
		@{_id=1; x=1}, @{_id=2; x=1} | Add-MdbcData
	}
	Invoke-Test {
		# One changed
		. $init
		$r = Update-MdbcData (New-MdbcUpdate -Set @{x=42}) @{} -Result
		equals $r.DocumentsAffected 1L
		assert $r.UpdatedExisting
		equals $r.HasLastErrorMessage $false

		# Two changed
		. $init
		$r = Update-MdbcData (New-MdbcUpdate -Set @{x=42}) @{} -Result -All
		equals $r.DocumentsAffected 2L
		assert $r.UpdatedExisting
		equals $r.HasLastErrorMessage $false

		# None changed, one added
		. $init
		$r = Update-MdbcData (New-MdbcUpdate -Set @{x=42}) @{miss=1} -Result -Add -All
		equals $r.DocumentsAffected 1L
		assert (!$r.UpdatedExisting)
		equals $r.HasLastErrorMessage $false

		# Error, data do not fit the update
		. $init
		$r = Update-MdbcData (New-MdbcUpdate -Push @{x=42}) @{_id=1} -Result -ErrorAction 0 -ErrorVariable e
		equals $r # Driver 1.10
		$m = if ('test.test' -eq $Collection) {"*The field 'x' must be an array but*"} else {'*Value "x" must be array.*'}
		assert ($e[0] -like $m)
	}{
		$init = { Connect-Mdbc -NewCollection; . $data }
	}{
		$init = { Open-MdbcFile; . $data }
	}
}
