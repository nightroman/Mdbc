
<#
.SYNOPSIS
	Tests query and update expressions
#>

Import-Module Mdbc

# Test: compare the expression with expected representation
function test([Parameter()]$value, $expected) {
	"$value => $expected"
	$actual = (. $value).ToString()
	if ($actual -cne $expected) {
		$PSCmdlet.ThrowTerminatingError((New-Object System.Management.Automation.ErrorRecord ([Exception]"Actual:`n$actual"), $null, 'InvalidResult', $value))
	}
}

# DateTime value as PSObject for tests
$date = [PSObject][DateTime]'2011-11-11'

# Guid value as PSObject for tests
$guid = [PSObject][Guid]'12345678-1234-1234-1234-123456789012'

# BsonArray value for tests
$bsonArray = [MongoDB.Bson.BsonArray](1, 2, 3)
if ($bsonArray.GetType().Name -ne 'BsonArray') { throw }

# MdbcArray value for tests
$mdbcArray = New-MdbcData 1, 2, 3
if ($mdbcArray.GetType().Name -ne 'Collection') { throw }

### [ Comparison ]

### EQ
test { query Name 42 } '{ "Name" : 42 }'
test { query Name -EQ 42 } '{ "Name" : 42 }'

# EQ is used on its own
try { query Name -EQ 42 -GT 15 }
catch { $$ = "$_" }
if ($$ -ne 'Parameter set cannot be resolved using the specified named parameters.') { throw }

### LE
test { query Name -LE 42 } '{ "Name" : { "$lte" : 42 } }'

### LT
test { query Name -LT 42 } '{ "Name" : { "$lt" : 42 } }'

### GE
test { query Name -GE 42 } '{ "Name" : { "$gte" : 42 } }'

### GT
test { query Name -GT 42 } '{ "Name" : { "$gt" : 42 } }'

### NE
test { query Name -NE 42 } '{ "Name" : { "$ne" : 42 } }'

### [ Ignore Case ]

### IEQ
test { query Name -IEQ te*xt } '{ "Name" : /^te\\*xt$/i }'

### NEQ
test { query Name -INE te*xt } '{ "Name" : { "$not" : /^te\\*xt$/i } }'

### [ Misc ]

### Not
test { query -Not Name -mod 2, 1 } '{ "Name" : { "$not" : { "$mod" : [2, 1] } } }'

### Exists
test { query Name -Exists $true } '{ "Name" : { "$exists" : true } }'
test { query Name -Exists $false } '{ "Name" : { "$exists" : false } }'

### Mod
test { query Name -Mod 2, 1 } '{ "Name" : { "$mod" : [2, 1] } }'

### Size
test { query Name -Size 42 } '{ "Name" : { "$size" : 42 } }'

### Type
test { query Name -Type 1 } '{ "Name" : { "$type" : 1 } }'
test { query Name -Type Double } '{ "Name" : { "$type" : 1 } }'

### Where
test { query -Where 'this.Length == null' } '{ "$where" : { "$code" : "this.Length == null" } }'

### Match

test { query Name -Match '^text$' } '{ "Name" : /^text$/ }'
test { query Name -Match '^text$' -Not } '{ "Name" : { "$not" : /^text$/ } }'

test { query Name -Match '^text$', 'imxs' } '{ "Name" : /^text$/imxs }'
test { query Name -Match '^text$', 'imxs' -Not } '{ "Name" : { "$not" : /^text$/imxs } }'

$regex = New-Object regex '^text$', "IgnoreCase, Multiline, IgnorePatternWhitespace, Singleline"
test { query Name -Match $regex } '{ "Name" : /^text$/imxs }'
test { query Name -Match $regex -Not } '{ "Name" : { "$not" : /^text$/imxs } }'

### Matches
test { query Name -Matches (query (query a 1), (query b 2)) } '{ "Name" : { "$elemMatch" : { "a" : 1, "b" : 2 } } }'

### [ Sets ]

### All
test { query Name -All $bsonArray } '{ "Name" : { "$all" : [1, 2, 3] } }'
test { query Name -All $mdbcArray } '{ "Name" : { "$all" : [1, 2, 3] } }'
test { query Name -All $true } '{ "Name" : { "$all" : [true] } }'
test { query Name -All $date } '{ "Name" : { "$all" : [ISODate("2011-11-11T00:00:00Z")] } }'
test { query Name -All 1.1 } '{ "Name" : { "$all" : [1.1] } }'
test { query Name -All $guid } '{ "Name" : { "$all" : [CSUUID("12345678-1234-1234-1234-123456789012")] } }'
test { query Name -All 1 } '{ "Name" : { "$all" : [1] } }'
test { query Name -All 1L } '{ "Name" : { "$all" : [NumberLong(1)] } }'
test { query Name -All text } '{ "Name" : { "$all" : ["text"] } }'
test { query Name -All $true, more } '{ "Name" : { "$all" : [true, "more"] } }'
test { query Name -All $date, more } '{ "Name" : { "$all" : [ISODate("2011-11-11T00:00:00Z"), "more"] } }'
test { query Name -All 1.1, more } '{ "Name" : { "$all" : [1.1, "more"] } }'
test { query Name -All $guid, more } '{ "Name" : { "$all" : [CSUUID("12345678-1234-1234-1234-123456789012"), "more"] } }'
test { query Name -All 1, more } '{ "Name" : { "$all" : [1, "more"] } }'
test { query Name -All 1L, more } '{ "Name" : { "$all" : [NumberLong(1), "more"] } }'
test { query Name -All text, more } '{ "Name" : { "$all" : ["text", "more"] } }'

### In
test { query Name -In $bsonArray } '{ "Name" : { "$in" : [1, 2, 3] } }'
test { query Name -In $mdbcArray } '{ "Name" : { "$in" : [1, 2, 3] } }'
test { query Name -In $true } '{ "Name" : { "$in" : [true] } }'
test { query Name -In $date } '{ "Name" : { "$in" : [ISODate("2011-11-11T00:00:00Z")] } }'
test { query Name -In 1.1 } '{ "Name" : { "$in" : [1.1] } }'
test { query Name -In $guid } '{ "Name" : { "$in" : [CSUUID("12345678-1234-1234-1234-123456789012")] } }'
test { query Name -In 1 } '{ "Name" : { "$in" : [1] } }'
test { query Name -In 1L } '{ "Name" : { "$in" : [NumberLong(1)] } }'
test { query Name -In text } '{ "Name" : { "$in" : ["text"] } }'
test { query Name -In $true, more } '{ "Name" : { "$in" : [true, "more"] } }'
test { query Name -In $date, more } '{ "Name" : { "$in" : [ISODate("2011-11-11T00:00:00Z"), "more"] } }'
test { query Name -In 1.1, more } '{ "Name" : { "$in" : [1.1, "more"] } }'
test { query Name -In $guid, more } '{ "Name" : { "$in" : [CSUUID("12345678-1234-1234-1234-123456789012"), "more"] } }'
test { query Name -In 1, more } '{ "Name" : { "$in" : [1, "more"] } }'
test { query Name -In 1L, more } '{ "Name" : { "$in" : [NumberLong(1), "more"] } }'
test { query Name -In text, more } '{ "Name" : { "$in" : ["text", "more"] } }'

### NotIn
test { query Name -NotIn $bsonArray } '{ "Name" : { "$nin" : [1, 2, 3] } }'
test { query Name -NotIn $mdbcArray } '{ "Name" : { "$nin" : [1, 2, 3] } }'
test { query Name -NotIn $true } '{ "Name" : { "$nin" : [true] } }'
test { query Name -NotIn $date } '{ "Name" : { "$nin" : [ISODate("2011-11-11T00:00:00Z")] } }'
test { query Name -NotIn 1.1 } '{ "Name" : { "$nin" : [1.1] } }'
test { query Name -NotIn $guid } '{ "Name" : { "$nin" : [CSUUID("12345678-1234-1234-1234-123456789012")] } }'
test { query Name -NotIn 1 } '{ "Name" : { "$nin" : [1] } }'
test { query Name -NotIn 1L } '{ "Name" : { "$nin" : [NumberLong(1)] } }'
test { query Name -NotIn text } '{ "Name" : { "$nin" : ["text"] } }'
test { query Name -NotIn $true, more } '{ "Name" : { "$nin" : [true, "more"] } }'
test { query Name -NotIn $date, more } '{ "Name" : { "$nin" : [ISODate("2011-11-11T00:00:00Z"), "more"] } }'
test { query Name -NotIn 1.1, more } '{ "Name" : { "$nin" : [1.1, "more"] } }'
test { query Name -NotIn $guid, more } '{ "Name" : { "$nin" : [CSUUID("12345678-1234-1234-1234-123456789012"), "more"] } }'
test { query Name -NotIn 1, more } '{ "Name" : { "$nin" : [1, "more"] } }'
test { query Name -NotIn 1L, more } '{ "Name" : { "$nin" : [NumberLong(1), "more"] } }'
test { query Name -NotIn text, more } '{ "Name" : { "$nin" : ["text", "more"] } }'

### [ Query Operators ]

### And
test { query (query x 1), (query y 2) } '{ "x" : 1, "y" : 2 }'

### Nor
test { query -Nor (query x 1), (query y 2) } '{ "$nor" : [{ "x" : 1 }, { "y" : 2 }] }'

### Or
test { query -Or (query x 1), (query y 2) } '{ "$or" : [{ "x" : 1 }, { "y" : 2 }] }'

### [ Update Expressions ]

### $addToSet

test { update Name -AddToSet 1 } '{ "$addToSet" : { "Name" : 1 } }'
test { update Name -AddToSetEach 1 } '{ "$addToSet" : { "Name" : { "$each" : [1] } } }'

test { update Name -AddToSet 1, 2 } '{ "$addToSet" : { "Name" : [1, 2] } }'
test { update Name -AddToSetEach 1, 2 } '{ "$addToSet" : { "Name" : { "$each" : [1, 2] } } }'

test { update Name -AddToSet $mdbcArray } '{ "$addToSet" : { "Name" : [1, 2, 3] } }'
test { update Name -AddToSetEach $mdbcArray } '{ "$addToSet" : { "Name" : { "$each" : [1, 2, 3] } } }'

test { update Name -AddToSet $bsonArray } '{ "$addToSet" : { "Name" : [1, 2, 3] } }'
test { update Name -AddToSetEach $bsonArray } '{ "$addToSet" : { "Name" : { "$each" : [1, 2, 3] } } }'

### $bit

test { update Name -Band 1 } '{ "$bit" : { "Name" : { "and" : 1 } } }'
test { update Name -Band 1L } '{ "$bit" : { "Name" : { "and" : NumberLong(1) } } }'

test { update Name -Bor 1 } '{ "$bit" : { "Name" : { "or" : 1 } } }'
test { update Name -Bor 1L } '{ "$bit" : { "Name" : { "or" : NumberLong(1) } } }'

### $inc
test { update Name -Increment 1 } '{ "$inc" : { "Name" : 1 } }'
test { update Name -Increment 1L } '{ "$inc" : { "Name" : NumberLong(1) } }'
test { update Name -Increment 1.1 } '{ "$inc" : { "Name" : 1.1 } }'

### $pop

test { update Name -PopFirst } '{ "$pop" : { "Name" : -1 } }'
test { update Name -PopLast } '{ "$pop" : { "Name" : 1 } }'

### $pull, $pullAll

test { update Name -Pull 1 } '{ "$pull" : { "Name" : 1 } }'
test { update Name -PullAll 1 } '{ "$pullAll" : { "Name" : [1] } }'

test { update Name -Pull 1, 2 } '{ "$pull" : { "Name" : [1, 2] } }'
test { update Name -PullAll 1, 2 } '{ "$pullAll" : { "Name" : [1, 2] } }'

test { update Name -Pull $mdbcArray } '{ "$pull" : { "Name" : [1, 2, 3] } }'
test { update Name -PullAll $mdbcArray } '{ "$pullAll" : { "Name" : [1, 2, 3] } }'

test { update Name -Pull $bsonArray } '{ "$pull" : { "Name" : [1, 2, 3] } }'
test { update Name -PullAll $bsonArray } '{ "$pullAll" : { "Name" : [1, 2, 3] } }'

### $push, $pushAll

test { update Name -Push 1 } '{ "$push" : { "Name" : 1 } }'
test { update Name -PushAll 1 } '{ "$pushAll" : { "Name" : [1] } }'

test { update Name -Push 1, 2 } '{ "$push" : { "Name" : [1, 2] } }'
test { update Name -PushAll 1, 2 } '{ "$pushAll" : { "Name" : [1, 2] } }'

test { update Name -Push $mdbcArray } '{ "$push" : { "Name" : [1, 2, 3] } }'
test { update Name -PushAll $mdbcArray } '{ "$pushAll" : { "Name" : [1, 2, 3] } }'

test { update Name -Push $bsonArray } '{ "$push" : { "Name" : [1, 2, 3] } }'
test { update Name -PushAll $bsonArray } '{ "$pushAll" : { "Name" : [1, 2, 3] } }'

#??? how to get this : { $pull : { field : {$gt: 3} }
test { update Name -Pull (query Name2 value) } '{ "$pull" : { "Name" : { "Name2" : "value" } } }'

### $rename
test { update One -Rename Two } '{ "$rename" : { "One" : "Two" } }'

### $set
test { update Name -Set $null } '{ "$set" : { } }'
test { update Name -Set one } '{ "$set" : { "Name" : "one" } }'

### $unset
test { update Name -Unset } '{ "$unset" : { "Name" : 1 } }'
