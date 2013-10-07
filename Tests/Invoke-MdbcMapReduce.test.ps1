
Import-Module Mdbc

# Example 1 on p. 87 of MongoDB: The Definitive Guide by Kristina Chodorow and Michael Dirolf
task Invoke-MdbcMapReduce {
	Connect-Mdbc . test test -NewCollection

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

	assert ($data.Count -eq 5)
	assert ($data[1]._id -eq 'B')
	assert ($data[1].value.count -eq 3)

	assert ($result.EmitCount -eq 9)
	assert ($result.InputCount -eq 3)
	assert ($result.OutputCount -eq 5)

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
	$data = Invoke-MdbcMapReduce $map, $reduce (New-MdbcQuery A -Exists 1) -SortBy A -First 10
	assert ($data.Count -eq 3)

	### collection output, Replace

	$mz = $Database.GetCollection('z')
	$null = $mz.Drop()

	# add a dummy; it should be removed by MR
	@{_id = 'dummy'} | Add-MdbcData -Collection $mz
	assert ($mz.Count() -eq 1)

	# do replace
	$data = Invoke-MdbcMapReduce $map, $reduce -OutCollection z

	# 5, i.e. the dummy was removed
	assert ($null -eq $data)
	assert ($mz.Count() -eq 5)

	# check the value
	$data = Get-MdbcData -Collection $mz B
	assert ($data.value.count -eq 3)

	### collection output, Reduce

	# do reduce
	$data = Invoke-MdbcMapReduce $map, $reduce -OutCollection z -OutDatabase test -OutMode Reduce

	# still 5
	assert ($null -eq $data)
	assert ($mz.Count() -eq 5)

	# the value is doubled
	$data = Get-MdbcData -Collection $mz B
	assert ($data.value.count -eq 6)

	### collection output, Merge

	# add a dummy; it should survive
	@{_id = 'dummy'} | Add-MdbcData -Collection $mz
	assert ($mz.Count() -eq 6)

	# do merge
	$data = Invoke-MdbcMapReduce $map, $reduce -OutCollection z -OutDatabase test -OutMode Merge

	# 6, i.e. the dummy survived
	assert ($null -eq $data)
	assert ($mz.Count() -eq 6)

	# the value is replaced
	$data = Get-MdbcData -Collection $mz B
	assert ($data.value.count -eq 3)

	# end
	$null = $mz.Drop()
}
