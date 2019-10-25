<#
.Synopsis
	Test Set-MdbcData and Update-MdbcData.

.Description
	These cmdlets are similar and the command result is the same.
#>

. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

#_131121_104038
task BadSet {
	Test-Error { Set-MdbcData } $ErrorFilter
	Test-Error { Set-MdbcData '' } $ErrorFilter
	Test-Error { Set-MdbcData $null } $ErrorFilter
	Test-Error { Set-MdbcData @{} } $ErrorSet
	Test-Error { Set-MdbcData @{} $null } $ErrorSet
	Test-Error { Set-MdbcData @{} '' } '*Cannot convert System.String to a document.*'
}

#_131121_104038
task BadUpdate {
	Test-Error { Update-MdbcData } $ErrorFilter
	Test-Error { Update-MdbcData '' } $ErrorFilter
	Test-Error { Update-MdbcData $null } $ErrorFilter
	Test-Error { Update-MdbcData @{} } $ErrorUpdate
	Test-Error { Update-MdbcData @{} '' } '*"Invalid JSON."'
	Test-Error { Update-MdbcData @{} $null } $ErrorUpdate
}

task AddToSet {
	Connect-Mdbc -NewCollection
	$1310110108 = '*Cannot apply $addToSet to non-array field.*'

	# add data
	@{_id = 1310110108; value = 1; array = @(1310110108)} | Add-MdbcData

	# try to add to non array #! try $null (fixed)
	Test-Error { Update-MdbcData @{_id = 1310110108} @{'$addToSet' = @{value = $null}} } $1310110108

	# add to array
	Update-MdbcData @{_id = 1310110108} @{'$addToSet' = @{array = $null}}
	$d = Get-MdbcData

	equals $d.array.Count 2
	equals $d.array[0] 1310110108
	equals $d.array[1]
}

task Set {
	Connect-Mdbc -NewCollection

	# add data
	$r = New-MdbcData -Id 1
	$r.p1 = 1
	$r.p2 = 1
	$r.p3 = 1
	$r | Add-MdbcData

	# update some fields and get back
	Update-MdbcData @{_id = 1} @{'$set' = @{p1 = 2; p3 = 2; p4 = 2}}
	$r = Get-MdbcData
	equals $r.p1 2
	equals $r.p2 1
	equals $r.p3 2
	equals $r.p4 2
}

task Pop {
	Connect-Mdbc -NewCollection

	# make a document
	$r = New-MdbcData -Id 1
	$r.Array = 1, 2, 3
	$r | Add-MdbcData

	# update (pop last) and get back
	Update-MdbcData @{_id = 1} @{'$pop' = @{Array = 1}}
	$r = Get-MdbcData

	# test: 3 is removed; 1, 2 are there
	equals $r.Array.Count 2
	equals $r.Array[0] 1
	equals $r.Array[1] 2

	# update (pop first) and get back
	Update-MdbcData @{_id = 1} @{'$pop' = @{Array = -1}}
	$r = Get-MdbcData

	# test: 1 is removed; 2 is there
	equals $r.Array.Count 1
	equals $r.Array[0] 2
}

task Pull {
	Connect-Mdbc -NewCollection

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
	$update = @{'$pull' = @{Array1 = 1, 2; Array2 = 1, 2}}

	# update and get back
	Update-MdbcData @{_id = 1234} $update
	$r = Get-MdbcData

	# test: removed from Array1 and not removed from Array2
	Test-Table -Force $r @{_id=1234; Array1=@(,@(3, 4)); Array2=1, 2, 3, 4}
}

task Pull.Null {
	Connect-Mdbc -NewCollection

	@{_id = 131011; array = 1, $null, 2, $null} | Add-MdbcData
	Update-MdbcData @{_id = 131011} @{'$pull' = @{array = $null}}
	$d = Get-MdbcData
	equals $d.array.Count 2
	equals $d.array[0] 1
	equals $d.array[1] 2
}

task PullAll {
	Connect-Mdbc -NewCollection

	# make and add a document
	Add-MdbcData @{Array = 1, 2, 3, 4, 1, 2, 3, 4}

	# update (pullAll) and get back
	Update-MdbcData @{} @{'$pullAll' = @{Array = 1, 2}}
	$r = Get-MdbcData

	# test: 1, 2 are removed; 3, 4 are there
	equals $r.Array.Count 4
	equals $r.Array[0] 3
	equals $r.Array[1] 4
	equals $r.Array[2] 3
	equals $r.Array[3] 4

	# update (pull) and get back
	Update-MdbcData @{} @{'$pull' = @{Array = 3}}
	$r = Get-MdbcData

	# test: 3 is removed; 4 is there
	equals $r.Array.Count 2
	equals $r.Array[0] 4
	equals $r.Array[1] 4
}

task Push {
	Connect-Mdbc -NewCollection
	$1310110138 = "*The field 'value' must be an array*"

	# add data
	@{value = 1; array = @(1310110138)} | Add-MdbcData

	# try to push to non array #! try $null (fixed)
	Test-Error { Update-MdbcData @{} @{'$push' = @{value = $null}} } $1310110138

	# add to array
	Update-MdbcData @{} @{'$push' = @{array = $null}}
	$d = Get-MdbcData

	equals $d.array.Count 2
	equals $d.array[0] 1310110138
	equals $d.array[1] $null
}

task Rename {
	Connect-Mdbc -NewCollection

	# add a document with Name1
	$r = New-MdbcData -Id 1
	$r.Name1 = 42
	$r | Add-MdbcData

	# update (rename Name1 to Name2) and get back
	Update-MdbcData @{_id = 1} @{'$rename' = @{Name1 = 'Name2'}}
	$r = Get-MdbcData

	# test: Name2 gets 42, i.e. renamed
	equals $r.Name2 42
}

# was an alternative way, now it is the main
task JSON-like {
	Connect-Mdbc -NewCollection

	@{_id = 42 } | Add-MdbcData
	Update-MdbcData @{_id = 42} @{'$set' = @{ p1 = 123; p2 = 456}}
	$d = Get-MdbcData
	equals $d.p1 123
	equals $d.p2 456

	#_131102_084424 Fixed PSObject cannot be mapped to a BsonValue
	Set-MdbcData @{} @{x=Get-Date} #_131103_204607
	$r = Get-MdbcData
	Test-Type $r.x 'System.DateTime'

	#? obsolete?
	# was '*multi update is not supported for replacement-style update*'
	$do = { Update-MdbcData @{} @{x=Get-Date} -Many }
	Test-Error $do 'Element name ''x'' is not valid''.'
}

task ChangeId {
	Connect-Mdbc -NewCollection
	@{_id = 1} | Add-MdbcData
	Test-Error { Update-MdbcData @{} @{'$set' = @{_id = 42; x = 1}} } "*the immutable field '_id'*"
	Test-Error { Update-MdbcData @{} @{'$unset' = @{_id = 1}} } "*the immutable field '_id'*"
	$r = Get-MdbcData
	equals $r.Count 1
	equals $r._id 1
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
		$d = Get-MdbcData -Sort @{_id = 1}
		"$d"
		equals $d[0].n 1 # changed
		equals $d[2].n 0 # not changed
	}

	# update which causes an error in the middle of data
	$update = New-MdbcData @{'$inc' = @{n = 1}}
	"$update"

	. $init 'ErrorAction Continue'
	$r = Update-MdbcData @{} $update -Many -Result -ErrorAction 0 -ErrorVariable e
	equals $r # Driver 1.10
	equals $e.Count 1 # error
	$e[0].ToString()
	. $test

	. $init 'ErrorAction Stop'
	$x = $null
	$r = .{ try { Update-MdbcData @{} $update -Many -Result -ErrorAction Stop -ErrorVariable $e } catch { $x = $_ } }
	equals $e # no error due to exception
	equals $r # no result
	assert $x # exception
	. $test
}

task Upsert {
	Connect-Mdbc -NewCollection

	Update-MdbcData @{_id = 'miss'} @{'$set' = @{x = 42}} -Add
	$r = Get-MdbcData
	assert ($r._id = 'miss')
	assert ($r.x = 42)
}

task All {
	$init = {
		Connect-Mdbc -NewCollection
		@{_id=1; x=1}, @{_id=2; x=1} | Add-MdbcData
	}

	# Default - one is changed
	. $init
	Update-MdbcData @{} @{'$set' = @{x = 42}}
	$r1, $r2 = Get-MdbcData
	# changed
	equals $r1._id 1
	equals $r1.x 42
	# not changed
	equals $r2._id 2
	equals $r2.x 1

	# All - two are changed
	. $init
	Update-MdbcData @{} @{'$set' = @{x = 42}} -Many
	$r1, $r2 = Get-MdbcData
	# changed
	equals $r1._id 1
	equals $r1.x 42
	# changed
	equals $r2._id 2
	equals $r2.x 42
}

#! was about write concern
task WriteConcernResult {
	$init = {
		Connect-Mdbc -NewCollection
		@{_id=1; x=1}, @{_id=2; x=1} | Add-MdbcData
	}

	# One changed
	. $init
	$r = Update-MdbcData @{} @{'$set' = @{x = 42}} -Result
	equals $r.MatchedCount 1L
	equals $r.ModifiedCount 1L

	# Two changed
	. $init
	$r = Update-MdbcData @{} @{'$set' = @{x = 42}} -Result -Many
	equals $r.MatchedCount 2L
	equals $r.ModifiedCount 2L

	# None changed, one added
	. $init
	$r = Update-MdbcData @{miss=1} @{'$set' = @{x = 42}} -Result -Add -Many
	equals $r.MatchedCount 0L
	equals $r.ModifiedCount 0L

	# Error, data do not fit the update
	. $init
	$r = Update-MdbcData @{_id = 1} @{'$push' = @{x=42}} -Result -ErrorAction 0 -ErrorVariable e
	equals $r # Driver 1.10
	assert ($e[0] -like "*The field 'x' must be an array but*")
}

# Set-MdbcData -Add
task SetAdd {
	Connect-Mdbc -NewCollection

	Set-MdbcData @{_id = 87} @{p2 = 2} -Add
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 87, "p2" : 2 }'

	Set-MdbcData @{_id = 87} @{p3 = 3} -Add
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 87, "p3" : 3 }'
}
