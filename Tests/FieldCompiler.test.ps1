
<#
Include   - includes defined and _id unless Exclude(_id) is used
Exclude   - excludes defined, only Exclude(_id) can be used with Include
Slice     - alone just slices and does not exclude others _131103_164212
ElemMatch - alone excludes others but _id but with Exclude does not _131103_164801
#>

. .\Zoo.ps1
Import-Module Mdbc

$data = @{ _id=1; a=1; b=1; arr=1..5; doc=1, @{x=1}, @{x=1} }
$qOK = [MongoDB.Driver.QueryDocument]@{x=1}
$qKO = [MongoDB.Driver.QueryDocument]@{x=2}
$fb = [MongoDB.Driver.Builders.Fields]

function get($Property) {
	try {Get-MdbcData -Property $Property}
	catch {Write-Error $_}
}

task Error {
	Invoke-Test {
		Test-Error { get a, a } '*Duplicate element name*'
		Test-Error { get $fb::Include('a').Exclude('b') } '*Projection cannot have a mix of inclusion and exclusion.*'
		Test-Error { get $fb::Slice('arr', 0, 0) } '*$slice limit must be positive*'
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Slice {
	Invoke-Test {
		$data | Add-MdbcData

		# 0 -> empty
		$r = get $fb::Slice('arr', 0)
		equals $r.arr.Count 0

		# <0 -> N-n n
		$r = get $fb::Slice('arr', -2)
		equals $r.arr.Count 2
		equals $r.arr[0] 4

		# >N -> array
		$r = get $fb::Slice('arr', 9)
		equals $r.arr.Count 5

		# 0 >N -> array
		$r = get $fb::Slice('arr', 0, 9)
		equals $r.arr.Count 5

		# >N n -> empty
		$r = get $fb::Slice('arr', 9, 9)
		equals $r.arr.Count 0

		# <0 n -> N-s n
		$r = get $fb::Slice('arr', -3, 2)
		equals $r.arr.Count 2
		equals $r.arr[0] 3

		# <<<0 n -> 0 n
		$r = get $fb::Slice('arr', -7, 2)
		equals $r.arr.Count 2
		equals $r.arr[0] 1

	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}

task Assorted {
	Invoke-Test {
		$data | Add-MdbcData

		# + _id
		$r = get _id #!
		Test-List @('_id') $r.Keys

		# + a + b
		$r = get a, b
		Test-List @('_id', 'a', 'b') ($r.Keys | Sort-Object)

		# - a -> all but a
		$r = get $fb::Exclude('a')
		equals $r.Count ($data.Count - 1)
		assert (!$r['a'])

		# + a - _id -> just a
		$r = get $fb::Include('a').Exclude('_id')
		equals $r.Count 1
		equals $r.a 1

		# slice -> all
		$r = get $fb::Slice('arr', 2)
		equals $r.Count $data.Count #_131103_164212
		equals $r.arr.Count 2
		equals $r.arr[0] 1

		# match -> _id @(@{})
		$r = get $fb::ElemMatch('doc', $qOK)
		Test-Table -Force @{_id=1; doc=@(@{x=1})} $r #_131103_164801

		# mismatch array -> _id
		$r = get $fb::ElemMatch('doc', $qKO)
		equals $r.Count 1
		assert $r._id

		# + a slice array -> a array
		$r = get $fb::Include('a').Slice('arr', 2)
		equals $r.arr.Count 2
		equals $r.a 1
		equals $r.arr[0] 1

		# - a slice array -> all but a
		$r = get $fb::Exclude('a').Slice('arr', 2)
		equals $r.Count ($data.Count - 1)
		assert (!$r['a'])
		equals $r.arr.Count 2
		equals $r.arr[0] 1

		# - _id + a slice array -> a array
		$r = get $fb::Exclude('_id').Include('a').Slice('arr', 2)
		equals $r.arr.Count 2
		equals $r.a 1
		equals $r.arr[0] 1

		# + _id slice
		$r = get $fb::Include('_id').Slice('arr', 1, 2)
		equals $r.Count 2
		equals $r.arr.Count 2
		equals $r.arr[0] 2

		### Slice and ElemMatch with Exclude

		$r = Get-MdbcData -Property $fb::Slice('arr', 2).Exclude('b')
		equals $r.Count ($data.Count - 1)

		$r = Get-MdbcData -Property $fb::ElemMatch('doc', $qOK).Exclude('b')
		equals $r.Count ($data.Count - 1) #_131103_164801

		$r = Get-MdbcData -Property $fb::Slice('arr', 2).ElemMatch('doc', $qOK).Exclude('b')
		equals $r.Count ($data.Count - 1)

		### Slice and ElemMatch with Include

		$r = Get-MdbcData -Property $fb::Slice('arr', 2).Include('b')
		equals $r.Count 3

		$r = Get-MdbcData -Property $fb::ElemMatch('doc', $qOK).Include('b')
		equals $r.Count 3

		$r = Get-MdbcData -Property $fb::Slice('arr', 2).ElemMatch('doc', $qOK).Include('b')
		equals $r.Count 4

		### Slice and ElemMatch alone on non arrays

		# -> all included, even b
		$r = Get-MdbcData -Property $fb::Slice('b', 2)
		equals $r.Count $data.Count
		equals $r.b 1

		# -> just _id, b excluded
		$r = Get-MdbcData -Property $fb::ElemMatch('b', $qOK)
		equals $r.Count 1
		assert $r._id

		### Slice and ElemMatch with Exclude on non arrays

		$r = Get-MdbcData -Property $fb::Slice('b', 2).Exclude('a')
		equals $r.Count ($data.Count - 1)
		equals $r.b 1

		$r = Get-MdbcData -Property $fb::ElemMatch('b', $qOK).Exclude('a')
		equals $r.Count ($data.Count - 2)
		assert (!$r['b']) #_131103_173143

		### -Update, FindAndModify
		# All is the same with fields, just test different code for FindAndModify

		$r = Get-MdbcData -Update (New-MdbcUpdate -Unset miss) -Property a, _id # _id is second
		Test-List $r.Keys '_id', 'a' # _id is first anyway

		$r = Get-MdbcData -Update (New-MdbcUpdate -Unset miss) -Property $fb::Include('_id').Slice('arr', 1, 2)
		equals $r.Count 2
		equals $r.arr.Count 2
		equals $r.arr[0] 2
	}{
		Connect-Mdbc -NewCollection
	}{
		Open-MdbcFile
	}
}
