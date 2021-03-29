<#
.Synopsis
	Examples of MapReduce.

.Description
	Mdbc does not expose IMongoCollection.MapReduce.
	But MapReduce can be done by Invoke-MdbcCommand.

.Link
	https://docs.mongodb.com/manual/reference/command/mapReduce/
#>

Import-Module Mdbc

task GetAllFieldNames {
	Connect-Mdbc -NewCollection
	@{d=1}, @{a=1; b=1}, @{b=1; c=1} | Add-MdbcData

	$r = Invoke-MdbcCommand -As PS ([ordered]@{
		mapreduce = 'test'
		map = 'function() { for (var key in this) { emit(key, null); } }'
		reduce = 'function(key, stuff) { return null; }'
		out = @{inline = 1}
	})
	$names = $r.results | .{process{ $_._id }} | Sort-Object
	equals "$names" '_id a b c d'
}

# Example 1 on p. 87 of MongoDB: The Definitive Guide by Kristina Chodorow and Michael Dirolf
task ExampleFromTheBook {
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

	# get inline output
	$r = Invoke-MdbcCommand ([ordered]@{
		mapreduce = 'test'
		map = $map
		reduce = $reduce
		out = @{ inline = 1 }
	})
	$data = $r.results | Sort-Object {$_._id}, {$_.value.count}
	$data.Print()

	equals $data.Count 5
	equals $data[2]._id 'B'
	equals $data[2].value.count 3.0

	### collection output, Replace

	$mz = Get-MdbcCollection z -NewCollection

	# add a dummy; it should be removed by MR
	@{_id = 'dummy'} | Add-MdbcData -Collection $mz
	equals "$(Get-MdbcData -Collection $mz)" '{ "_id" : "dummy" }'

	# do replace
	$r = Invoke-MdbcCommand ([ordered]@{
		mapreduce = 'test'
		map = $map
		reduce = $reduce
		out = 'z'
	})
	"$r"

	# 5, i.e. the dummy was removed
	equals 5L (Get-MdbcData -Count -Collection $mz)

	# check the value
	$data = Get-MdbcData @{_id = 'B'} -Collection $mz
	equals $data.value.count 3.0

	### collection output, Reduce

	# do reduce
	$r = Invoke-MdbcCommand ([ordered]@{
		mapreduce = 'test'
		map = $map
		reduce = $reduce
		out = @{ reduce = 'z' }
	})
	"$r"

	# still 5
	equals 5L (Get-MdbcData -Count -Collection $mz)

	# the value is doubled
	$data = Get-MdbcData @{_id = 'B'} -Collection $mz
	equals $data.value.count 6.0

	### collection output, Merge

	# add a dummy; it should survive
	@{_id = 'dummy'} | Add-MdbcData -Collection $mz

	# do merge
	$r = Invoke-MdbcCommand ([ordered]@{
		mapreduce = 'test'
		map = $map
		reduce = $reduce
		out = @{ merge = 'z' }
	})
	"$r"

	# 6, i.e. the dummy survived
	equals 6L (Get-MdbcData -Count -Collection $mz)

	# the value is replaced
	$data = Get-MdbcData @{_id = 'B'} -Collection $mz
	equals $data.value.count 3.0

	# end
	Remove-MdbcCollection z
}
