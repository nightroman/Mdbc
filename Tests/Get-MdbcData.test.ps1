
. .\Zoo.ps1
Import-Module Mdbc

task Bad {
	Test-Error { Get-MdbcData -Update bad } '*Exception setting "Update": "Invalid update object type:*'
}

task Get-MdbcData.-As {
	$db = $true
	Invoke-Test {
		. $$
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

		. $$

		# add data with default _id
		1..5 | %{@{data = $_}} | Add-MdbcData

		# get data, the extra field `time` is not an issue
		Get-MdbcData -As ([TestGetMdbcDataAs3]) -First 1

		if ($db) {
			# get strongly typed data using a cursor
			Get-MdbcData -As ([TestGetMdbcDataAs3]) -Cursor -Skip 3
		}
	}{
		$$ = {Connect-Mdbc -NewCollection}
	}{
		$$ = {Open-MdbcFile}
		$db = $false
	}
}

task Get-MdbcData.-Cursor {
	Connect-Mdbc -NewCollection

	# add 11 documents
	20..1 | %{@{Value = $_}} | Add-MdbcData

	# get 5 skipping 5
	$cursor = Get-MdbcData -Cursor -First 5 -Skip 5
	assert ($cursor.Count() -eq 20)
	assert ($cursor.Size() -eq 5)

	# get data as array
	$set = @($cursor)
	assert ($set[0].Value -eq 15)
	assert ($set[-1].Value -eq 11)

	# get and test ordered data
	# Set* methods returns the cursor, both handy and gotcha
	$cursor = Get-MdbcData -Cursor -First 5 -Skip 5
	$set = @($cursor.SetSortOrder('Value'))
	assert ($set[0].Value -eq 6)
	assert ($set[-1].Value -eq 10)
}

task Get-MdbcData.-Remove {
	Invoke-Test {
		# add documents
		1..9 | %{@{Value1 = $_; Value2 = $_ % 2}} | Add-MdbcData

		# get and remove the first even > 2, it is 4
		$data = Get-MdbcData (New-MdbcQuery Value1 -GT 2) -SortBy Value2, Value1 -Remove -As Default
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
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Get-MdbcData.-SortBy {
	Invoke-Test {
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
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

# Tests Get-MdbcData -Update -Add -New
# https://github.com/mongodb/mongo/blob/master/jstests/find_and_modify4.js
task Get-MdbcData.-Update {
	Invoke-Test {
		. $$

		# this is the best way to build auto-increment
		function getNextVal($counterName) {
			(Get-MdbcData (New-MdbcQuery _id $counterName) -Update (New-MdbcUpdate -Inc @{val = 1}) -Add -New -As Default).val
		}

		assert (1 -eq (getNextVal a))
		assert (2 -eq (getNextVal a))
		assert (3 -eq (getNextVal a))
		assert (1 -eq (getNextVal z))
		assert (2 -eq (getNextVal z))
		assert (4 -eq (getNextVal a))

		. $$

		function helper($upsert) {
			Get-MdbcData (New-MdbcQuery _id asdf) -Update (New-MdbcUpdate -Inc @{val = 1}) -Add:$upsert
		}

		# upsert:false so nothing there before and after
		assert ($null -eq (helper $false))
		assert (0 -eq (Get-MdbcData -Count))

		# upsert:true so nothing there before; something there after
		assert ($null -eq (helper $true))
		assert (1 -eq (Get-MdbcData -Count))

		$data = helper $true
		assert ($data._id -eq 'asdf' -and $data.val -eq 1) #_131103_185751

		# upsert only matters when obj doesn't exist
		$data = helper $false
		assert ($data._id -eq 'asdf' -and $data.val -eq 2)

		$data = helper $true
		assert ($data._id -eq 'asdf' -and $data.val -eq 3)

		# _id created if not specified
		$out = Get-MdbcData (New-MdbcQuery a 1) -Update (New-MdbcUpdate @{b = 2}) -Add -New
		assert ($null -ne $out._id)
		assert (1 -eq $out.a)
		assert (2 -eq $out.b)
	}{
		$$ = {Connect-Mdbc -NewCollection}
	}{
		$$ = {Open-MdbcFile}
	}
}

# -Skip, -First, -Last
task Limits {
	Invoke-Test {
		1..5 | Add-MdbcData -Id {$_}
		assert ((Get-MdbcData -Count -First 3) -eq 3)
		assert ((Get-MdbcData -Count -Last 3) -eq 3)
		assert ((Get-MdbcData -Count -Skip 3) -eq 2)

		$r = @(Get-MdbcData -First 2 -Skip 1 (New-MdbcQuery _id -GTE 2))
		assert ($r.Count -eq 2) $r.Count
		assert ($r[0]._id -eq 3)

		$r = @(Get-MdbcData -Last 2 -Skip 1 (New-MdbcQuery _id -LTE 4))
		assert ($r.Count -eq 2)
		assert ($r[1]._id -eq 3)

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
		assert ((Get-MdbcData -Count) -eq 0)

		# -Update -Add
		. $$
		$r = Get-MdbcData $query -Update $update -Add
		assert (!$r)
		$r = Get-MdbcData
		assert ($r.x = 42)
		assert ($r._id = 'miss')

		# -Update -Add -New
		. $$
		$r = Get-MdbcData $query -Update $update -Add -New
		assert ($r.x = 42)
		assert ($r._id = 'miss')
		$r = Get-MdbcData
		assert ($r.x = 42)
		assert ($r._id = 'miss')
	}{
		$$ = { Connect-Mdbc -NewCollection }
	}{
		$$ = { Open-MdbcFile }
	}
}
