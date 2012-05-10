
Import-Module Mdbc
$mtest = Connect-Mdbc . test test -NewCollection

# Example 1 on p. 87 of MongoDB: The Definitive Guide by Kristina Chodorow and Michael Dirolf
@{ A = 1; B = 2; }, @{ B = 1; C = 2 }, @{ X = 1; B = 2 } | Add-MdbcData $mtest

# NB: `function` looks optional and `this` is all we need
$map = <#js#>@'
//function() {
	for (var key in this) {
		emit(key, {count : 1})
	}
//}
'@

# NB: http://stackoverflow.com/a/65028/323582
$reduce = <#js#>@'
function(key, emits) {
	total = 0
	for (var i in emits) {
		total += emits[i].count
	}
	return {count : total}
}
'@

### inline output
<#
_id value
--- -----
A   @{count=1}
B   @{count=3}
C   @{count=1}
X   @{count=1}
_id @{count=3}
#>

# get inline output and other results as $result
$data = Invoke-MdbcMapReduce $mtest $map, $reduce -Result result

if ($data.Count -ne 5) {throw}
if ($data[1]._id -ne 'B') {throw}
if ($data[1].value.count -ne 3) {throw}

if ($result.EmitCount -ne 9) {throw}
if ($result.InputCount -ne 3) {throw}
if ($result.OutputCount -ne 5) {throw}

### inline with query
<#
_id value
--- -----
A   @{count=1}
B   @{count=1}
_id @{count=1}
#>

# -SortBy and -First, just for testing
$null = $mtest.CreateIndex('A') #! https://jira.mongodb.org/browse/CSHARP-472
$data = Invoke-MdbcMapReduce $mtest $map, $reduce (New-MdbcQuery A -Exists 1) -SortBy A -First 10
if ($data.Count -ne 3) {throw}

### collection output, Replace

$mz = $mtest.Database['z']
$null = $mz.Drop()

# add a dummy; it should be removed by MR
@{_id = 'dummy'} | Add-MdbcData $mz
if ($mz.Count() -ne 1) {throw}

# do replace
$data = Invoke-MdbcMapReduce $mtest $map, $reduce -OutCollection z

# 5, i.e. the dummy was removed
if ($null -ne $data) {throw}
if ($mz.Count() -ne 5) {throw}

# check the value
$data = Get-MdbcData $mz B
if ($data.value.count -ne 3) {throw}

### collection output, Reduce

# do reduce
$data = Invoke-MdbcMapReduce $mtest $map, $reduce -OutCollection z -OutDatabase test -OutMode Reduce

# still 5
if ($null -ne $data) {throw}
if ($mz.Count() -ne 5) {throw}

# the value is doubled
$data = Get-MdbcData $mz B
if ($data.value.count -ne 6) {throw}

### collection output, Merge

# add a dummy; it should survive
@{_id = 'dummy'} | Add-MdbcData $mz
if ($mz.Count() -ne 6) {throw}

# do merge
$data = Invoke-MdbcMapReduce $mtest $map, $reduce -OutCollection z -OutDatabase test -OutMode Merge

# 6, i.e. the dummy survived
if ($null -ne $data) {throw}
if ($mz.Count() -ne 6) {throw}

# the value is replaced
$data = Get-MdbcData $mz B
if ($data.value.count -ne 3) {throw}
