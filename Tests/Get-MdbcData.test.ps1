
<#
.Synopsis
	Tests MongoCursor Get-MdbcData -Cursor.
#>

Import-Module Mdbc

function Enter-BuildTask {
	Connect-Mdbc . test test -NewCollection
}

task Get-MdbcData.-As {
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

	# add data with custom _id
	1..5 | %{@{_id = $_; data = $_ % 2; time = Get-Date}} | Add-MdbcData

	# get full data
	Get-MdbcData -As ([TestGetMdbcDataAs1]) -First 1

	# get subset of fields
	Get-MdbcData -Property data -As ([TestGetMdbcDataAs2]) -First 1

	$null = $Collection.Drop()

	# add data with default _id
	1..5 | %{@{data = $_}} | Add-MdbcData

	# get data, the extra field `time` is not an issue
	Get-MdbcData -As ([TestGetMdbcDataAs3]) -First 1

	# get strongly typed data using a cursor
	Get-MdbcData -As ([TestGetMdbcDataAs3]) -Cursor -Skip 3
}

task Get-MdbcData.-Cursor {
	# add 11 documents
	20..1 | %{@{Value = $_}} | Add-MdbcData

	# get 5 skipping 5
	$cursor = Get-MdbcData -Cursor -First 5 -Skip 5
	assert ($cursor.Count() -eq 20)
	assert ($cursor.Size() -eq 5)

	# get raw data as an array; NB: raw BsonDocument and BsonValue are not so friendly
	$set = @($cursor)
	assert ($set[0]['Value'].AsInt32 -eq 15)
	assert ($set[-1]['Value'].AsInt32 -eq 11)

	# get data again, converted to Mdbc.Dictionary; NB: these data are more friendly
	$set = $cursor | New-MdbcData
	assert ($set[0].Value -eq 15)
	assert ($set[-1].Value -eq 11)

	# get and test ordered data
	# Set* methods returns the cursor, both handy and gotcha
	$cursor = Get-MdbcData -Cursor -First 5 -Skip 5
	$set = $cursor.SetSortOrder('Value') | New-MdbcData
	assert ($set[0].Value -eq 6)
	assert ($set[-1].Value -eq 10)
}

task Get-MdbcData.-Remove {
	# add documents
	1..9 | %{@{Value1 = $_; Value2 = $_ % 2}} | Add-MdbcData

	# get and remove the first even > 2, it is 4
	$data = Get-MdbcData (New-MdbcQuery Value1 -GT 2) -SortBy Value2, Value1 -Remove
	assert ($data.Value1 -eq 4)

	# do again, it is 6
	$data = Get-MdbcData (New-MdbcQuery Value1 -GT 2) -SortBy Value2, Value1 -Remove
	assert ($data.Value1 -eq 6)

	# try missing
	$data = Get-MdbcData (New-MdbcQuery Value1 -LT 0) -SortBy Value2, Value1 -Remove
	assert ($null -eq $data)

	# count: 9 - 2
	assert (7 -eq (Get-MdbcData -Count))

	# null SortBy
	$data = Get-MdbcData (New-MdbcQuery Value1 -GT 2) -Remove
	assert ($data.Value1 -eq 3)
	assert (6 -eq (Get-MdbcData -Count))

	# null Query
	$data = Get-MdbcData -SortBy Value2, Value1 -Remove
	assert ($data.Value1 -eq 2)
	assert (5 -eq (Get-MdbcData -Count))
}

task Get-MdbcData.-SortBy {
	# add documents (9,1), (8,0), (7,1), .. (0,0)
	9..0 | %{@{Value1 = $_; Value2 = $_ % 2}} | Add-MdbcData

	# sort by Value1
	$data = Get-MdbcData -SortBy Value1 -First 1
	assert ($data.Value1 -eq 0)

	# sort by two values, ascending by default
	$data = Get-MdbcData -SortBy Value2, Value1
	assert ($data[0].Value1 -eq 0)
	assert ($data[1].Value1 -eq 2)
	assert ($data[-2].Value1 -eq 7)
	assert ($data[-1].Value1 -eq 9)

	# sort by two values, descending explicitly
	$data = Get-MdbcData -SortBy @{Value2=0}, @{Value1=0}
	assert ($data[0].Value1 -eq 9)
	assert ($data[1].Value1 -eq 7)
	assert ($data[-2].Value1 -eq 2)
	assert ($data[-1].Value1 -eq 0)
}

# Tests Get-MdbcData -Update -Add -New
# https://github.com/mongodb/mongo/blob/master/jstests/find_and_modify4.js
task Get-MdbcData.-Update {
	# this is the best way to build auto-increment
	function getNextVal($counterName) {
		(Get-MdbcData (New-MdbcQuery _id $counterName) -Update (New-MdbcUpdate val -Increment 1) -Add -New).val
	}

	assert (1 -eq (getNextVal a))
	assert (2 -eq (getNextVal a))
	assert (3 -eq (getNextVal a))
	assert (1 -eq (getNextVal z))
	assert (2 -eq (getNextVal z))
	assert (4 -eq (getNextVal a))
	$null = $Collection.Drop()

	function helper($upsert) {
		Get-MdbcData (New-MdbcQuery _id asdf) -Update (New-MdbcUpdate val -Increment 1) -Add:$upsert
	}

	# upsert:false so nothing there before and after
	assert ($null -eq (helper $false))
	assert (0 -eq $Collection.Count())

	# upsert:true so nothing there before; something there after
	assert ($null -eq (helper $true))
	assert (1 -eq $Collection.Count())

	$data = helper $true
	assert ($data._id -eq 'asdf' -and $data.val -eq 1)

	# upsert only matters when obj doesn't exist
	$data = helper $false
	assert ($data._id -eq 'asdf' -and $data.val -eq 2)

	$data = helper $true
	assert ($data._id -eq 'asdf' -and $data.val -eq 3)

	# _id created if not specified
	$out = Get-MdbcData (New-MdbcQuery a 1) -Update (New-MdbcUpdate b -Set 2) -Add -New
	assert ($null -ne $out._id)
	assert (1 -eq $out.a)
	assert (2 -eq $out.b)
}
