
Import-Module Mdbc

# Example 1 on p. 87 of MongoDB: The Definitive Guide by Kristina Chodorow and Michael Dirolf
task Invoke-MdbcMapReduce {
	Connect-Mdbc -NewCollection

	@{ A = 1; B = 2; }, @{ B = 1; C = 2 }, @{ X = 1; B = 2 } | Add-MdbcData

	# NB: `this` is all we need
	$map = @'
function() {
	for (var key in this) {
		emit(key, {count : 1})
	}
}
'@

	# NB: http://stackoverflow.com/a/65028/323582
	$reduce = @'
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
	$data = Invoke-MdbcMapReduce $map, $reduce -ResultVariable result

	equals $data.Count 5
	equals $data[1]._id 'B'
	equals $data[1].value.count 3.0

	equals $result.EmitCount 9L
	equals $result.InputCount 3L
	equals $result.OutputCount 5L

	### inline with query
	<#
_id value
--- -----
A   @{count=1}
B   @{count=1}
_id @{count=1}
#>

	# -SortBy and -First, just for testing
	$null = $Collection.CreateIndex('A') #! https://jira.mongodb.org/browse/CSHARP-472
	$data = Invoke-MdbcMapReduce $map, $reduce (New-MdbcQuery A -Exists) -SortBy A -First 10
	equals $data.Count 3

	### collection output, Replace

	$mz = $Database.GetCollection('z')
	$null = $mz.Drop()

	# add a dummy; it should be removed by MR
	@{_id = 'dummy'} | Add-MdbcData -Collection $mz
	equals $mz.Count() 1L

	# do replace
	$data = Invoke-MdbcMapReduce $map, $reduce -OutCollection z

	# 5, i.e. the dummy was removed
	equals $data
	equals $mz.Count() 5L

	# check the value
	$data = Get-MdbcData -Collection $mz B
	equals $data.value.count 3.0

	### collection output, Reduce

	# do reduce
	$data = Invoke-MdbcMapReduce $map, $reduce -OutCollection z -OutDatabase test -OutMode Reduce

	# still 5
	equals $data
	equals $mz.Count() 5L

	# the value is doubled
	$data = Get-MdbcData -Collection $mz B
	equals $data.value.count 6.0

	### collection output, Merge

	# add a dummy; it should survive
	@{_id = 'dummy'} | Add-MdbcData -Collection $mz
	equals $mz.Count() 6L

	# do merge
	$data = Invoke-MdbcMapReduce $map, $reduce -OutCollection z -OutDatabase test -OutMode Merge

	# 6, i.e. the dummy survived
	equals $data
	equals $mz.Count() 6L

	# the value is replaced
	$data = Get-MdbcData -Collection $mz B
	equals $data.value.count 3.0

	# end
	$null = $mz.Drop()
	$Database.DropCollection('z')
}
