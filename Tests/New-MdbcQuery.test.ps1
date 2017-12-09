
. .\Zoo.ps1
Import-Module Mdbc
Set-Alias test Test-Expression

# DateTime value as PSObject for tests
$date = [PSObject][DateTime]'2011-11-11'

# Guid value as PSObject for tests
$guid = [PSObject][Guid]'12345678-1234-1234-1234-123456789012'

# BsonArray value for tests
$bsonArray = New-MdbcData -Value 1, 2, 3
Test-Type $bsonArray MongoDB.Bson.BsonArray

# MdbcArray value for tests
$mdbcArray = [Mdbc.Collection]$bsonArray
Test-Type $mdbcArray Mdbc.Collection

task EQ {
	test { New-MdbcQuery Name 42 } '{ "Name" : 42 }'
	test { New-MdbcQuery Name -EQ 42 } '{ "Name" : 42 }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -EQ 42) } '{ "Name" : { "$ne" : 42 } }'

	# EQ is used on its own
	Test-Error { New-MdbcQuery Name -EQ 42 -GT 15 } 'Parameter set cannot be resolved using the specified named parameters.'
}

task NE {
	test { New-MdbcQuery Name -NE 42 } '{ "Name" : { "$ne" : 42 } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -NE 42) } '{ "Name" : 42 }'
}

task GT {
	test { New-MdbcQuery Name -GT 42 } '{ "Name" : { "$gt" : 42 } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -GT 42) } '{ "Name" : { "$not" : { "$gt" : 42 } } }'
}

task GTE {
	test { New-MdbcQuery Name -GTE 42 } '{ "Name" : { "$gte" : 42 } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -GTE 42) } '{ "Name" : { "$not" : { "$gte" : 42 } } }'
}

task LT {
	test { New-MdbcQuery Name -LT 42 } '{ "Name" : { "$lt" : 42 } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -LT 42) } '{ "Name" : { "$not" : { "$lt" : 42 } } }'
}

task LTE {
	test { New-MdbcQuery Name -LTE 42 } '{ "Name" : { "$lte" : 42 } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -LTE 42) } '{ "Name" : { "$not" : { "$lte" : 42 } } }'
}

task IEQ {
	test { New-MdbcQuery Name -IEQ te*xt } '{ "Name" : /^te\*xt$/i }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -IEQ te*xt) } '{ "Name" : { "$not" : /^te\*xt$/i } }'
}

task INE {
	test { New-MdbcQuery Name -INE te*xt } '{ "Name" : { "$not" : /^te\*xt$/i } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -INE te*xt) } '{ "Name" : /^te\*xt$/i }'
}

task Exists {
	test { New-MdbcQuery Name -Exists } '{ "Name" : { "$exists" : true } }'
	test { New-MdbcQuery Name -Exists:$false } '{ "Name" : { "$exists" : false } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -Exists) } '{ "Name" : { "$exists" : false } }'

	test { New-MdbcQuery Name -NotExists } '{ "Name" : { "$exists" : false } }'
	test { New-MdbcQuery Name -NotExists:$false } '{ "Name" : { "$exists" : true } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -NotExists) } '{ "Name" : { "$exists" : true } }'
}

task Mod {
	test { New-MdbcQuery Name -Mod 2, 1 } '{ "Name" : { "$mod" : [2, 1] } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -Mod 2, 1) } '{ "Name" : { "$not" : { "$mod" : [2, 1] } } }'
}

task Size {
	test { New-MdbcQuery Name -Size 42 } '{ "Name" : { "$size" : 42 } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -Size 42) } '{ "Name" : { "$not" : { "$size" : 42 } } }'
}

task Type {
	test { New-MdbcQuery Name -Type 1 } '{ "Name" : { "$type" : 1 } }'
	test { New-MdbcQuery Name -Type Double } '{ "Name" : { "$type" : 1 } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -Type Double) } '{ "Name" : { "$not" : { "$type" : 1 } } }'
}

task TypeAlias {
	test { New-MdbcQuery Name -TypeAlias number } '{ "Name" : { "$type" : "number" } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -TypeAlias number) } '{ "Name" : { "$not" : { "$type" : "number" } } }'
}

task Where {
	test { New-MdbcQuery -Where 'this.Length == null' } '{ "$where" : { "$code" : "this.Length == null" } }'
	# fixed https://jira.mongodb.org/browse/CSHARP-840
	test { New-MdbcQuery -Not (New-MdbcQuery -Where 'this.Length == null') } '{ "$nor" : [{ "$where" : { "$code" : "this.Length == null" } }] }'
}

task Match {
	test { New-MdbcQuery Name -Matches '^text$' } '{ "Name" : /^text$/ }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -Matches '^text$') } '{ "Name" : { "$not" : /^text$/ } }'

	test { New-MdbcQuery Name -Matches '^text$', 'imxs' } '{ "Name" : /^text$/imxs }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -Matches '^text$', 'imxs') } '{ "Name" : { "$not" : /^text$/imxs } }'

	$regex = New-Object regex '^text$', "IgnoreCase, Multiline, IgnorePatternWhitespace, Singleline"
	test { New-MdbcQuery Name -Matches $regex } '{ "Name" : /^text$/imxs }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -Matches $regex) } '{ "Name" : { "$not" : /^text$/imxs } }'
}

task ElemMatch {
	$query = New-MdbcQuery -And (New-MdbcQuery a 1), (New-MdbcQuery b 2)
	test { New-MdbcQuery Name -ElemMatch $query } '{ "Name" : { "$elemMatch" : { "a" : 1, "b" : 2 } } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -ElemMatch $query) } '{ "Name" : { "$not" : { "$elemMatch" : { "a" : 1, "b" : 2 } } } }'

	#_131110_085122
	Test-Error { New-MdbcQuery Name -ElemMatch 1,2 } "Can't use an array for _id."
}

task All {
	test { New-MdbcQuery Name -All $bsonArray } '{ "Name" : { "$all" : [1, 2, 3] } }'
	test { New-MdbcQuery Name -All $mdbcArray } '{ "Name" : { "$all" : [1, 2, 3] } }'
	test { New-MdbcQuery Name -All $true } '{ "Name" : { "$all" : [true] } }'
	test { New-MdbcQuery Name -All $date } '{ "Name" : { "$all" : [ISODate("2011-11-11T00:00:00Z")] } }'
	test { New-MdbcQuery Name -All 1.1 } '{ "Name" : { "$all" : [1.1000000000000001] } }'
	test { New-MdbcQuery Name -All $guid } '{ "Name" : { "$all" : [UUID("12345678-1234-1234-1234-123456789012")] } }'
	test { New-MdbcQuery Name -All 1 } '{ "Name" : { "$all" : [1] } }'
	test { New-MdbcQuery Name -All 1L } '{ "Name" : { "$all" : [NumberLong(1)] } }'
	test { New-MdbcQuery Name -All text } '{ "Name" : { "$all" : ["text"] } }'
	test { New-MdbcQuery Name -All $true, more } '{ "Name" : { "$all" : [true, "more"] } }'
	test { New-MdbcQuery Name -All $date, more } '{ "Name" : { "$all" : [ISODate("2011-11-11T00:00:00Z"), "more"] } }'
	test { New-MdbcQuery Name -All 1.1, more } '{ "Name" : { "$all" : [1.1000000000000001, "more"] } }'
	test { New-MdbcQuery Name -All $guid, more } '{ "Name" : { "$all" : [UUID("12345678-1234-1234-1234-123456789012"), "more"] } }'
	test { New-MdbcQuery Name -All 1, more } '{ "Name" : { "$all" : [1, "more"] } }'
	test { New-MdbcQuery Name -All 1L, more } '{ "Name" : { "$all" : [NumberLong(1), "more"] } }'
	test { New-MdbcQuery Name -All text, more } '{ "Name" : { "$all" : ["text", "more"] } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -All text, more) } '{ "Name" : { "$not" : { "$all" : ["text", "more"] } } }'
}

task In {
	test { New-MdbcQuery Name -In $bsonArray } '{ "Name" : { "$in" : [1, 2, 3] } }'
	test { New-MdbcQuery Name -In $mdbcArray } '{ "Name" : { "$in" : [1, 2, 3] } }'
	test { New-MdbcQuery Name -In $true } '{ "Name" : { "$in" : [true] } }'
	test { New-MdbcQuery Name -In $date } '{ "Name" : { "$in" : [ISODate("2011-11-11T00:00:00Z")] } }'
	test { New-MdbcQuery Name -In 1.1 } '{ "Name" : { "$in" : [1.1000000000000001] } }'
	test { New-MdbcQuery Name -In $guid } '{ "Name" : { "$in" : [UUID("12345678-1234-1234-1234-123456789012")] } }'
	test { New-MdbcQuery Name -In 1 } '{ "Name" : { "$in" : [1] } }'
	test { New-MdbcQuery Name -In 1L } '{ "Name" : { "$in" : [NumberLong(1)] } }'
	test { New-MdbcQuery Name -In text } '{ "Name" : { "$in" : ["text"] } }'
	test { New-MdbcQuery Name -In $true, more } '{ "Name" : { "$in" : [true, "more"] } }'
	test { New-MdbcQuery Name -In $date, more } '{ "Name" : { "$in" : [ISODate("2011-11-11T00:00:00Z"), "more"] } }'
	test { New-MdbcQuery Name -In 1.1, more } '{ "Name" : { "$in" : [1.1000000000000001, "more"] } }'
	test { New-MdbcQuery Name -In $guid, more } '{ "Name" : { "$in" : [UUID("12345678-1234-1234-1234-123456789012"), "more"] } }'
	test { New-MdbcQuery Name -In 1, more } '{ "Name" : { "$in" : [1, "more"] } }'
	test { New-MdbcQuery Name -In 1L, more } '{ "Name" : { "$in" : [NumberLong(1), "more"] } }'
	test { New-MdbcQuery Name -In text, more } '{ "Name" : { "$in" : ["text", "more"] } }'
	test { New-MdbcQuery Name -In text, ([regex]'^more$') } '{ "Name" : { "$in" : ["text", /^more$/] } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -In text, more) } '{ "Name" : { "$nin" : ["text", "more"] } }'
}

task NotIn {
	test { New-MdbcQuery Name -NotIn $bsonArray } '{ "Name" : { "$nin" : [1, 2, 3] } }'
	test { New-MdbcQuery Name -NotIn $mdbcArray } '{ "Name" : { "$nin" : [1, 2, 3] } }'
	test { New-MdbcQuery Name -NotIn $true } '{ "Name" : { "$nin" : [true] } }'
	test { New-MdbcQuery Name -NotIn $date } '{ "Name" : { "$nin" : [ISODate("2011-11-11T00:00:00Z")] } }'
	test { New-MdbcQuery Name -NotIn 1.1 } '{ "Name" : { "$nin" : [1.1000000000000001] } }'
	test { New-MdbcQuery Name -NotIn $guid } '{ "Name" : { "$nin" : [UUID("12345678-1234-1234-1234-123456789012")] } }'
	test { New-MdbcQuery Name -NotIn 1 } '{ "Name" : { "$nin" : [1] } }'
	test { New-MdbcQuery Name -NotIn 1L } '{ "Name" : { "$nin" : [NumberLong(1)] } }'
	test { New-MdbcQuery Name -NotIn text } '{ "Name" : { "$nin" : ["text"] } }'
	test { New-MdbcQuery Name -NotIn $true, more } '{ "Name" : { "$nin" : [true, "more"] } }'
	test { New-MdbcQuery Name -NotIn $date, more } '{ "Name" : { "$nin" : [ISODate("2011-11-11T00:00:00Z"), "more"] } }'
	test { New-MdbcQuery Name -NotIn 1.1, more } '{ "Name" : { "$nin" : [1.1000000000000001, "more"] } }'
	test { New-MdbcQuery Name -NotIn $guid, more } '{ "Name" : { "$nin" : [UUID("12345678-1234-1234-1234-123456789012"), "more"] } }'
	test { New-MdbcQuery Name -NotIn 1, more } '{ "Name" : { "$nin" : [1, "more"] } }'
	test { New-MdbcQuery Name -NotIn 1L, more } '{ "Name" : { "$nin" : [NumberLong(1), "more"] } }'
	test { New-MdbcQuery Name -NotIn text, more } '{ "Name" : { "$nin" : ["text", "more"] } }'
	test { New-MdbcQuery Name -NotIn text, ([regex]'^more$') } '{ "Name" : { "$nin" : ["text", /^more$/] } }'
	test { New-MdbcQuery -Not (New-MdbcQuery Name -NotIn text, more) } '{ "Name" : { "$in" : ["text", "more"] } }'
}

task And {
	test { New-MdbcQuery -And (New-MdbcQuery x 1), (New-MdbcQuery y 2) } '{ "x" : 1, "y" : 2 }'
	test { New-MdbcQuery -Not (New-MdbcQuery -And (New-MdbcQuery x 1), (New-MdbcQuery y 2)) } '{ "$nor" : [{ "x" : 1, "y" : 2 }] }'
}

task Or {
	test { New-MdbcQuery -Or (New-MdbcQuery x 1), (New-MdbcQuery y 2) } '{ "$or" : [{ "x" : 1 }, { "y" : 2 }] }'
	test { New-MdbcQuery -Not (New-MdbcQuery -Or (New-MdbcQuery x 1), (New-MdbcQuery y 2)) } '{ "$nor" : [{ "x" : 1 }, { "y" : 2 }] }'
}

# Various query parameters use ObjectToQuery to create IMongoQuery from
# arguments. Let's test this process using New-MdbcQuery -Or <argument>.
task ObjectToQuery {
	# IMongoQuery - as it is
	test { New-MdbcQuery -Or (New-MdbcQuery Name -EQ 'One') } '{ "Name" : "One" }'

	# Mdbc.Dictionary - ToBsonDocument() -> QueryDocument
	$d = New-MdbcData; $d._id = 1; $d.name = 'name1'
	test { New-MdbcQuery -Or $d } '{ "_id" : 1, "name" : "name1" }'

	# BsonDocument -> QueryDocument
	test { New-MdbcQuery -Or $d.ToBsonDocument() } '{ "_id" : 1, "name" : "name1" }'

	# IDictionary -> QueryDocument
	$d = New-Object Collections.Specialized.OrderedDictionary; $d._id = 1; $d.name = 'name1'
	test { New-MdbcQuery -Or $d } '{ "_id" : 1, "name" : "name1" }'

	# Others are used as _id
	test { New-MdbcQuery -Or 42 } '{ "_id" : 42 }'

	# KO PSCustomObject
	Test-Error { New-MdbcQuery -Or (New-Object PSObject -Property @{_id = 1}) } '*PSCustomObject cannot be mapped to a BsonValue.*'
}

# fixes
task Nulls {
	test { New-MdbcQuery null -EQ $null } '{ "null" : null }'
	test { New-MdbcQuery null -NE $null } '{ "null" : { "$ne" : null } }'
}
