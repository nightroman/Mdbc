
<#
.Synopsis
	Tests Get-MdbcData.
#>

. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

task Bad {
	Test-Error { Get-MdbcData -Update bad } '*Exception setting "Update": "Invalid update object type:*'
}

task As {
	# strongly typed helpers
	Add-Type @'
using System;
public class TestGetMdbcDataAs1 {
	public int _id;
	public int data;
	public DateTime time;
}
public class TestGetMdbcDataAs2 {
	public int _id;
	public int data;
}
public class TestGetMdbcDataAs3 {
	public object _id;
	public int data;
	public DateTime time;
}
'@
	Invoke-Test {
		. $$

		# add data with custom _id
		1..5 | .{process{ @{_id = $_; data = $_ % 2; time = Get-Date} }} | Add-MdbcData

		# get full data
		$r = Get-MdbcData -As ([TestGetMdbcDataAs1]) -First 1
		assert ($r -is [TestGetMdbcDataAs1])

		# get subset of fields
		$r = Get-MdbcData -Property data -As ([TestGetMdbcDataAs2]) -First 1
		assert ($r -is [TestGetMdbcDataAs2])

		. $$

		# add data with default _id
		1..5 | .{process{ @{data = $_} }} | Add-MdbcData

		# get data, the extra field `time` is not an issue
		$r = Get-MdbcData -As ([TestGetMdbcDataAs3]) -First 1
		assert ($r -is [TestGetMdbcDataAs3])
	}{
		$$ = {Connect-Mdbc -NewCollection}
	}{
		$$ = {Open-MdbcFile}
	}
}

task Cursor {
	Connect-Mdbc -NewCollection

	# add documents
	20..1 | .{process{ @{_id = $_} }} | Add-MdbcData

	# get 5 skipping 5
	$cursor = $Collection.FindAllAs([Mdbc.Dictionary]).SetSkip(5).SetLimit(5)
	equals $cursor.Count() 20L
	equals $cursor.Size() 5L

	# get data as array
	$set = @($cursor)
	equals $set[0]._id 15
	equals $set[-1]._id 11

	# get and test ordered data
	$cursor = $Collection.FindAllAs([Mdbc.Dictionary]).SetSkip(5).SetLimit(5)
	$set = @($cursor.SetSortOrder('_id'))
	equals $set[0]._id 6
	equals $set[-1]._id 10
}

#_131119_113717
task Distinct {
	$data = @(
		@{x=1}, @{x=1}, @{x=$true} # same 1, true is not 1
		@{x=2}, @{x=2.0}, @{x=2L}  # different types of the same 2
		@{x=@{y=3}}, @{x=@{y=3.0}} # same objects with some differences
	)
	Invoke-Test {
		$data | Add-MdbcData
		$r = Get-MdbcData -Distinct x
		"$r"
		equals "$r" '1 True 2 { "y" : 3 }'
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Remove {
	Invoke-Test {
		# add documents
		1..9 | .{process{ @{Value1 = $_; Value2 = $_ % 2} }} | Add-MdbcData

		# get and remove the first even > 2, it is 4
		$data = Get-MdbcData (New-MdbcQuery Value1 -GT 2) -SortBy Value2, Value1 -Remove -As Default
		equals $data.Value1 4

		# do again, it is 6
		$data = Get-MdbcData (New-MdbcQuery Value1 -GT 2) -SortBy Value2, Value1 -Remove
		equals $data.Value1 6

		# try missing
		$data = Get-MdbcData (New-MdbcQuery Value1 -LT 0) -SortBy Value2, Value1 -Remove
		equals $data

		# count: 9 - 2
		equals 7L (Get-MdbcData -Count)

		# null SortBy
		$data = Get-MdbcData (New-MdbcQuery Value1 -GT 2) -Remove
		equals $data.Value1 3
		equals 6L (Get-MdbcData -Count)

		# null Query
		$data = Get-MdbcData -SortBy Value2, Value1 -Remove
		equals $data.Value1 2
		equals 5L (Get-MdbcData -Count)
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task SortBy {
	Invoke-Test {
		# add documents (9,1), (8,0), (7,1), .. (0,0)
		9..0 | .{process{ @{Value1 = $_; Value2 = $_ % 2} }} | Add-MdbcData

		# sort by Value1
		$data = Get-MdbcData -SortBy Value1 -First 1
		equals $data.Value1 0

		# sort by two values, ascending by default
		$data = Get-MdbcData -SortBy Value2, Value1
		equals $data[0].Value1 0
		equals $data[1].Value1 2
		equals $data[-2].Value1 7
		equals $data[-1].Value1 9

		# sort by two values, descending explicitly
		$data = Get-MdbcData -SortBy @{Value2=0}, @{Value1=0}
		equals $data[0].Value1 9
		equals $data[1].Value1 7
		equals $data[-2].Value1 2
		equals $data[-1].Value1 0
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

# Tests Get-MdbcData -Update -Add -New
# https://github.com/mongodb/mongo/blob/master/jstests/core/find_and_modify4.js (path changes!)
task Update {
	Invoke-Test {
		. $$

		# this is the best way to build auto-increment
		function getNextVal($counterName) {
			(Get-MdbcData (New-MdbcQuery _id $counterName) -Update (New-MdbcUpdate -Inc @{val = 1}) -Add -New -As Default).val
		}

		equals 1 (getNextVal a)
		equals 2 (getNextVal a)
		equals 3 (getNextVal a)
		equals 1 (getNextVal z)
		equals 2 (getNextVal z)
		equals 4 (getNextVal a)

		. $$

		function helper($upsert) {
			Get-MdbcData (New-MdbcQuery _id asdf) -Update (New-MdbcUpdate -Inc @{val = 1}) -Add:$upsert
		}

		# upsert:false so nothing there before and after
		equals (helper $false)
		equals 0L (Get-MdbcData -Count)

		# upsert:true so nothing there before; something there after
		equals (helper $true)
		equals 1L (Get-MdbcData -Count)

		$data = helper $true
		equals $data._id asdf
		equals $data.val 1 #_131103_185751

		# upsert only matters when obj doesn't exist
		$data = helper $false
		equals $data._id asdf
		equals $data.val 2

		$data = helper $true
		equals $data._id asdf
		equals $data.val 3

		# _id created if not specified
		$out = Get-MdbcData (New-MdbcQuery a 1) -Update (New-MdbcUpdate @{b = 2}) -Add -New
		assert $out._id
		equals 1 $out.a
		equals 2 $out.b
	}{
		$$ = {Connect-Mdbc -NewCollection}
	}{
		$$ = {Open-MdbcFile}
	}
}

# -Skip, -First, -Last
task Limits {
	Invoke-Test {
		1..5 | .{process{@{_id=$_}}} | Add-MdbcData
		equals (Get-MdbcData -Count -First 3) 3L
		equals (Get-MdbcData -Count -Last 3) 3L
		equals (Get-MdbcData -Count -Skip 3) 2L

		$r = @(Get-MdbcData -First 2 -Skip 1 (New-MdbcQuery _id -GTE 2))
		equals $r.Count 2
		equals $r[0]._id 3

		$r = @(Get-MdbcData -Last 2 -Skip 1 (New-MdbcQuery _id -LTE 4))
		equals $r.Count 2
		equals $r[1]._id 3

		Test-Error { Get-MdbcData -First 1 -Last 1 } '*Parameters First and Last cannot be specified together.'
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

# -Update, -Add, -New
task Upsert {
	$query = New-MdbcQuery _id miss
	$update = New-MdbcUpdate -Set @{x=42}
	Invoke-Test {
		# -Update
		. $$
		$r = Get-MdbcData $query -Update $update
		assert (!$r)
		equals (Get-MdbcData -Count) 0L

		# -Update -Add
		. $$
		$r = Get-MdbcData $query -Update $update -Add
		assert (!$r)
		$r = Get-MdbcData
		equals $r.x 42
		equals $r._id 'miss'

		# -Update -Add -New
		. $$
		$r = Get-MdbcData $query -Update $update -Add -New
		equals $r.x 42
		equals $r._id 'miss'
		$r = Get-MdbcData
		equals $r.x 42
		equals $r._id 'miss'
	}{
		$$ = { Connect-Mdbc -NewCollection }
	}{
		$$ = { Open-MdbcFile }
	}
}

task UpdateResult {
	$query = New-MdbcQuery _id 1
	$update = New-MdbcUpdate -Set @{x=42}
	Invoke-Test {
		# update missing
		. $$
		$d = Get-MdbcData $query -Update $update -ResultVariable r
		assert (!$d)
		equals (Get-MdbcData -Count) 0L
		equals $r.DocumentsAffected 0L
		equals $r.UpdatedExisting $false

		# update existing, get old
		. $$
		@{_id = 1; x = 1} | Add-MdbcData
		$d = Get-MdbcData $query -Update $update -ResultVariable r
		equals "$d" '{ "_id" : 1, "x" : 1 }'
		$d = Get-MdbcData
		equals "$d" '{ "_id" : 1, "x" : 42 }'
		equals $r.DocumentsAffected 1L
		equals $r.UpdatedExisting $true

		# update existing, get new
		. $$
		@{_id = 1; x = 1} | Add-MdbcData
		$d = Get-MdbcData $query -Update $update -New -ResultVariable r
		equals "$d" '{ "_id" : 1, "x" : 42 }'
		$d = Get-MdbcData
		equals "$d" '{ "_id" : 1, "x" : 42 }'
		equals $r.DocumentsAffected 1L
		equals $r.UpdatedExisting $true

		# upsert missing, get old
		. $$
		$d = Get-MdbcData $query -Update $update -Add -ResultVariable r
		assert (!$d)
		$d = Get-MdbcData
		equals "$d" '{ "_id" : 1, "x" : 42 }'
		equals $r.DocumentsAffected 1L
		equals $r.UpdatedExisting $false

		# upsert missing, get new
		. $$
		$d = Get-MdbcData $query -Update $update -Add -New -ResultVariable r
		equals "$d" '{ "_id" : 1, "x" : 42 }'
		$d = Get-MdbcData
		equals "$d" '{ "_id" : 1, "x" : 42 }'
		equals $r.DocumentsAffected 1L
		equals $r.UpdatedExisting $false
	}{
		$$ = { Connect-Mdbc -NewCollection }
	}{
		$$ = { Open-MdbcFile }
	}
}

task IncludeFields {
	Invoke-Test {
		@{_id=1; p1=1; p2=2} | Add-MdbcData

		$r = Get-MdbcData 1 -Property p2, p3
		equals $r._id 1
		equals $r.p2 2
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task ExcludeFields {
	Invoke-Test {
		@{_id=1; p1=1; p2=2} | Add-MdbcData

		$ff = New-Object MongoDB.Driver.Builders.FieldsBuilder
		$ff = $ff.Exclude('p1', 'p3')

		$r = Get-MdbcData 1 -Property $ff
		equals $r.Count 2
		equals $r._id 1
		equals $r.p2 2
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

# Synopsis: Fixed #3.
task SortByMissing {
	Invoke-Test {
		@{_id=1; p1=1; p2=2},
		@{_id=2; p1=0; p2=2} | Add-MdbcData

		$r = Get-MdbcData -SortBy p1, p3
		equals $r.Count 2
		equals $r[0]._id 2
		equals $r[1]._id 1
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}
