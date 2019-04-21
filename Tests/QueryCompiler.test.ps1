
Enter-Build {
	. .\Zoo.ps1
	Import-Module Mdbc
	Set-StrictMode -Version Latest

	$date = [DateTime]'2000-01-01'
	$guid = [Guid]'94a30dd6-6451-49fb-9c48-18e3f1509877'
	$document = New-MdbcData -NewId @{
		null = $null
		text = 'text'
		int = 42
		intn = -42
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

	Connect-Mdbc -NewCollection
	$document | Add-MdbcData
}

function query(
	$query, # query to be tested
	$count, # sample query result count
	$queryText, # sample native query text
	$expressionText, # sample expression query text
	$QError, # query error sample
	$EError # expression error sample
)
{
	# get and show query text
	if ($query -is [hashtable]) {$query = New-MdbcQuery -And $query}
	$queryText2 = $query.ToString()
	$queryText2

	# run query
	$err = $null
	try {
		$count2 = Get-MdbcData -Count $query
	}
	catch {
		if (!$QError) {Write-Error $_}
		if ($_ -notlike $QError) {Write-Error "`n Query error sample : $QError`n Query error result : $_"}
		$err = $_
	}
	if ($QError -and !$err) {Write-Error "Expected error on query."}

	# test query
	if (!$QError) {
		# 1. test query count
		if ($count -ne $count2) {
			Write-Error "`n Query count sample : $count`n Query count result : $count2"
		}

		# 2. test query text
		if ($queryText -cne $queryText2) {
			Write-Error "`n Query text sample : $queryText`n Query text result : $queryText2"
		}
	}

	# run expression
	$err = $null
	try {
		# get and show expression
		$expression = [Mdbc.QueryCompiler]::GetExpression($query)
		($expressionText2 = $expression.ToString())

		# run expression
		$count2 = [int][Mdbc.QueryCompiler]::GetFunction($expression).Invoke($document)
	}
	catch {
		if (!$EError) {Write-Error $_}
		if ($_ -notlike $EError) {Write-Error "`n Expression error sample : $EError`n Expression error result : $_"}
		$err = $_
	}
	if ($EError -and !$err) {Write-Error "Expected error on expression."}

	# test expression
	if (!$EError) {
		# 1. test expression count
		if ($count -ne $count2) {
			Write-Error "`n Expression count sample : $count`n Expression count result : $count2"
		}

		# 2. test expression text
		if ($expressionText -cne $expressionText2) {
			if ($expressionText -ceq ($expressionText2 -replace '\bvalue\(.+?\)', '...')) {}
			else { Write-Error "`n Expression sample : $expressionText`n Expression result : $expressionText2" }
		}
	}
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
	query (New-MdbcQuery miss -GT $null) 0 '{ "miss" : { "$gt" : null } }' 'GT(data, "miss", BsonNull)'
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
	query (New-MdbcQuery miss -LT $null) 0 '{ "miss" : { "$lt" : null } }' 'LT(data, "miss", BsonNull)'
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

	$query = @{int=[ordered]@{'$ne'=99; '$exists'=1}}

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
	query @{null=@{'$regex'=1}} -QError '*$regex has to be a string*' -EError '*Invalid $regex argument.*'
	query @{null=@{'$regex'=$null}} -QError '*$regex has to be a string*' -EError '*Invalid $regex argument.*'
	query @{miss=@{'$regex'=$null}} -QError '*$regex has to be a string*' -EError '*Invalid $regex argument.*'

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
	query (New-MdbcQuery null -TypeAlias null) 1 '{ "null" : { "$type" : "null" } }' 'Type(data, "null", Null)'

	query (New-MdbcQuery miss -Type Null) 0 '{ "miss" : { "$type" : 10 } }' 'Type(data, "miss", Null)'
	query (New-MdbcQuery miss -TypeAlias null) 0 '{ "miss" : { "$type" : "null" } }' 'Type(data, "miss", Null)'

	query (New-MdbcQuery int -Type Int32) 1 '{ "int" : { "$type" : 16 } }' 'Type(data, "int", Int32)'
	query (New-MdbcQuery int -TypeAlias int) 1 '{ "int" : { "$type" : "int" } }' 'Type(data, "int", Int32)'
	query (New-MdbcQuery int -TypeAlias number) 1 '{ "int" : { "$type" : "number" } }' 'TypeNumber(data, "int")'

	query (New-MdbcQuery int -Type Int64) 0 '{ "int" : { "$type" : 18 } }' 'Type(data, "int", Int64)'
	query (New-MdbcQuery int -TypeAlias long) 0 '{ "int" : { "$type" : "long" } }' 'Type(data, "int", Int64)'

	query @{int=@{'$type'=16.0}} 1 '{ "int" : { "$type" : 16.0 } }' 'Type(data, "int", Int32)'
	query @{int=@{'$type'=16L}} 1 '{ "int" : { "$type" : NumberLong(16) } }' 'Type(data, "int", Int32)'
	query @{int=@{'$type'='int'}} 1 '{ "int" : { "$type" : "int" } }' 'Type(data, "int", Int32)'
	query @{int=@{'$type'='number'}} 1 '{ "int" : { "$type" : "number" } }' 'TypeNumber(data, "int")'

	query @{int=@{'$type'=$null}} -QError '*type must be represented as a number or a string.*' -EError '*$type argument must be number or string.*'
	query @{int=@{'$type'='16'}} -QError '*Unknown type name alias: 16.*' -EError '*Unknown string alias of $type argument.*'
}

task Mod {
	# fixed assert https://jira.mongodb.org/browse/SERVER-11744
	query @{int=@{'$mod'=1}} -QError '*malformed mod, needs to be an array*' -EError '*$mod argument must be array.*'

	# KO item count
	query @{int=@{'$mod'=@()}} -QError '*malformed mod, not enough elements*' -EError '*$mod array must have two items.*'
	query @{int=@{'$mod'=@(2)}} -QError '*malformed mod, not enough elements*' -EError '*$mod array must have two items.*'
	query @{int=@{'$mod'=@(2,0,1)}} -QError '*malformed mod, too many elements*' -EError '*$mod array must have two items.*'

	# KO divisor
	query @{int=@{'$mod'=@(0,1)}} -QError '*divisor cannot be 0*' -EError '*$mod divisor cannot be 0.*'
	query @{int=@{'$mod'=@('bad',1)}} -QError '*malformed mod, divisor not a number*' -EError '*$mod divisor must be number.*'

	# not numbers are treated as 0
	query @{int=@{'$mod'=@(2,'bad')}} 1 '{ "int" : { "$mod" : [2, "bad"] } }' 'Mod(data, "int", 2, 0)'

	# null, miss, text
	query (New-MdbcQuery null -Mod 2, 0) 0 '{ "null" : { "$mod" : [2, 0] } }' 'Mod(data, "null", 2, 0)'
	query (New-MdbcQuery miss -Mod 2, 0) 0 '{ "miss" : { "$mod" : [2, 0] } }' 'Mod(data, "miss", 2, 0)'
	query (New-MdbcQuery text -Mod 2, 0) 0 '{ "text" : { "$mod" : [2, 0] } }' 'Mod(data, "text", 2, 0)'

	# simple
	query (New-MdbcQuery int -Mod 2, 0) 1 '{ "int" : { "$mod" : [2, 0] } }' 'Mod(data, "int", 2, 0)'
	query (New-MdbcQuery int -Mod 2, 1) 0 '{ "int" : { "$mod" : [2, 1] } }' 'Mod(data, "int", 2, 1)'

	# negative
	query (New-MdbcQuery int -Mod -5, 2) 1 '{ "int" : { "$mod" : [-5, 2] } }' 'Mod(data, "int", -5, 2)'
	query (New-MdbcQuery intn -Mod -5, -2) 1 '{ "intn" : { "$mod" : [-5, -2] } }' 'Mod(data, "intn", -5, -2)'

	# long and double
	query @{int=@{'$mod'=2L, 0}} 1 '{ "int" : { "$mod" : [NumberLong(2), 0] } }' 'Mod(data, "int", 2, 0)'
	query @{int=@{'$mod'=2, 0L}} 1 '{ "int" : { "$mod" : [2, NumberLong(0)] } }' 'Mod(data, "int", 2, 0)'
	query @{int=@{'$mod'=2.1, 0.1}} 1 '{ "int" : { "$mod" : [2.1000000000000001, 0.10000000000000001] } }' 'Mod(data, "int", 2, 0)'
	query @{pi=@{'$mod'=2.1, 1.1}} 1 '{ "pi" : { "$mod" : [2.1000000000000001, 1.1000000000000001] } }' 'Mod(data, "pi", 2, 1)'
}

task Size {
	query (New-MdbcQuery null -Size 0) 0 '{ "null" : { "$size" : 0 } }' 'Size(data, "null", 0)'
	query (New-MdbcQuery miss -Size 0) 0 '{ "miss" : { "$size" : 0 } }' 'Size(data, "miss", 0)'
	query (New-MdbcQuery text -Size 0) 0 '{ "text" : { "$size" : 0 } }' 'Size(data, "text", 0)'

	query (New-MdbcQuery three -Size 3) 1 '{ "three" : { "$size" : 3 } }' 'Size(data, "three", 3)'
	query (New-MdbcQuery three -Size 4) 0 '{ "three" : { "$size" : 4 } }' 'Size(data, "three", 4)'

	# KO size v2.6
	query @{empty=@{'$size'=$null}} -QError '*$size needs a number*' -EError '*Invalid $size argument.*'
	query @{empty=@{'$size'=$true}} -QError '*$size needs a number*' -EError '*Invalid $size argument.*'
	query @{empty=@{'$size'=$date}} -QError '*$size needs a number*' -EError '*Invalid $size argument.*'
	query @{empty=@{'$size'=@()}} -QError '*$size needs a number*' -EError '*Invalid $size argument.*'
	query @{empty=@{'$size'=@{}}} -QError '*$size needs a number*' -EError '*Invalid $size argument.*'
	query @{empty=@{'$size'=[regex]''}} -QError '*$size needs a number*' -EError '*Invalid $size argument.*'

	query @{three=@{'$size'=3L}} 1 '{ "three" : { "$size" : NumberLong(3) } }' 'Size(data, "three", 3)'
	query @{three=@{'$size'=3.0}} 1 '{ "three" : { "$size" : 3.0 } }' 'Size(data, "three", 3)'

	$version = Get-ServerVersion
	if ($version -lt ([version]'3.4.1')) {
		Write-Warning 'Skip old v3.2 query tests.'
		return
	}

	# Mongo treated strings as 0 and 3.14 as 3. Fixed in v3.4.1
	query @{empty=@{'$size'='text'}} -QError '*$size needs a number*' -EError '*Invalid $size argument.*'
	query @{empty=@{'$size'='3'}} -QError '*$size needs a number*' -EError '*Invalid $size argument.*'
	query @{three=@{'$size'=3.14}} -QError '*$size must be a whole number*' -EError '*Invalid $size argument.*'
}

task In {
	# $in/$nin needs array
	query @{int=@{'$in'=42}} -QError '*$in needs an array*' -EError '*$in/$nin argument must be array.*'
	query @{int=@{'$nin'=42}} -QError '*$nin needs an array*' -EError '*$in/$nin argument must be array.*'

	# $nin is just a negation of $in, so does Mdbc
	equals (New-MdbcQuery -Not (New-MdbcQuery x -In 1)).ToString() '{ "x" : { "$nin" : [1] } }'

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

	# regex for text
	query (New-MdbcQuery text -In ([regex]'text')) 1 '{ "text" : { "$in" : [/text/] } }' 'In(data, "text", [/text/])'
	query (New-MdbcQuery text -NotIn ([regex]'text')) 0 '{ "text" : { "$nin" : [/text/] } }' 'Not(In(data, "text", [/text/]))'

	# regex for int
	query (New-MdbcQuery int -In ([regex]'42')) 0 '{ "int" : { "$in" : [/42/] } }' 'In(data, "int", [/42/])'
	query (New-MdbcQuery int -NotIn ([regex]'42')) 1 '{ "int" : { "$nin" : [/42/] } }' 'Not(In(data, "int", [/42/]))'
}

task All {
	# $all needs array
	query @{three=@{'$all'=42}} -QError '*$all needs an array*' -EError '*$all argument must be array.*'

	# $elemMatch needs document
	query (New-MdbcQuery doc2 -All @(@{'$elemMatch'=1})) -QError '*$elemMatch needs an Object*' -EError '*$all $elemMatch argument must be document.*'

	# false if array is empty
	query (New-MdbcQuery int -All @()) 0 '{ "int" : { "$all" : [] } }' 'All(data, "int", ...)'
	query (New-MdbcQuery miss -All @()) 0 '{ "miss" : { "$all" : [] } }' 'All(data, "miss", ...)'
	query (New-MdbcQuery empty -All @()) 0 '{ "empty" : { "$all" : [] } }' 'All(data, "empty", ...)'

	query (New-MdbcQuery int -All @(42.0, 42.0)) 1 '{ "int" : { "$all" : [42.0, 42.0] } }' 'All(data, "int", ...)'
	query (New-MdbcQuery int -All @(42.0, 42.0, 1)) 0 '{ "int" : { "$all" : [42.0, 42.0, 1] } }' 'All(data, "int", ...)'

	query (New-MdbcQuery three -All @(1, 2)) 1 '{ "three" : { "$all" : [1, 2] } }' 'All(data, "three", ...)'
	query (New-MdbcQuery three -All @(1, 2, 4)) 0 '{ "three" : { "$all" : [1, 2, 4] } }' 'All(data, "three", ...)'

	# regex
	query (New-MdbcQuery text -All @(([regex]'text'))) 1 '{ "text" : { "$all" : [/text/] } }' 'All(data, "text", ...)'
	query (New-MdbcQuery text -All @(([regex]'miss'))) 0 '{ "text" : { "$all" : [/miss/] } }' 'All(data, "text", ...)'

	# objects
	query (New-MdbcQuery doc2 -All @(@{x=1;y=2})) 1 '{ "doc2" : { "$all" : [{ "y" : 2, "x" : 1 }] } }' 'All(data, "doc2", ...)'
	query (New-MdbcQuery doc2 -All @(@{x=2;y=1})) 0 '{ "doc2" : { "$all" : [{ "y" : 1, "x" : 2 }] } }' 'All(data, "doc2", ...)'

	# $elemMatch

	query (New-MdbcQuery doc2 -All @(@{'$elemMatch'=@{y=@{'$gt'=2}}})) 1 `
	'{ "doc2" : { "$all" : [{ "$elemMatch" : { "y" : { "$gt" : 2 } } }] } }' 'All(data, "doc2", ...)'

	#_131116_140311
	$d = New-MdbcData; $d['$elemMatch'] = @{y=@{'$gt'=2}}; $d.bad = 1
	query (New-MdbcQuery doc2 -All @($d)) 1 '{ "doc2" : { "$all" : [{ "$elemMatch" : { "y" : { "$gt" : 2 } }, "bad" : 1 }] } }' 'All(data, "doc2", ...)'
}

task ElemMatch {
	query @{doc1=@{'$elemMatch'=1}} -QError '*$elemMatch needs an Object*' -EError '*$elemMatch argument must be document.*'

	query (New-MdbcQuery doc1 -ElemMatch (New-MdbcQuery -And @{x=1}, @{y=2})) 0 `
	'{ "doc1" : { "$elemMatch" : { "x" : 1, "y" : 2 } } }' 'ElemMatch(data, "doc1", ...)'

	query (New-MdbcQuery doc2 -ElemMatch (New-MdbcQuery -And @{x=1}, @{y=2})) 1 `
	'{ "doc2" : { "$elemMatch" : { "x" : 1, "y" : 2 } } }' 'ElemMatch(data, "doc2", ...)'

	query (New-MdbcQuery doc2 -ElemMatch (New-MdbcQuery -And @{x=1}, @{y=3})) 0 `
	'{ "doc2" : { "$elemMatch" : { "x" : 1, "y" : 3 } } }' 'ElemMatch(data, "doc2", ...)'
}

task Not {
	query @{int=@{'$not'=1}} -QError '*$not needs a regex or a document*' -EError '*Invalid form of $not.*'

	query @{text=@{'$not'=[regex]'miss'}} 1 '{ "text" : { "$not" : /miss/ } }' 'Not(Matches(data, "text", miss))'
	query @{text=@{'$not'=[regex]'text'}} 0 '{ "text" : { "$not" : /text/ } }' 'Not(Matches(data, "text", text))'

	query @{int=@{'$not'=@{'$gt'=99}}} 1 '{ "int" : { "$not" : { "$gt" : 99 } } }' 'Not(GT(data, "int", 99))'
	query @{int=@{'$not'=@{'$lt'=99}}} 0 '{ "int" : { "$not" : { "$lt" : 99 } } }' 'Not(LT(data, "int", 99))'

	query @{miss=@{'$not'=@{'$gt'=99}}} 1 '{ "miss" : { "$not" : { "$gt" : 99 } } }' 'Not(GT(data, "miss", 99))'
	query @{miss=@{'$not'=@{'$exists'=1}}} 1 '{ "miss" : { "$not" : { "$exists" : 1 } } }' 'Not((data.Contains("miss") == True))'
	query @{miss=@{'$not'=@{'$exists'=0}}} 0 '{ "miss" : { "$not" : { "$exists" : 0 } } }' 'Not((data.Contains("miss") == False))'

	$$ = New-MdbcData; $$['$gt'] = 99; $$['$gte'] = 99
	query @{int=@{'$not'=$$}} 1 '{ "int" : { "$not" : { "$gt" : 99, "$gte" : 99 } } }' 'Not((GT(data, "int", 99) And GTE(data, "int", 99)))'
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
