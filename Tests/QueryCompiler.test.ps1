
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version 2

$date = [DateTime]'2000-01-01'
$guid = [Guid]'94a30dd6-6451-49fb-9c48-18e3f1509877'
$document = New-MdbcData -NewId @{
	null = $null
	text = 'text'
	int = 42
	pi = 3.14
	date = $date
	guid = $guid
	empty = @()
	three = 1, 2, 3
	doc0 = @{}
	doc1 = @{x=1; y=2; deep=@{x=9}; '1'=@{n=42}}
	doc2 = @{x=1; y=2}, @{x=3; y=4; deep=@{x=9}}
	arr1 = 0, 42, @{x=33}
	arr2 = @(@{x=1}, @{x=9}), @(1, 2)
}

$CLRVersion3 = $PSVersionTable.CLRVersion.Major -lt 4
function query(
	$query, # query to be tested
	$count, # sample query result count
	$queryText, # sample native query text
	$expressionText # sample expression query text
)
{
	# get and show query text
	if ($query -is [hashtable]) {$query = New-MdbcQuery -And $query}
	$queryText2 = $query.ToString()
	$queryText2

	# 1. test query count
	$count2 = Get-MdbcData -Count $query
	if ($count -ne $count2) {
		Write-Error "`n Query count sample : $count`n Query count result : $count2"
	}

	# 2. test query text
	if ($queryText -cne $queryText2) {
		Write-Error "`n Query text sample : $queryText`n Query text result : $queryText2"
	}

	# get and show expression
	try { $expression = [Mdbc.QueryCompiler]::GetExpression($query) }
	catch { Write-Error $_ }
	$expressionText2 = $expression.ToString()
	if ($CLRVersion3) {$expressionText2 = $expressionText2.Replace(' = ', ' == ')}
	$expressionText2

	# 1. test expression count
	try { $count2 = [int][Mdbc.QueryCompiler]::GetFunction($expression).Invoke($document) }
	catch { Write-Error $_ }
	if ($count -ne $count2) {
		Write-Error "`n Expression count sample : $count`n Expression count result : $count2"
	}

	# 2. test expression text
	if ($expressionText -cne $expressionText2) {
		Write-Error "`n Expression sample : $expressionText`n Expression result : $expressionText2"
	}
}

function Enter-Build {
	Connect-Mdbc -NewCollection
	$document | Add-MdbcData
}

task EQ {
	query (New-MdbcQuery null -EQ $null) 1 '{ "null" : null }' 'EQ(data, "null", BsonNull)'
	query (New-MdbcQuery miss -EQ $null) 1 '{ "miss" : null }' 'EQ(data, "miss", BsonNull)'
	query (New-MdbcQuery miss -EQ 12345) 0 '{ "miss" : 12345 }' 'EQ(data, "miss", 12345)'

	query (New-MdbcQuery int -EQ 99) 0 '{ "int" : 99 }' 'EQ(data, "int", 99)'
	query (New-MdbcQuery int -EQ 42) 1 '{ "int" : 42 }' 'EQ(data, "int", 42)'
	query (New-MdbcQuery int -EQ 42L) 1 '{ "int" : NumberLong(42) }' 'EQ(data, "int", 42)'
	query (New-MdbcQuery int -EQ 42.0) 1 '{ "int" : 42.0 }' 'EQ(data, "int", 42)'

	query @{doc0=@{}} 1 '{ "doc0" : { } }' 'EQ(data, "doc0", { })'
}

task NE {
	query (New-MdbcQuery null -NE $null) 0 '{ "null" : { "$ne" : null } }' 'NE(data, "null", BsonNull)'
	query (New-MdbcQuery miss -NE $null) 0 '{ "miss" : { "$ne" : null } }' 'NE(data, "miss", BsonNull)'
	query (New-MdbcQuery miss -NE 12345) 1 '{ "miss" : { "$ne" : 12345 } }' 'NE(data, "miss", 12345)'

	query (New-MdbcQuery int -NE 99) 1 '{ "int" : { "$ne" : 99 } }' 'NE(data, "int", 99)'
	query (New-MdbcQuery int -NE 42) 0 '{ "int" : { "$ne" : 42 } }' 'NE(data, "int", 42)'
	query (New-MdbcQuery int -NE 42L) 0 '{ "int" : { "$ne" : NumberLong(42) } }' 'NE(data, "int", 42)'
	query (New-MdbcQuery int -NE 42.0) 0 '{ "int" : { "$ne" : 42.0 } }' 'NE(data, "int", 42)'
}

task GT {
	query (New-MdbcQuery null -GT $null) 0 '{ "null" : { "$gt" : null } }' 'GT(data, "null", BsonNull)'
	query (New-MdbcQuery miss -GT $null) 1 '{ "miss" : { "$gt" : null } }' 'GT(data, "miss", BsonNull)'
	query (New-MdbcQuery miss -GT 12345) 0 '{ "miss" : { "$gt" : 12345 } }' 'GT(data, "miss", 12345)'

	query (New-MdbcQuery int -GT (-99)) 1 '{ "int" : { "$gt" : -99 } }' 'GT(data, "int", -99)'
	query (New-MdbcQuery int -GT 42) 0 '{ "int" : { "$gt" : 42 } }' 'GT(data, "int", 42)'
	query (New-MdbcQuery int -GT 99) 0 '{ "int" : { "$gt" : 99 } }' 'GT(data, "int", 99)'

	query (New-MdbcQuery text -GT 'aaaa') 1 '{ "text" : { "$gt" : "aaaa" } }' 'GT(data, "text", aaaa)'
	query (New-MdbcQuery text -GT 'text') 0 '{ "text" : { "$gt" : "text" } }' 'GT(data, "text", text)'
	query (New-MdbcQuery text -GT 'zzzz') 0 '{ "text" : { "$gt" : "zzzz" } }' 'GT(data, "text", zzzz)'
}

task GTE {
	query (New-MdbcQuery null -GTE $null) 1 '{ "null" : { "$gte" : null } }' 'GTE(data, "null", BsonNull)'
	query (New-MdbcQuery miss -GTE $null) 1 '{ "miss" : { "$gte" : null } }' 'GTE(data, "miss", BsonNull)'
	query (New-MdbcQuery miss -GTE 12345) 0 '{ "miss" : { "$gte" : 12345 } }' 'GTE(data, "miss", 12345)'

	query (New-MdbcQuery int -GTE (-99)) 1 '{ "int" : { "$gte" : -99 } }' 'GTE(data, "int", -99)'
	query (New-MdbcQuery int -GTE 42) 1 '{ "int" : { "$gte" : 42 } }' 'GTE(data, "int", 42)'
	query (New-MdbcQuery int -GTE 99) 0 '{ "int" : { "$gte" : 99 } }' 'GTE(data, "int", 99)'

	query (New-MdbcQuery text -GTE 'aaaa') 1 '{ "text" : { "$gte" : "aaaa" } }' 'GTE(data, "text", aaaa)'
	query (New-MdbcQuery text -GTE 'text') 1 '{ "text" : { "$gte" : "text" } }' 'GTE(data, "text", text)'
	query (New-MdbcQuery text -GTE 'zzzz') 0 '{ "text" : { "$gte" : "zzzz" } }' 'GTE(data, "text", zzzz)'
}

task LT {
	query (New-MdbcQuery null -LT $null) 0 '{ "null" : { "$lt" : null } }' 'LT(data, "null", BsonNull)'
	query (New-MdbcQuery miss -LT $null) 1 '{ "miss" : { "$lt" : null } }' 'LT(data, "miss", BsonNull)'
	query (New-MdbcQuery miss -LT 12345) 0 '{ "miss" : { "$lt" : 12345 } }' 'LT(data, "miss", 12345)'

	query (New-MdbcQuery int -LT (-99)) 0 '{ "int" : { "$lt" : -99 } }' 'LT(data, "int", -99)'
	query (New-MdbcQuery int -LT 42) 0 '{ "int" : { "$lt" : 42 } }' 'LT(data, "int", 42)'
	query (New-MdbcQuery int -LT 99) 1 '{ "int" : { "$lt" : 99 } }' 'LT(data, "int", 99)'

	query (New-MdbcQuery text -LT 'aaaa') 0 '{ "text" : { "$lt" : "aaaa" } }' 'LT(data, "text", aaaa)'
	query (New-MdbcQuery text -LT 'text') 0 '{ "text" : { "$lt" : "text" } }' 'LT(data, "text", text)'
	query (New-MdbcQuery text -LT 'zzzz') 1 '{ "text" : { "$lt" : "zzzz" } }' 'LT(data, "text", zzzz)'
}

task LTE {
	query (New-MdbcQuery null -LTE $null) 1 '{ "null" : { "$lte" : null } }' 'LTE(data, "null", BsonNull)'
	query (New-MdbcQuery miss -LTE $null) 1 '{ "miss" : { "$lte" : null } }' 'LTE(data, "miss", BsonNull)'
	query (New-MdbcQuery miss -LTE 12345) 0 '{ "miss" : { "$lte" : 12345 } }' 'LTE(data, "miss", 12345)'

	query (New-MdbcQuery int -LTE (-99)) 0 '{ "int" : { "$lte" : -99 } }' 'LTE(data, "int", -99)'
	query (New-MdbcQuery int -LTE 42) 1 '{ "int" : { "$lte" : 42 } }' 'LTE(data, "int", 42)'
	query (New-MdbcQuery int -LTE 99) 1 '{ "int" : { "$lte" : 99 } }' 'LTE(data, "int", 99)'

	query (New-MdbcQuery text -LTE 'aaaa') 0 '{ "text" : { "$lte" : "aaaa" } }' 'LTE(data, "text", aaaa)'
	query (New-MdbcQuery text -LTE 'text') 1 '{ "text" : { "$lte" : "text" } }' 'LTE(data, "text", text)'
	query (New-MdbcQuery text -LTE 'zzzz') 1 '{ "text" : { "$lte" : "zzzz" } }' 'LTE(data, "text", zzzz)'
}

task Exists {
	query (New-MdbcQuery miss -Exists) 0 '{ "miss" : { "$exists" : true } }' '(data.Contains("miss") == True)'
	query (New-MdbcQuery text -Exists) 1 '{ "text" : { "$exists" : true } }' '(data.Contains("text") == True)'

	query (New-MdbcQuery miss -NotExists) 1 '{ "miss" : { "$exists" : false } }' '(data.Contains("miss") == False)'
	query (New-MdbcQuery text -NotExists) 0 '{ "text" : { "$exists" : false } }' '(data.Contains("text") == False)'
}

task And {
	# implicit

	$query = New-MdbcQuery -And @{int=42}, @{text='text'}

	query $query 1 `
	'{ "int" : 42, "text" : "text" }' '(EQ(data, "int", 42) And EQ(data, "text", text))'

	query (New-MdbcQuery -Not $query) 0 `
	'{ "$nor" : [{ "int" : 42, "text" : "text" }] }' 'Not((EQ(data, "int", 42) And EQ(data, "text", text)))'

	# explicit

	$query = New-MdbcQuery -And @{int=@{'$exists'=1}}, @{int=42}

	query $query 1 `
	'{ "$and" : [{ "int" : { "$exists" : 1 } }, { "int" : 42 }] }' '((data.Contains("int") == True) And EQ(data, "int", 42))'

	query (New-MdbcQuery -Not $query) 0 `
	'{ "$nor" : [{ "$and" : [{ "int" : { "$exists" : 1 } }, { "int" : 42 }] }] }' 'Not(((data.Contains("int") == True) And EQ(data, "int", 42)))'

	# combined

	$query = @{int=@{'$exists'=1; '$ne'=99}}

	query $query 1 `
	'{ "int" : { "$ne" : 99, "$exists" : 1 } }' '(NE(data, "int", 99) And (data.Contains("int") == True))'

	query (New-MdbcQuery -Not $query) 0 `
	'{ "$nor" : [{ "int" : { "$ne" : 99, "$exists" : 1 } }] }' 'Not((NE(data, "int", 99) And (data.Contains("int") == True)))'
}

task Or {
	$query = New-MdbcQuery -Or @{int=42}, @{text='text'}

	query $query 1 `
	'{ "$or" : [{ "int" : 42 }, { "text" : "text" }] }' '(EQ(data, "int", 42) Or EQ(data, "text", text))'

	query (New-MdbcQuery -Not $query) 0 `
	'{ "$nor" : [{ "int" : 42 }, { "text" : "text" }] }' 'Not((EQ(data, "int", 42) Or EQ(data, "text", text)))'
}

task Matches {
	query @{null=@{'$regex'=$null}} 0 '{ "null" : { "$regex" : null } }' 'Matches(data, "null", null)'
	query @{miss=@{'$regex'=$null}} 0 '{ "miss" : { "$regex" : null } }' 'Matches(data, "miss", null)'

	query (New-MdbcQuery miss -Matches 'text') 0 '{ "miss" : /text/ }' 'Matches(data, "miss", text)'
	query (New-MdbcQuery int -Matches '42') 0 '{ "int" : /42/ }' 'Matches(data, "int", 42)'

	query (New-MdbcQuery text -Matches 'text') 1 '{ "text" : /text/ }' 'Matches(data, "text", text)'
	query (New-MdbcQuery text -Matches 'TEXT') 0 '{ "text" : /TEXT/ }' 'Matches(data, "text", TEXT)'
	query (New-MdbcQuery text -Matches 'TEXT', 'i') 1 '{ "text" : /TEXT/i }' 'Matches(data, "text", TEXT)'

	query (New-MdbcQuery text -IEQ 'TEXT') 1 '{ "text" : /^TEXT$/i }' 'Matches(data, "text", ^TEXT$)'
	query (New-MdbcQuery text -INE 'TEXT') 0 '{ "text" : { "$not" : /^TEXT$/i } }' 'Not(Matches(data, "text", ^TEXT$))'
}

task Type {
	query (New-MdbcQuery null -Type Null) 1 '{ "null" : { "$type" : 10 } }' 'Type(data, "null", Null)'
	query (New-MdbcQuery miss -Type Null) 0 '{ "miss" : { "$type" : 10 } }' 'Type(data, "miss", Null)'

	query (New-MdbcQuery int -Type Int32) 1 '{ "int" : { "$type" : 16 } }' 'Type(data, "int", Int32)'
	query (New-MdbcQuery int -Type Int64) 0 '{ "int" : { "$type" : 18 } }' 'Type(data, "int", Int64)'

	query @{int=@{'$type'=16.0}} 1 '{ "int" : { "$type" : 16.0 } }' 'Type(data, "int", Int32)'
	query @{int=@{'$type'=16L}} 1 '{ "int" : { "$type" : NumberLong(16) } }' 'Type(data, "int", Int32)'

	Test-Error { Get-MdbcData @{int=@{'$type'=$null}} } '*type not supported*'
	Test-Error { Get-MdbcData @{int=@{'$type'='16'}} } '*type not supported*'
}

task Mod {
	query (New-MdbcQuery null -Mod 2, 0) 0 '{ "null" : { "$mod" : [2, 0] } }' 'Mod(data, "null", 2, 0)'
	query (New-MdbcQuery miss -Mod 2, 0) 0 '{ "miss" : { "$mod" : [2, 0] } }' 'Mod(data, "miss", 2, 0)'
	query (New-MdbcQuery text -Mod 2, 0) 0 '{ "text" : { "$mod" : [2, 0] } }' 'Mod(data, "text", 2, 0)'

	query (New-MdbcQuery int -Mod 2, 0) 1 '{ "int" : { "$mod" : [2, 0] } }' 'Mod(data, "int", 2, 0)'
	query (New-MdbcQuery int -Mod 2, 1) 0 '{ "int" : { "$mod" : [2, 1] } }' 'Mod(data, "int", 2, 1)'

	# long and double
	query @{int=@{'$mod'=2L, 0}} 1 '{ "int" : { "$mod" : [NumberLong(2), 0] } }' 'Mod(data, "int", 2, 0)'
	query @{int=@{'$mod'=2, 0L}} 1 '{ "int" : { "$mod" : [2, NumberLong(0)] } }' 'Mod(data, "int", 2, 0)'
	query @{int=@{'$mod'=2.1, 0.1}} 1 '{ "int" : { "$mod" : [2.1, 0.1] } }' 'Mod(data, "int", 2, 0)'
	query @{pi=@{'$mod'=2.1, 1.1}} 1 '{ "pi" : { "$mod" : [2.1, 1.1] } }' 'Mod(data, "pi", 2, 1)'
}

task Size {
	query (New-MdbcQuery null -Size 0) 0 '{ "null" : { "$size" : 0 } }' 'Size(data, "null", 0)'
	query (New-MdbcQuery miss -Size 0) 0 '{ "miss" : { "$size" : 0 } }' 'Size(data, "miss", 0)'
	query (New-MdbcQuery text -Size 0) 0 '{ "text" : { "$size" : 0 } }' 'Size(data, "text", 0)'

	query (New-MdbcQuery three -Size 3) 1 '{ "three" : { "$size" : 3 } }' 'Size(data, "three", 3)'
	query (New-MdbcQuery three -Size 4) 0 '{ "three" : { "$size" : 4 } }' 'Size(data, "three", 4)'

	query @{empty=@{'$size'=$null}} 1 '{ "empty" : { "$size" : null } }' 'Size(data, "empty", 0)'
	query @{three=@{'$size'=3L}} 1 '{ "three" : { "$size" : NumberLong(3) } }' 'Size(data, "three", 3)'
	query @{three=@{'$size'=3.0}} 1 '{ "three" : { "$size" : 3.0 } }' 'Size(data, "three", 3)'
	query @{three=@{'$size'=3.14}} 0 '{ "three" : { "$size" : 3.14 } }' 'Size(data, "three", 3.14)'

	# weird: Mongo treats non numbers as 0
	query @{empty=@{'$size'='text'}} 1 '{ "empty" : { "$size" : "text" } }' 'Size(data, "empty", 0)'
	query @{three=@{'$size'='text'}} 0 '{ "three" : { "$size" : "text" } }' 'Size(data, "three", 0)'
	query @{empty=@{'$size'=$date}} 1 '{ "empty" : { "$size" : ISODate("2000-01-01T00:00:00Z") } }' 'Size(data, "empty", 0)'
	query @{three=@{'$size'=$date}} 0 '{ "three" : { "$size" : ISODate("2000-01-01T00:00:00Z") } }' 'Size(data, "three", 0)'
}

task In {
	# $in and $nin need arrays, so does Mdbc
	Test-Error { Get-MdbcData @{int=@{'$in'=42}} } '*"invalid query"*'
	Test-Error { Get-MdbcData @{int=@{'$nin'=42}} } '*"$nin needs an array"*'

	# $nin is just a negation of $in, so does Mdbc
	assert ((New-MdbcQuery -Not (New-MdbcQuery x -In 1)).ToString() -eq '{ "x" : { "$nin" : [1] } }')

	query (New-MdbcQuery null -In @($null)) 1 '{ "null" : { "$in" : [null] } }' 'In(data, "null", [BsonNull])'
	query (New-MdbcQuery null -NotIn @($null)) 0 '{ "null" : { "$nin" : [null] } }' 'Not(In(data, "null", [BsonNull]))'

	query (New-MdbcQuery miss -In @()) 0 '{ "miss" : { "$in" : [] } }' 'In(data, "miss", [])'
	query (New-MdbcQuery miss -NotIn @()) 1 '{ "miss" : { "$nin" : [] } }' 'Not(In(data, "miss", []))'

	query (New-MdbcQuery int -In 33, 42) 1 '{ "int" : { "$in" : [33, 42] } }' 'In(data, "int", [33, 42])'
	query (New-MdbcQuery int -NotIn 33, 42) 0 '{ "int" : { "$nin" : [33, 42] } }' 'Not(In(data, "int", [33, 42]))'

	query (New-MdbcQuery empty -In @()) 0 '{ "empty" : { "$in" : [] } }' 'In(data, "empty", [])'
	query (New-MdbcQuery empty -NotIn @()) 1 '{ "empty" : { "$nin" : [] } }' 'Not(In(data, "empty", []))'

	query (New-MdbcQuery three -In @(5, 4, 3)) 1 '{ "three" : { "$in" : [5, 4, 3] } }' 'In(data, "three", [5, 4, 3])'
	query (New-MdbcQuery three -NotIn @(5, 4, 3)) 0 '{ "three" : { "$nin" : [5, 4, 3] } }' 'Not(In(data, "three", [5, 4, 3]))'

	query (New-MdbcQuery int -In 33, 42L) 1 '{ "int" : { "$in" : [33, NumberLong(42)] } }' 'In(data, "int", [33, 42])'
	query (New-MdbcQuery int -NotIn 33, 42L) 0 '{ "int" : { "$nin" : [33, NumberLong(42)] } }' 'Not(In(data, "int", [33, 42]))'

	query (New-MdbcQuery int -In 33, 42.0) 1 '{ "int" : { "$in" : [33, 42.0] } }' 'In(data, "int", [33, 42])'
	query (New-MdbcQuery int -NotIn 33, 42.0) 0 '{ "int" : { "$nin" : [33, 42.0] } }' 'Not(In(data, "int", [33, 42]))'
}

task All {
	# $all needs arrays, so does Mdbc
	Test-Error { Get-MdbcData @{three=@{'$all'=42}} } '*"$all requires array"*'

	# false if array is empty
	query (New-MdbcQuery int -All @()) 0 '{ "int" : { "$all" : [] } }' 'All(data, "int", [])'
	query (New-MdbcQuery miss -All @()) 0 '{ "miss" : { "$all" : [] } }' 'All(data, "miss", [])'
	query (New-MdbcQuery empty -All @()) 0 '{ "empty" : { "$all" : [] } }' 'All(data, "empty", [])'

	query (New-MdbcQuery int -All @(42.0, 42.0)) 1 '{ "int" : { "$all" : [42.0, 42.0] } }' 'All(data, "int", [42, 42])'
	query (New-MdbcQuery int -All @(42.0, 42.0, 1)) 0 '{ "int" : { "$all" : [42.0, 42.0, 1] } }' 'All(data, "int", [42, 42, 1])'

	query (New-MdbcQuery three -All @(1, 2)) 1 '{ "three" : { "$all" : [1, 2] } }' 'All(data, "three", [1, 2])'
	query (New-MdbcQuery three -All @(1, 2, 4)) 0 '{ "three" : { "$all" : [1, 2, 4] } }' 'All(data, "three", [1, 2, 4])'
}

task ElemMatch {
	query (New-MdbcQuery doc1 -ElemMatch (New-MdbcQuery -And @{x=1}, @{y=2})) 0 `
	'{ "doc1" : { "$elemMatch" : { "x" : 1, "y" : 2 } } }' 'ElemMatch(data, "doc1", value(System.Func`2[MongoDB.Bson.BsonDocument,System.Boolean]))'

	query (New-MdbcQuery doc2 -ElemMatch (New-MdbcQuery -And @{x=1}, @{y=2})) 1 `
	'{ "doc2" : { "$elemMatch" : { "x" : 1, "y" : 2 } } }' 'ElemMatch(data, "doc2", value(System.Func`2[MongoDB.Bson.BsonDocument,System.Boolean]))'

	query (New-MdbcQuery doc2 -ElemMatch (New-MdbcQuery -And @{x=1}, @{y=3})) 0 `
	'{ "doc2" : { "$elemMatch" : { "x" : 1, "y" : 3 } } }' 'ElemMatch(data, "doc2", value(System.Func`2[MongoDB.Bson.BsonDocument,System.Boolean]))'
}

task Not {
	query @{int=@{'$not'=@{'$gt'=99}}} 1 '{ "int" : { "$not" : { "$gt" : 99 } } }' 'Not(GT(data, "int", 99))'
	query @{int=@{'$not'=@{'$lt'=99}}} 0 '{ "int" : { "$not" : { "$lt" : 99 } } }' 'Not(LT(data, "int", 99))'

	query @{miss=@{'$not'=@{'$gt'=99}}} 1 '{ "miss" : { "$not" : { "$gt" : 99 } } }' 'Not(GT(data, "miss", 99))'
	query @{miss=@{'$not'=@{'$exists'=1}}} 1 '{ "miss" : { "$not" : { "$exists" : 1 } } }' 'Not((data.Contains("miss") == True))'
	query @{miss=@{'$not'=@{'$exists'=0}}} 0 '{ "miss" : { "$not" : { "$exists" : 0 } } }' 'Not((data.Contains("miss") == False))'
}

task Empty {
	query @{} 1 '{ }' 'True'
}

task Nested {
	# nested document
	query (New-MdbcQuery doc1.deep.x 9) 1 '{ "doc1.deep.x" : 9 }' 'EQ(data, "doc1.deep.x", 9)'

	# array of documents
	query (New-MdbcQuery doc2.deep.x 9) 1 '{ "doc2.deep.x" : 9 }' 'EQ(data, "doc2.deep.x", 9)'
	query (New-MdbcQuery doc2.deep.x '9') 0 '{ "doc2.deep.x" : "9" }' 'EQ(data, "doc2.deep.x", 9)'

	# index
	query (New-MdbcQuery arr1.1 42) 1 '{ "arr1.1" : 42 }' 'EQ(data, "arr1.1", 42)'
	query (New-MdbcQuery arr1.2.x 33) 1 '{ "arr1.2.x" : 33 }' 'EQ(data, "arr1.2.x", 33)'

	# index out of range
	query (New-MdbcQuery arr1.-1 42) 0 '{ "arr1.-1" : 42 }' 'EQ(data, "arr1.-1", 42)'
	query (New-MdbcQuery arr1.99 42) 0 '{ "arr1.99" : 42 }' 'EQ(data, "arr1.99", 42)'

	# key looks like index
	query (New-MdbcQuery doc1.1.n 42) 1 '{ "doc1.1.n" : 42 }' 'EQ(data, "doc1.1.n", 42)'
}
