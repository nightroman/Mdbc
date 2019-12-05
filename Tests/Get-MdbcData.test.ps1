<#
.Synopsis
	Tests Get-MdbcData.
#>

. ./Zoo.ps1
Set-StrictMode -Version Latest

task Bad {
	Connect-Mdbc
	Test-Error { Get-MdbcData -Update 42 } "Cannot bind parameter 'Update'*"
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
	### 1
	Connect-Mdbc -NewCollection

	# add data with custom _id
	1..5 | .{process{ @{_id = $_; data = $_ % 2; time = Get-Date} }} | Add-MdbcData

	# get full data
	$r = Get-MdbcData -As ([TestGetMdbcDataAs1]) -First 1
	assert ($r -is [TestGetMdbcDataAs1])

	# get subset of fields
	$r = Get-MdbcData -Project '{data : 1}' -As ([TestGetMdbcDataAs2]) -First 1
	assert ($r -is [TestGetMdbcDataAs2])

	### 2
	Connect-Mdbc -NewCollection

	# add data with default _id
	1..5 | .{process{ @{data = $_} }} | Add-MdbcData

	# get data, the extra field `time` is not an issue
	$r = Get-MdbcData -As ([TestGetMdbcDataAs3]) -First 1
	assert ($r -is [TestGetMdbcDataAs3])
}

#_131119_113717
task Distinct {
	Connect-Mdbc -NewCollection

	$data = @(
		@{x=1}, @{x=1}, @{x=$true} # same 1, true is not 1
		@{x=2}, @{x=2.0}, @{x=2L}  # different types of the same 2
		@{x=@{y=3}}, @{x=@{y=3.0}} # same objects with some differences
	)

	$data | Add-MdbcData
	$r = Get-MdbcData -Distinct x | Sort-Object {$_.ToString()}
	"$r"
	equals "$r" '{ "y" : 3 } 1 2 True'
}

task Remove {
	Connect-Mdbc -NewCollection

	# add documents
	1..9 | .{process{ @{Value1 = $_; Value2 = $_ % 2} }} | Add-MdbcData

	# get and remove the first even > 2, it is 4
	$data = Get-MdbcData '{Value1 : {$gt : 2}}' -Sort '{Value2 : 1, Value1 : 1}' -Remove -As Default
	equals $data.Value1 4

	# do again, it is 6
	$data = Get-MdbcData '{Value1 : {$gt : 2}}' -Sort '{Value2 : 1, Value1 : 1}' -Remove
	equals $data.Value1 6

	# try missing
	$data = Get-MdbcData '{Value1 : {$lt : 0}}' -Sort '{Value2 : 1, Value1 : 1}' -Remove
	equals $data

	# count: 9 - 2
	equals 7L (Get-MdbcData -Count)

	# null SortBy
	$data = Get-MdbcData '{Value1 : {$gt : 2}}' -Remove
	equals $data.Value1 3
	equals 6L (Get-MdbcData -Count)

	# null Query
	$data = Get-MdbcData -Sort '{Value2 : 1, Value1 : 1}' -Remove
	equals $data.Value1 2
	equals 5L (Get-MdbcData -Count)
}

task Sort {
	Connect-Mdbc -NewCollection

	# add documents (9,1), (8,0), (7,1), .. (0,0)
	9..0 | .{process{ @{Value1 = $_; Value2 = $_ % 2} }} | Add-MdbcData

	# sort by Value1
	$data = Get-MdbcData -Sort '{Value1 : 1}' -First 1
	equals $data.Value1 0

	# sort by two values, ascending by default
	$data = Get-MdbcData -Sort '{Value2 : 1, Value1 : 1}'
	equals $data[0].Value1 0
	equals $data[1].Value1 2
	equals $data[-2].Value1 7
	equals $data[-1].Value1 9

	# sort by two values, descending explicitly
	$data = Get-MdbcData -Sort '{Value2 : -1, Value1 : -1}'
	equals $data[0].Value1 9
	equals $data[1].Value1 7
	equals $data[-2].Value1 2
	equals $data[-1].Value1 0
}

# Tests Get-MdbcData -Update -Add -New
# https://github.com/mongodb/mongo/blob/master/jstests/core/find_and_modify4.js (path changes!)
task Update {
	### 1
	Connect-Mdbc -NewCollection

	# this is the best way to build auto-increment
	function getNextVal($counterName) {
		(Get-MdbcData @{_id = $counterName} -Update '{$inc : {val : 1}}' -Add -New -As Default).val
	}

	equals 1 (getNextVal a)
	equals 2 (getNextVal a)
	equals 3 (getNextVal a)
	equals 1 (getNextVal z)
	equals 2 (getNextVal z)
	equals 4 (getNextVal a)

	### 2
	Connect-Mdbc -NewCollection

	function helper($upsert) {
		Get-MdbcData @{_id = 'asdf'} -Update '{$inc : {val : 1}}' -Add:$upsert
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
	$out = Get-MdbcData @{a = 1} -Update @{b = 2} -Add -New
	equals ($out._id.GetType()) ([MongoDB.Bson.ObjectId])
	assert (!$out.Contains('a')) # Mdbc.v5 was a=1
	equals $out.b 2
}

# -Skip, -First, -Last
task Limits {
	Connect-Mdbc -NewCollection

	1..5 | .{process{@{_id=$_}}} | Add-MdbcData
	equals (Get-MdbcData -Count -First 3) 3L
	equals (Get-MdbcData -Count -Skip 3) 2L

	$r = @(Get-MdbcData -First 2 -Skip 1 '{_id : {$gte : 2}}')
	equals $r.Count 2
	equals $r[0]._id 3

	$r = @(Get-MdbcData -Last 2 -Skip 1 '{_id : {$lte : 4}}')
	equals $r.Count 2
	equals $r[1]._id 3

	Test-Error { Get-MdbcData -First 1 -Last 1 } '*Parameters First and Last cannot be specified together.'
}

# -Update, -Add, -New
task Upsert {
	$query = '{_id : "miss"}'
	$update = '{$set : {x : 42}}'

	# -Update
	Connect-Mdbc -NewCollection
	$r = Get-MdbcData $query -Update $update
	assert (!$r)
	equals (Get-MdbcData -Count) 0L

	# -Update -Add
	Connect-Mdbc -NewCollection
	$r = Get-MdbcData $query -Update $update -Add
	assert (!$r)
	$r = Get-MdbcData
	equals $r.x 42
	equals $r._id 'miss'

	# -Update -Add -New
	Connect-Mdbc -NewCollection
	$r = Get-MdbcData $query -Update $update -Add -New
	equals $r.x 42
	equals $r._id 'miss'
	$r = Get-MdbcData
	equals $r.x 42
	equals $r._id 'miss'
}

# used to test -ResultVariable, retired
task UpdateResult {
	$query = '{_id : 1}'
	$update = '{$set : {x : 42}}'

	# update missing
	Connect-Mdbc -NewCollection
	$d = Get-MdbcData $query -Update $update
	assert (!$d)
	equals (Get-MdbcData -Count) 0L

	# update existing, get old
	Connect-Mdbc -NewCollection
	@{_id = 1; x = 1} | Add-MdbcData
	$d = Get-MdbcData $query -Update $update
	Test-Table $d @{_id = 1; x = 1}
	$d = Get-MdbcData
	Test-Table $d @{_id = 1; x = 42}

	# update existing, get new
	Connect-Mdbc -NewCollection
	@{_id = 1; x = 1} | Add-MdbcData
	$d = Get-MdbcData $query -Update $update -New
	Test-Table $d @{_id = 1; x = 42}
	$d = Get-MdbcData
	Test-Table $d @{_id = 1; x = 42}

	# upsert missing, get old
	Connect-Mdbc -NewCollection
	$d = Get-MdbcData $query -Update $update -Add
	assert (!$d)
	$d = Get-MdbcData
	Test-Table $d @{_id = 1; x = 42}

	# upsert missing, get new
	Connect-Mdbc -NewCollection
	$d = Get-MdbcData $query -Update $update -Add -New
	Test-Table $d @{_id = 1; x = 42}
	$d = Get-MdbcData
	Test-Table $d @{_id = 1; x = 42}
}

task IncludeFields {
	Connect-Mdbc -NewCollection
	@{_id=1; p1=1; p2=2} | Add-MdbcData

	$r = Get-MdbcData -Project '{p2 : 1, p3 : 1}'
	equals $r.Count 2
	equals $r._id 1
	equals $r.p2 2
}

task ExcludeFields {
	Connect-Mdbc -NewCollection
	@{_id=1; p1=1; p2=2} | Add-MdbcData

	$r = Get-MdbcData -Project '{p1 : 0, p3 : 0}'
	equals $r.Count 2
	equals $r._id 1
	equals $r.p2 2
}

# Synopsis: Fixed #3.
task SortByMissing {
	Connect-Mdbc -NewCollection
	@{_id=1; p1=1; p2=2},
	@{_id=2; p1=0; p2=2} | Add-MdbcData

	$r = Get-MdbcData -Sort '{p1 : 1, p3 : 1}'
	equals $r.Count 2
	equals $r[0]._id 2
	equals $r[1]._id 1
}

### Get-MdbcData -Update -Add -New
task GetUpdateAddNew {
	Connect-Mdbc -NewCollection

	$r = Get-MdbcData @{_id = 76} -Update @{'$set' = @{p1 = 1}} -Add
	equals $r
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 76, "p1" : 1 }'

	$r = Get-MdbcData @{_id = 76} -Update @{'$set' = @{p1 = 2}} -Add
	equals $r.p1 1 # old returned
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 76, "p1" : 2 }'

	$r = Get-MdbcData @{_id = 76} -Update @{'$set' = @{p1 = 3}} -Add -New
	equals $r.p1 3 # new returned
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 76, "p1" : 3 }'
}

#! can use -Project * and -As type-name
task ProjectStar {
	Connect-Mdbc -NewCollection
	@{_id = 0; p1 = 1; p2 = 2; p3 = 3} | Add-MdbcData

	# * is fine with no -As
	$r = Get-MdbcData -Project *
	equals $r.Count 4

	# id stands for _id automatically
	class T1 {$id; $p2}
	$r = Get-MdbcData -As T1 -Project *
	equals '{"id":0,"p2":2}' ($r | ConvertTo-Json -Compress)

	# id may be missing
	class T2 {$p2; $p3}
	$r = Get-MdbcData -As T2 -Project *
	equals '{"p2":2,"p3":3}' ($r | ConvertTo-Json -Compress)

	#! serialized type
	class T3 {$Name; $p3}
	Register-MdbcClassMap T3 -IdProperty Name
	$r = Get-MdbcData -As T3 -Project *
	equals '{"Name":0,"p3":3}' ($r | ConvertTo-Json -Compress)
}
