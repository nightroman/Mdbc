
. .\Zoo.ps1
Import-Module Mdbc

# Log and test the expression and expected representation
function test($value, $expected) {
	"$value => $expected"
	$actual = (. $value).ToString()
	if ($actual -cne $expected) {
		Write-Error -ErrorAction 1 "`nExpected : $expected`nActual   : $actual"
	}
}

# DateTime value as PSObject for tests
$date = [PSObject][DateTime]'2011-11-11'

# Guid value as PSObject for tests
$guid = [PSObject][Guid]'12345678-1234-1234-1234-123456789012'

# BsonArray value for tests
$bsonArray = [MongoDB.Bson.BsonArray](1, 2, 3)
Test-Type $bsonArray MongoDB.Bson.BsonArray

# MdbcArray value for tests
$mdbcArray = New-MdbcData -Value 1, 2, 3
Test-Type $mdbcArray Mdbc.Collection

task New-MdbcQuery.Expression {
	### [ Comparison ]

	### EQ
	test { New-MdbcQuery Name 42 } '{ "Name" : 42 }'
	test { New-MdbcQuery Name -EQ 42 } '{ "Name" : 42 }'
	test { New-MdbcQuery -Not Name -EQ 42 } '{ "Name" : { "$ne" : 42 } }'

	# EQ is used on its own
	try { New-MdbcQuery Name -EQ 42 -GT 15 }
	catch { $$ = "$_" }
	assert ($$ -eq 'Parameter set cannot be resolved using the specified named parameters.')

	### LE
	test { New-MdbcQuery Name -LE 42 } '{ "Name" : { "$lte" : 42 } }'
	test { New-MdbcQuery -Not Name -LE 42 } '{ "Name" : { "$not" : { "$lte" : 42 } } }'

	### LT
	test { New-MdbcQuery Name -LT 42 } '{ "Name" : { "$lt" : 42 } }'
	test { New-MdbcQuery -Not Name -LT 42 } '{ "Name" : { "$not" : { "$lt" : 42 } } }'

	### GE
	test { New-MdbcQuery Name -GE 42 } '{ "Name" : { "$gte" : 42 } }'
	test { New-MdbcQuery -Not Name -GE 42 } '{ "Name" : { "$not" : { "$gte" : 42 } } }'

	### GT
	test { New-MdbcQuery Name -GT 42 } '{ "Name" : { "$gt" : 42 } }'
	test { New-MdbcQuery -Not Name -GT 42 } '{ "Name" : { "$not" : { "$gt" : 42 } } }'

	### NE
	test { New-MdbcQuery Name -NE 42 } '{ "Name" : { "$ne" : 42 } }'
	test { New-MdbcQuery -Not Name -NE 42 } '{ "Name" : 42 }'

	### [ Ignore Case ]

	### IEQ
	test { New-MdbcQuery Name -IEQ te*xt } '{ "Name" : /^te\*xt$/i }'
	test { New-MdbcQuery -Not Name -IEQ te*xt } '{ "Name" : { "$not" : /^te\*xt$/i } }'

	### INE
	test { New-MdbcQuery Name -INE te*xt } '{ "Name" : { "$not" : /^te\*xt$/i } }'
	test { New-MdbcQuery -Not Name -INE te*xt } '{ "Name" : /^te\*xt$/i }'

	### [ Misc ]

	### Exists

	test { New-MdbcQuery Name -Exists $true } '{ "Name" : { "$exists" : true } }'
	test { New-MdbcQuery -Not Name -Exists $true } '{ "Name" : { "$exists" : false } }'

	test { New-MdbcQuery Name -Exists $false } '{ "Name" : { "$exists" : false } }'
	test { New-MdbcQuery -Not Name -Exists $false } '{ "Name" : { "$exists" : true } }'

	### Mod
	test { New-MdbcQuery Name -Mod 2, 1 } '{ "Name" : { "$mod" : [2, 1] } }'
	test { New-MdbcQuery -Not Name -Mod 2, 1 } '{ "Name" : { "$not" : { "$mod" : [2, 1] } } }'

	### Size
	test { New-MdbcQuery Name -Size 42 } '{ "Name" : { "$size" : 42 } }'
	test { New-MdbcQuery -Not Name -Size 42 } '{ "Name" : { "$not" : { "$size" : 42 } } }'

	### Type

	test { New-MdbcQuery Name -Type 1 } '{ "Name" : { "$type" : 1 } }'
	test { New-MdbcQuery Name -Type Double } '{ "Name" : { "$type" : 1 } }'
	test { New-MdbcQuery -Not Name -Type Double } '{ "Name" : { "$not" : { "$type" : 1 } } }'

	### Where
	test { New-MdbcQuery -Where 'this.Length == null' } '{ "$where" : { "$code" : "this.Length == null" } }'
	test { New-MdbcQuery -Not -Where 'this.Length == null' } '{ "$where" : { "$ne" : { "$code" : "this.Length == null" } } }' #todo why $ne?

	### Match

	test { New-MdbcQuery Name -Match '^text$' } '{ "Name" : /^text$/ }'
	test { New-MdbcQuery -Not Name -Match '^text$'} '{ "Name" : { "$not" : /^text$/ } }'

	test { New-MdbcQuery Name -Match '^text$', 'imxs' } '{ "Name" : /^text$/imxs }'
	test { New-MdbcQuery -Not Name -Match '^text$', 'imxs'} '{ "Name" : { "$not" : /^text$/imxs } }'

	$regex = New-Object regex '^text$', "IgnoreCase, Multiline, IgnorePatternWhitespace, Singleline"
	test { New-MdbcQuery Name -Match $regex } '{ "Name" : /^text$/imxs }'
	test { New-MdbcQuery -Not Name -Match $regex } '{ "Name" : { "$not" : /^text$/imxs } }'

	### Matches
	$query = New-MdbcQuery -And (New-MdbcQuery a 1), (New-MdbcQuery b 2)
	test { New-MdbcQuery Name -Matches $query } '{ "Name" : { "$elemMatch" : { "a" : 1, "b" : 2 } } }'
	test { New-MdbcQuery -Not Name -Matches $query } '{ "Name" : { "$not" : { "$elemMatch" : { "a" : 1, "b" : 2 } } } }'

	### [ Sets ]

	### All
	test { New-MdbcQuery Name -All $bsonArray } '{ "Name" : { "$all" : [1, 2, 3] } }'
	test { New-MdbcQuery Name -All $mdbcArray } '{ "Name" : { "$all" : [1, 2, 3] } }'
	test { New-MdbcQuery Name -All $true } '{ "Name" : { "$all" : [true] } }'
	test { New-MdbcQuery Name -All $date } '{ "Name" : { "$all" : [ISODate("2011-11-11T00:00:00Z")] } }'
	test { New-MdbcQuery Name -All 1.1 } '{ "Name" : { "$all" : [1.1] } }'
	test { New-MdbcQuery Name -All $guid } '{ "Name" : { "$all" : [CSUUID("12345678-1234-1234-1234-123456789012")] } }'
	test { New-MdbcQuery Name -All 1 } '{ "Name" : { "$all" : [1] } }'
	test { New-MdbcQuery Name -All 1L } '{ "Name" : { "$all" : [NumberLong(1)] } }'
	test { New-MdbcQuery Name -All text } '{ "Name" : { "$all" : ["text"] } }'
	test { New-MdbcQuery Name -All $true, more } '{ "Name" : { "$all" : [true, "more"] } }'
	test { New-MdbcQuery Name -All $date, more } '{ "Name" : { "$all" : [ISODate("2011-11-11T00:00:00Z"), "more"] } }'
	test { New-MdbcQuery Name -All 1.1, more } '{ "Name" : { "$all" : [1.1, "more"] } }'
	test { New-MdbcQuery Name -All $guid, more } '{ "Name" : { "$all" : [CSUUID("12345678-1234-1234-1234-123456789012"), "more"] } }'
	test { New-MdbcQuery Name -All 1, more } '{ "Name" : { "$all" : [1, "more"] } }'
	test { New-MdbcQuery Name -All 1L, more } '{ "Name" : { "$all" : [NumberLong(1), "more"] } }'
	test { New-MdbcQuery Name -All text, more } '{ "Name" : { "$all" : ["text", "more"] } }'
	test { New-MdbcQuery -Not Name -All text, more } '{ "Name" : { "$not" : { "$all" : ["text", "more"] } } }'

	### In
	test { New-MdbcQuery Name -In $bsonArray } '{ "Name" : { "$in" : [1, 2, 3] } }'
	test { New-MdbcQuery Name -In $mdbcArray } '{ "Name" : { "$in" : [1, 2, 3] } }'
	test { New-MdbcQuery Name -In $true } '{ "Name" : { "$in" : [true] } }'
	test { New-MdbcQuery Name -In $date } '{ "Name" : { "$in" : [ISODate("2011-11-11T00:00:00Z")] } }'
	test { New-MdbcQuery Name -In 1.1 } '{ "Name" : { "$in" : [1.1] } }'
	test { New-MdbcQuery Name -In $guid } '{ "Name" : { "$in" : [CSUUID("12345678-1234-1234-1234-123456789012")] } }'
	test { New-MdbcQuery Name -In 1 } '{ "Name" : { "$in" : [1] } }'
	test { New-MdbcQuery Name -In 1L } '{ "Name" : { "$in" : [NumberLong(1)] } }'
	test { New-MdbcQuery Name -In text } '{ "Name" : { "$in" : ["text"] } }'
	test { New-MdbcQuery Name -In $true, more } '{ "Name" : { "$in" : [true, "more"] } }'
	test { New-MdbcQuery Name -In $date, more } '{ "Name" : { "$in" : [ISODate("2011-11-11T00:00:00Z"), "more"] } }'
	test { New-MdbcQuery Name -In 1.1, more } '{ "Name" : { "$in" : [1.1, "more"] } }'
	test { New-MdbcQuery Name -In $guid, more } '{ "Name" : { "$in" : [CSUUID("12345678-1234-1234-1234-123456789012"), "more"] } }'
	test { New-MdbcQuery Name -In 1, more } '{ "Name" : { "$in" : [1, "more"] } }'
	test { New-MdbcQuery Name -In 1L, more } '{ "Name" : { "$in" : [NumberLong(1), "more"] } }'
	test { New-MdbcQuery Name -In text, more } '{ "Name" : { "$in" : ["text", "more"] } }'
	test { New-MdbcQuery -Not Name -In text, more } '{ "Name" : { "$nin" : ["text", "more"] } }'

	### NotIn
	test { New-MdbcQuery Name -NotIn $bsonArray } '{ "Name" : { "$nin" : [1, 2, 3] } }'
	test { New-MdbcQuery Name -NotIn $mdbcArray } '{ "Name" : { "$nin" : [1, 2, 3] } }'
	test { New-MdbcQuery Name -NotIn $true } '{ "Name" : { "$nin" : [true] } }'
	test { New-MdbcQuery Name -NotIn $date } '{ "Name" : { "$nin" : [ISODate("2011-11-11T00:00:00Z")] } }'
	test { New-MdbcQuery Name -NotIn 1.1 } '{ "Name" : { "$nin" : [1.1] } }'
	test { New-MdbcQuery Name -NotIn $guid } '{ "Name" : { "$nin" : [CSUUID("12345678-1234-1234-1234-123456789012")] } }'
	test { New-MdbcQuery Name -NotIn 1 } '{ "Name" : { "$nin" : [1] } }'
	test { New-MdbcQuery Name -NotIn 1L } '{ "Name" : { "$nin" : [NumberLong(1)] } }'
	test { New-MdbcQuery Name -NotIn text } '{ "Name" : { "$nin" : ["text"] } }'
	test { New-MdbcQuery Name -NotIn $true, more } '{ "Name" : { "$nin" : [true, "more"] } }'
	test { New-MdbcQuery Name -NotIn $date, more } '{ "Name" : { "$nin" : [ISODate("2011-11-11T00:00:00Z"), "more"] } }'
	test { New-MdbcQuery Name -NotIn 1.1, more } '{ "Name" : { "$nin" : [1.1, "more"] } }'
	test { New-MdbcQuery Name -NotIn $guid, more } '{ "Name" : { "$nin" : [CSUUID("12345678-1234-1234-1234-123456789012"), "more"] } }'
	test { New-MdbcQuery Name -NotIn 1, more } '{ "Name" : { "$nin" : [1, "more"] } }'
	test { New-MdbcQuery Name -NotIn 1L, more } '{ "Name" : { "$nin" : [NumberLong(1), "more"] } }'
	test { New-MdbcQuery Name -NotIn text, more } '{ "Name" : { "$nin" : ["text", "more"] } }'
	test { New-MdbcQuery -Not Name -NotIn text, more } '{ "Name" : { "$not" : { "$nin" : ["text", "more"] } } }'

	### [ Binary Operators ]

	### And
	test { New-MdbcQuery -And (New-MdbcQuery x 1), (New-MdbcQuery y 2) } '{ "x" : 1, "y" : 2 }'
	test { New-MdbcQuery -Not -And (New-MdbcQuery x 1), (New-MdbcQuery y 2) } '{ "$nor" : [{ "x" : 1, "y" : 2 }] }'

	### Or
	test { New-MdbcQuery -Or (New-MdbcQuery x 1), (New-MdbcQuery y 2) } '{ "$or" : [{ "x" : 1 }, { "y" : 2 }] }'
	test { New-MdbcQuery -Not -Or (New-MdbcQuery x 1), (New-MdbcQuery y 2) } '{ "$nor" : [{ "x" : 1 }, { "y" : 2 }] }'
}

task New-MdbcUpdate.Expression {
	### $addToSet

	test { New-MdbcUpdate Name -AddToSet 1 } '{ "$addToSet" : { "Name" : 1 } }'
	test { New-MdbcUpdate Name -AddToSetEach 1 } '{ "$addToSet" : { "Name" : { "$each" : [1] } } }'

	test { New-MdbcUpdate Name -AddToSet 1, 2 } '{ "$addToSet" : { "Name" : [1, 2] } }'
	test { New-MdbcUpdate Name -AddToSetEach 1, 2 } '{ "$addToSet" : { "Name" : { "$each" : [1, 2] } } }'

	test { New-MdbcUpdate Name -AddToSet $mdbcArray } '{ "$addToSet" : { "Name" : [1, 2, 3] } }'
	test { New-MdbcUpdate Name -AddToSetEach $mdbcArray } '{ "$addToSet" : { "Name" : { "$each" : [1, 2, 3] } } }'

	test { New-MdbcUpdate Name -AddToSet $bsonArray } '{ "$addToSet" : { "Name" : [1, 2, 3] } }'
	test { New-MdbcUpdate Name -AddToSetEach $bsonArray } '{ "$addToSet" : { "Name" : { "$each" : [1, 2, 3] } } }'

	### $bit

	test { New-MdbcUpdate Name -Band 1 } '{ "$bit" : { "Name" : { "and" : 1 } } }'
	test { New-MdbcUpdate Name -Band 1L } '{ "$bit" : { "Name" : { "and" : NumberLong(1) } } }'

	test { New-MdbcUpdate Name -Bor 1 } '{ "$bit" : { "Name" : { "or" : 1 } } }'
	test { New-MdbcUpdate Name -Bor 1L } '{ "$bit" : { "Name" : { "or" : NumberLong(1) } } }'

	### $inc
	test { New-MdbcUpdate Name -Increment 1 } '{ "$inc" : { "Name" : 1 } }'
	test { New-MdbcUpdate Name -Increment 1L } '{ "$inc" : { "Name" : NumberLong(1) } }'
	test { New-MdbcUpdate Name -Increment 1.1 } '{ "$inc" : { "Name" : 1.1 } }'

	### $pop

	test { New-MdbcUpdate Name -PopFirst } '{ "$pop" : { "Name" : -1 } }'
	test { New-MdbcUpdate Name -PopLast } '{ "$pop" : { "Name" : 1 } }'

	### $pull, $pullAll

	test { New-MdbcUpdate Name -Pull 1 } '{ "$pull" : { "Name" : 1 } }'
	test { New-MdbcUpdate Name -PullAll 1 } '{ "$pullAll" : { "Name" : [1] } }'

	test { New-MdbcUpdate Name -Pull 1, 2 } '{ "$pull" : { "Name" : [1, 2] } }'
	test { New-MdbcUpdate Name -PullAll 1, 2 } '{ "$pullAll" : { "Name" : [1, 2] } }'

	test { New-MdbcUpdate Name -Pull $mdbcArray } '{ "$pull" : { "Name" : [1, 2, 3] } }'
	test { New-MdbcUpdate Name -PullAll $mdbcArray } '{ "$pullAll" : { "Name" : [1, 2, 3] } }'

	test { New-MdbcUpdate Name -Pull $bsonArray } '{ "$pull" : { "Name" : [1, 2, 3] } }'
	test { New-MdbcUpdate Name -PullAll $bsonArray } '{ "$pullAll" : { "Name" : [1, 2, 3] } }'

	### $push, $pushAll

	test { New-MdbcUpdate Name -Push 1 } '{ "$push" : { "Name" : 1 } }'
	test { New-MdbcUpdate Name -PushAll 1 } '{ "$pushAll" : { "Name" : [1] } }'

	test { New-MdbcUpdate Name -Push 1, 2 } '{ "$push" : { "Name" : [1, 2] } }'
	test { New-MdbcUpdate Name -PushAll 1, 2 } '{ "$pushAll" : { "Name" : [1, 2] } }'

	test { New-MdbcUpdate Name -Push $mdbcArray } '{ "$push" : { "Name" : [1, 2, 3] } }'
	test { New-MdbcUpdate Name -PushAll $mdbcArray } '{ "$pushAll" : { "Name" : [1, 2, 3] } }'

	test { New-MdbcUpdate Name -Push $bsonArray } '{ "$push" : { "Name" : [1, 2, 3] } }'
	test { New-MdbcUpdate Name -PushAll $bsonArray } '{ "$pushAll" : { "Name" : [1, 2, 3] } }'

	### $pull with queries
	test { New-MdbcUpdate Name -Pull (New-MdbcQuery Name2 value) } '{ "$pull" : { "Name" : { "Name2" : "value" } } }'
	test { New-MdbcUpdate Name -Pull (New-MdbcQuery Name2 -GT value) } '{ "$pull" : { "Name" : { "Name2" : { "$gt" : "value" } } } }'

	### $rename
	test { New-MdbcUpdate One -Rename Two } '{ "$rename" : { "One" : "Two" } }'

	### $set
	test { New-MdbcUpdate Name -Set $null } '{ "$set" : { "Name" : null } }'
	test { New-MdbcUpdate Name -Set one } '{ "$set" : { "Name" : "one" } }'

	### $unset
	test { New-MdbcUpdate Name -Unset } '{ "$unset" : { "Name" : 1 } }'
}

# Mdbc cmdlets use ObjectToQuery to create IMongoQuery from objects.
# Let's test ObjectToQuery using New-MdbcQuery -Or.
task New-MdbcQuery.ObjectToQuery {
	# PSCustomObject - _id
	test { New-MdbcQuery -Or (New-Object PSObject -Property @{_id = 'PSCustomObject'}) } '{ "_id" : "PSCustomObject" }'

	# IMongoQuery - as it is
	test { New-MdbcQuery -Or (New-MdbcQuery Name -EQ 'One') } '{ "Name" : "One" }'

	# Mdbc.Dictionary - _id
	$md = New-MdbcData @{_id = 'Two'}
	test { New-MdbcQuery -Or $md } '{ "_id" : "Two" }'

	# BsonDocument - _id
	test { New-MdbcQuery -Or $md.Document() } '{ "_id" : "Two" }'

	# IDictionary - any JSON-like query
	test { New-MdbcQuery -Or @{'$set' = @{Name = 'Three'}} } '{ "$set" : { "Name" : "Three" } }'

	# Others are primitive for BsonValue.Create() - _id
	test { New-MdbcQuery -Or 'Four' } '{ "_id" : "Four" }'
}
