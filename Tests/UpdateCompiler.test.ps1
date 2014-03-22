
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version Latest

function update (
	[Parameter(Position=0)]$Update, # update for the document
	[Parameter(Position=1)]$Document, # document to be updated
	[Parameter(Position=2)]$Sample, # updated document sample
	[Parameter(Position=3)]$ExpressionText, # update expression sample
	$Query, # query used on upsert update
	$UError, # update error wildcard
	$EError # expression error wildcard
)
{
	Connect-Mdbc -NewCollection
	if ($Query) {
		$Query = [MongoDB.Driver.QueryDocument]$Query
	}
	else {
		$Document | Add-MdbcData
	}

	# base update
	$err = $null
	try {
		if ($Query) {
			Update-MdbcData -Update $Update -Query $Query -Add
		}
		else {
			Update-MdbcData -Update $Update -Query @{}
		}
		$r = Get-MdbcData
		if (!$r) {Write-Error "No data after update."}
		$r.Remove('_id')
		$r.ToString()
	}
	catch {
		if (!$UError) {Write-Error $_}
		if ($_ -notlike $UError) {Write-Error "`n Update error sample : $UError`n Update error result : $_"}
		$err = $_
	}
	if ($UError -and !$err) {Write-Error "Expected error on update."}

	# test base result
	if (!$UError) {
		try { Test-Table $Sample $r -Force }
		catch { Write-Error "Update sample vs. result : $_" }
	}

	# linq update
	$err = $null
	try {
		if ($Update -is [Hashtable]) { $Update = New-MdbcData $Update }
		$expression = [Mdbc.UpdateCompiler]::GetExpression($Update, $Query, $Query)
		$Document = New-MdbcData $Document
		$null = [Mdbc.UpdateCompiler]::GetFunction($expression).Invoke($Document.ToBsonDocument())
		$Document.ToString()
	}
	catch {
		if (!$EError) {Write-Error $_}
		if ($_ -notlike $EError) {Write-Error "`n Expression error sample : $EError`n Expression error result : $_"}
		$err = $_
	}
	if ($EError -and !$err) {Write-Error "Expected error on expression."}

	# test linq result
	if (!$EError) {
		try { Test-Table $Sample $Document -Force }
		catch { Write-Error "Expression sample vs. result : $_" }

		# test linq text
		$expressionText2 = $expression.ToString().Substring('value(Mdbc.UpdateCompiler)'.Length)
		$expressionText2
		if ($ExpressionText -cne $expressionText2) {
			Write-Error "`n Expression text sample : $ExpressionText`n Expression text result : $expressionText2"
		}
	}
}

task Conflict {
	update (New-MdbcUpdate -Unset a.1 -Pull @{a=1}) @{a=1,2} -UError "*Cannot update 'a.1' and 'a'*" -EError '*Conflicting fields "a.1" and "a".*'
	update (New-MdbcUpdate -Unset a -Pull @{'a.1'=1}) @{a=1,2} -UError "*Cannot update 'a' and 'a.1'*" -EError '*Conflicting fields "a" and "a.1".*'
}

task Unset {
	# simple
	update (New-MdbcUpdate -Unset x) @{x=1; y=2} @{y=2} '.Unset(data, "x")'

	# unset missing
	update (New-MdbcUpdate -Unset miss) @{x=1} @{x=1} '.Unset(data, "miss")'

	# x.y.z where y is not document is fine
	update (New-MdbcUpdate -Unset x.y.z) @{x=@{y=1}} @{x=@{y=1}} '.Unset(data, "x.y.z")'

	# a.x where a is array is fine
	update (New-MdbcUpdate -Unset 'a.x') @{a=@{x=1},@{x=1}} @{a=@{x=1},@{x=1}} '.Unset(data, "a.x")'

	# unset nested
	update (New-MdbcUpdate -Unset x.y) @{x=@{y=@{z=1}}} @{x=@{}} '.Unset(data, "x.y")'
	update (New-MdbcUpdate -Unset x.y.z) @{x=@{y=@{z=1}}} @{x=@{y=@{}}} '.Unset(data, "x.y.z")'

	# unset a.1
	update (New-MdbcUpdate -Unset a.1) @{a=1,2,3} @{a=1,$null,3} '.Unset(data, "a.1")'

	# unset a.1.x
	update (New-MdbcUpdate -Unset a.1.x) @{a=1,@{x=1;y=1},3} @{a=1,@{y=1},3} '.Unset(data, "a.1.x")'

	# unset a.<out>
	#_140322_154514 https://jira.mongodb.org/browse/SERVER-13317
	update (New-MdbcUpdate -Unset a.-2) @{a=1,2} @{a=1,2} '.Unset(data, "a.-2")'
	update (New-MdbcUpdate -Unset a.99) @{a=1,2} @{a=1,2} '.Unset(data, "a.99")'
}

task CurrentDate {
	$now = [datetime]::Now

	# simple
	update (New-MdbcUpdate -CurrentDate x) @{x=1} @{x=$now} '.CurrentDate(data, "x")'

	# missing
	update (New-MdbcUpdate -CurrentDate miss) @{} @{miss=$now} '.CurrentDate(data, "miss")'

	# array.less
	update (New-MdbcUpdate -CurrentDate a.-1) @{a=1,2} -UError '*cannot use the part (a of a.-1)*' -EError '*Cannot insert at index (-1).*'

	# array.more
	update (New-MdbcUpdate -CurrentDate a.3) @{a=1,2} @{a=1,2,$null,$now} '.CurrentDate(data, "a.3")'

	# array.1
	update (New-MdbcUpdate -CurrentDate a.1) @{a=1,2} @{a=1,$now} '.CurrentDate(data, "a.1")'
}

task Rename {
	# rename two
	update (New-MdbcUpdate -Rename @{x='y'}) @{x=1} @{y=1} '.Rename(data, "x", "y")'

	# rename to existing
	update (New-MdbcUpdate -Rename @{x='existing'}) @{x='x'; existing=42} @{existing='x'} '.Rename(data, "x", "existing")'

	# rename missing
	update (New-MdbcUpdate -Rename @{miss='y'}) @{x=1} @{x=1} '.Rename(data, "miss", "y")'

	# rename nested
	update (New-MdbcUpdate -Rename @{'x.y'='x.z'}) @{x=@{y=1}} @{x=@{z=1}} '.Rename(data, "x.y", "x.z")'

	# move nested
	update (New-MdbcUpdate -Rename @{'d1.p1'='d2.p3'}) @{d1=@{p1=1}; d2=@{p2=2}} @{d1=@{}; d2=@{p2=2; p3=1}} '.Rename(data, "d1.p1", "d2.p3")'

	# rename a.1.x, _131028_234439
	update (New-MdbcUpdate -Rename @{'a.1.x'='a.1.z'}) @{a=1,@{x=1;y=1},3} `
	-UError '*The source field cannot be an array element*' -EError '*"Array indexes are not supported."'
}

task Set {
	# errors
	update (New-MdbcUpdate -Set @{'x.y.z'=1}) @{x=@{y=1}} -UError '* 16837,*' -EError '*"Field (y) in (x.y.z) is not a document."'
	update (New-MdbcUpdate -Set @{'a.x'=1}) @{a=@{x=1},@{x=1}} -UError '* 16837,*' -EError '*"Field (a) in (a.x) is not a document."'
	update @{x=1; '$inc'=@{y=2}} @{} -UError "*'Unknown modifier: x'.*" -EError '*Update cannot mix operators and fields.*' #_131103_204607

	# v2.6 error
	update @{x=@{'$bad'=1}} @{} @{x=@{'$bad'=1}} `
	-UError '*The dollar ($) prefixed field * is not valid for storage.*' -EError '*Invalid document element name: "$bad".*'
	# ditto, nested
	update @{x=@{'$bad'=1}} @{} @{x=@{x=@{'$bad'=1}}} `
	-UError '*The dollar ($) prefixed field * is not valid for storage.*' -EError '*Invalid document element name: "$bad".*'

	#_131103_204607 simple form
	update @{x=1; y=2} @{} @{x=1; y=2} '.Set(data, "y", 2).Set(data, "x", 1)'

	# set two
	update (New-MdbcUpdate -Set @{x=1; y=2}) @{} @{x=1; y=2} '.Set(data, "y", 2).Set(data, "x", 1)'

	# set nested
	update (New-MdbcUpdate -Set @{'x.y'=42}) @{x=@{y=1}} @{x=@{y=42}} '.Set(data, "x.y", 42)'

	# new nested
	update (New-MdbcUpdate -Set @{'x.y.z'=42}) @{} @{x=@{y=@{z=42}}} '.Set(data, "x.y.z", 42)'

	# set a.1
	update (New-MdbcUpdate -Set @{'a.1'=42}) @{a=1,2} @{a=1,42} '.Set(data, "a.1", 42)'

	# set a.<less>
	update (New-MdbcUpdate -Set @{'a.-1'=42}) @{a=1,2} -UError '*cannot use the part (a of a.-1)*' -EError '*Cannot insert at index (-1).*'

	# set a.<more>
	update (New-MdbcUpdate -Set @{'a.3'=42}) @{a=1,2} @{a=1,2,$null,42} '.Set(data, "a.3", 42)'

	# set a.1.x
	update (New-MdbcUpdate -Set @{'a.1.x'=42}) @{a=0,@{x=1;y=1}} @{a=0,@{x=42;y=1}} '.Set(data, "a.1.x", 42)'

	# set a.1.x, error [1] is not document
	update (New-MdbcUpdate -Set @{'a.1.x'=42}) @{a=0,1} -UError '* 16837,*' -EError '*"Array item at (1) in (a.1.x) is not a document."'

	# set a.<less>.x
	update (New-MdbcUpdate -Set @{'a.-2.x'=42}) @{a=0,@{x=1}} -UError '*cannot use the part (a of a.-2.x)*' -EError '*Cannot insert at index (-2).*'

	# set a.<more>.x
	update (New-MdbcUpdate -Set @{'a.3.x'=42}) @{a=0,@{x=1}} @{a=0,@{x=1},$null,@{x=42}} '.Set(data, "a.3.x", 42)'
}

task SetOnInsert {
	# not insert
	update (New-MdbcUpdate -SetOnInsert @{x=42}) @{} @{} ''

	# insert
	update (New-MdbcUpdate -SetOnInsert @{x=42}) @{} @{x=42; y=2} -Query @{y=2} '.Set(data, "y", 2).Set(data, "x", 42)'

	# v2.6 fails
	update (New-MdbcUpdate -SetOnInsert @{x=@{'$bad'=1}}) @{} -Query @{y=2} `
	-UError '*The dollar ($) prefixed field * is not valid for storage.*' -EError '*Invalid document element name: "$bad".*'

	#TODO v2.6 fails, Mdbc works _140223_223449
	update (New-MdbcUpdate -SetOnInsert @{x=42}) @{} @{x=42} -Query @{y=@{'$bad'=1}} `
	-UError '*unknown operator: $bad*' '.Set(data, "x", 42)'

	# fixed v2.6 https://jira.mongodb.org/browse/SERVER-12852
	update (New-MdbcUpdate -SetOnInsert @{x=42}) @{} -Query @{y=@{y=@{'$bad'=1}}} `
	-UError '*The dollar ($) prefixed field * is not valid for storage.*' -EError '*Invalid document element name: "$bad".*'

	# fixed v2.6 https://jira.mongodb.org/browse/SERVER-12852
	update (New-MdbcUpdate -SetOnInsert @{x=42}) @{} -Query @{y=@{'bad.1'=1}} `
	-UError '*The dotted field * is not valid for storage.*' -EError '*Invalid document element name: "bad.1".*'

	# v2.6 fails
	update (New-MdbcUpdate -SetOnInsert @{x=42}) @{} -Query @{'$exists'=@{m=1}} `
	-UError '*unknown top level operator: $exists*' -EError '*Unknown top level query operator: ($exists).*'

	# update overrides query
	update (New-MdbcUpdate -Set @{x=42}) @{} @{x=42} -Query @{x=1} '.Set(data, "x", 1).Set(data, "x", 42)'

	# two fields in query
	update (New-MdbcUpdate -Set @{x=42}) @{} @{x=42;y=1;z=1} -Query @{y=1;z=1} '.Set(data, "z", 1).Set(data, "y", 1).Set(data, "x", 42)'
}

task MinMax {
	# missing
	update (New-MdbcUpdate -Min @{miss=1}) @{} @{miss=1} '.Min(data, "miss", 1)'
	update (New-MdbcUpdate -Max @{miss=1}) @{} @{miss=1} '.Max(data, "miss", 1)'

	# updated
	update (New-MdbcUpdate -Min @{x=1}) @{x=2} @{x=1} '.Min(data, "x", 1)'
	update (New-MdbcUpdate -Max @{x=2}) @{x=1} @{x=2} '.Max(data, "x", 2)'

	# not updated
	update (New-MdbcUpdate -Min @{x=3}) @{x=2} @{x=2} '.Min(data, "x", 3)'
	update (New-MdbcUpdate -Max @{x=2}) @{x=3} @{x=3} '.Max(data, "x", 2)'

	# array.less
	$a = @{Document=@{a=2,2}; UError='*cannot use the part (a of a.-1)*'; EError='*Cannot insert at index (-1).*'}
	update (New-MdbcUpdate -Min @{'a.-1'=1}) @a
	update (New-MdbcUpdate -Max @{'a.-1'=1}) @a

	# array.more
	update (New-MdbcUpdate -Min @{'a.3'=1}) @{a=2,2} @{a=2,2,$null,1} '.Min(data, "a.3", 1)'
	update (New-MdbcUpdate -Max @{'a.3'=1}) @{a=2,2} @{a=2,2,$null,1} '.Max(data, "a.3", 1)'

	# array.1 updated
	update (New-MdbcUpdate -Min @{'a.1'=1}) @{a=2,2} @{a=2,1} '.Min(data, "a.1", 1)'
	update (New-MdbcUpdate -Max @{'a.1'=3}) @{a=2,2} @{a=2,3} '.Max(data, "a.1", 3)'

	# array.1 not updated
	update (New-MdbcUpdate -Min @{'a.1'=3}) @{a=2,2} @{a=2,2} '.Min(data, "a.1", 3)'
	update (New-MdbcUpdate -Max @{'a.1'=1}) @{a=2,2} @{a=2,2} '.Max(data, "a.1", 1)'
}

task Inc {
	# missing
	update (New-MdbcUpdate -Inc @{miss=1}) @{} @{miss=1} '.Inc(data, "miss", 1)'

	# int += int -> int
	update (New-MdbcUpdate -Inc @{x=1}) @{x=1} @{x=2} '.Inc(data, "x", 1)'

	# int += long -> long
	update (New-MdbcUpdate -Inc @{x=1L}) @{x=1} @{x=2L} '.Inc(data, "x", 1)'
	update (New-MdbcUpdate -Inc @{x=[long][int]::MaxValue}) @{x=1} @{x=[long][int]::MaxValue + 1} '.Inc(data, "x", 2147483647)'

	# int += double -> double
	update (New-MdbcUpdate -Inc @{x=1.0}) @{x=1} @{x=2.0} '.Inc(data, "x", 1)'
	update (New-MdbcUpdate -Inc @{x=1.1}) @{x=1} @{x=2.1} '.Inc(data, "x", 1.1)'

	# long += int -> long
	update (New-MdbcUpdate -Inc @{x=1}) @{x=1L} @{x=2L} '.Inc(data, "x", 1)'

	# long += long -> long
	update (New-MdbcUpdate -Inc @{x=1L}) @{x=1L} @{x=2L} '.Inc(data, "x", 1)'

	# long += double -> double
	update (New-MdbcUpdate -Inc @{x=1.0}) @{x=1L} @{x=2.0} '.Inc(data, "x", 1)'

	# double += int -> double
	update (New-MdbcUpdate -Inc @{x=1}) @{x=1.0} @{x=2.0} '.Inc(data, "x", 1)'

	# double += long -> double
	update (New-MdbcUpdate -Inc @{x=1L}) @{x=1.0} @{x=2.0} '.Inc(data, "x", 1)'

	# double += double -> double
	update (New-MdbcUpdate -Inc @{x=1.0}) @{x=1.0} @{x=2.0} '.Inc(data, "x", 1)'

	# source is not numeric
	update (New-MdbcUpdate -Inc @{x=1}) @{x=$null} -UError '*Cannot apply $inc to a value of non-numeric type.*' -EError '*Field "x" must be numeric.*'
	update (New-MdbcUpdate -Inc @{x=1}) @{x='bad'} -UError '*Cannot apply $inc to a value of non-numeric type.*' -EError '*Field "x" must be numeric.*'
	update (New-MdbcUpdate -Inc @{'a.1'=1}) @{a=1,'2'} -UError '*Cannot apply $inc to a value of non-numeric type.*' -EError '*Item "a.1" must be numeric.*'

	# value is not numeric
	Test-Error {New-MdbcUpdate -Inc @{x=$null}} '*Exception setting "Inc": "Invalid type. Expected types: int, long, double."'
	update @{'$inc'=@{x=$null}} -UError '*Cannot increment with non-numeric argument:*' -EError '*"Increment value must be numeric."'
	update @{'$inc'=@{x='bad'}} -UError '*Cannot increment with non-numeric argument:*' -EError '*"Increment value must be numeric."'

	# nested
	update (New-MdbcUpdate -Inc @{'x.deep'=-1}, @{'x.miss'=-1}) @{x=@{deep=-1}} @{x=@{deep=-2; miss=-1}} '.Inc(data, "x.deep", -1).Inc(data, "x.miss", -1)'

	# a.1
	update (New-MdbcUpdate -Inc @{'a.1'=1}) @{a=1,2,3} @{a=1,3,3} '.Inc(data, "a.1", 1)'

	# a.<less>
	update (New-MdbcUpdate -Inc @{'a.-2'=42}) @{a=1,2} -UError '*cannot use the part (a of a.-2)*' -EError '*Cannot insert at index (-2).*'

	# a.<more>
	update (New-MdbcUpdate -Inc @{'a.3'=42}) @{a=1,2} @{a=1,2,$null,42} '.Inc(data, "a.3", 42)'

	# a.1.x
	update (New-MdbcUpdate -Inc @{'a.1.x'=1}) @{a=1,@{x=2},3} @{a=1,@{x=3},3} '.Inc(data, "a.1.x", 1)'

	# a.<less>.x
	update (New-MdbcUpdate -Inc @{'a.-2.x'=1}) @{a=1,2} -UError '*cannot use the part (a of a.-2.x)*' -EError '*Cannot insert at index (-2).*'

	# a.<more>.x
	update (New-MdbcUpdate -Inc @{'a.3.x'=1}) @{a=1,2} @{a=1,2,$null,@{x=1}} '.Inc(data, "a.3.x", 1)'
}

task Mul {
	# missing
	update (New-MdbcUpdate -Mul @{miss=1}) @{} @{miss=0} '.Mul(data, "miss", 1)'
	update (New-MdbcUpdate -Mul @{miss=1L}) @{} @{miss=0L} '.Mul(data, "miss", 1)'
	update (New-MdbcUpdate -Mul @{miss=1.0}) @{} @{miss=0.0} '.Mul(data, "miss", 1)'

	# int *= int -> int
	update (New-MdbcUpdate -Mul @{x=2}) @{x=3} @{x=6} '.Mul(data, "x", 2)'

	# int *= long -> long
	update (New-MdbcUpdate -Mul @{x=2L}) @{x=3} @{x=6L} '.Mul(data, "x", 2)'

	# int *= double -> double
	update (New-MdbcUpdate -Mul @{x=2.0}) @{x=3} @{x=6.0} '.Mul(data, "x", 2)'
	update (New-MdbcUpdate -Mul @{x=2.2}) @{x=3} @{x=6.6000000000000005} '.Mul(data, "x", 2.2)'

	# long *= int -> long
	update (New-MdbcUpdate -Mul @{x=2}) @{x=3L} @{x=6L} '.Mul(data, "x", 2)'

	# long *= long -> long
	update (New-MdbcUpdate -Mul @{x=2L}) @{x=3L} @{x=6L} '.Mul(data, "x", 2)'

	# long *= double -> double
	update (New-MdbcUpdate -Mul @{x=2.0}) @{x=3L} @{x=6.0} '.Mul(data, "x", 2)'

	# double *= int -> double
	update (New-MdbcUpdate -Mul @{x=2}) @{x=3.0} @{x=6.0} '.Mul(data, "x", 2)'

	# double *= long -> double
	update (New-MdbcUpdate -Mul @{x=2L}) @{x=3.0} @{x=6.0} '.Mul(data, "x", 2)'

	# double *= double -> double
	update (New-MdbcUpdate -Mul @{x=2.0}) @{x=3.0} @{x=6.0} '.Mul(data, "x", 2)'

	# source is not numeric
	update (New-MdbcUpdate -Mul @{x=1}) @{x=$null} -UError '*Cannot apply $mul to a value of non-numeric type.*' -EError '*Field "x" must be numeric.*'
	update (New-MdbcUpdate -Mul @{x=1}) @{x='bad'} -UError '*Cannot apply $mul to a value of non-numeric type.*' -EError '*Field "x" must be numeric.*'
	update (New-MdbcUpdate -Mul @{'a.1'=1}) @{a=1,'2'} -UError '*Cannot apply $mul to a value of non-numeric type.*' -EError '*Item "a.1" must be numeric.*'

	# value is not numeric
	Test-Error {New-MdbcUpdate -Mul @{x=$null}} '*Exception setting "Mul": "Invalid type. Expected types: int, long, double."'
	# fixed v2.6 https://jira.mongodb.org/browse/SERVER-12945
	update @{'$mul'=@{x=$null}} -UError '*Cannot multiply with non-numeric argument:*' -EError '*"Multiply value must be numeric."'
	update @{'$mul'=@{x='bad'}} -UError '*Cannot multiply with non-numeric argument:*' -EError '*"Multiply value must be numeric."'

	# nested
	update (New-MdbcUpdate -Mul @{'x.deep'=-2}, @{'x.miss'=-3}) @{x=@{deep=-2}} @{x=@{deep=4; miss=0}} '.Mul(data, "x.deep", -2).Mul(data, "x.miss", -3)'
	update (New-MdbcUpdate -Mul @{'x.deep'=-2.0}, @{'x.miss'=-3.0}) @{x=@{deep=-2}} @{x=@{deep=4.0; miss=0.0}} '.Mul(data, "x.deep", -2).Mul(data, "x.miss", -3)'

	# a.1
	update (New-MdbcUpdate -Mul @{'a.1'=2}) @{a=1,2,3} @{a=1,4,3} '.Mul(data, "a.1", 2)'

	# a.<less>
	update (New-MdbcUpdate -Mul @{'a.-2'=42}) @{a=1,2} -UError '*cannot use the part (a of a.-2)*' -EError '*Cannot insert at index (-2).*'

	# a.<more>
	update (New-MdbcUpdate -Mul @{'a.3'=42}) @{a=1,2} @{a=1,2,$null,0} '.Mul(data, "a.3", 42)'
	update (New-MdbcUpdate -Mul @{'a.3'=42L}) @{a=1,2} @{a=1,2,$null,0L} '.Mul(data, "a.3", 42)'
	update (New-MdbcUpdate -Mul @{'a.3'=42.0}) @{a=1,2} @{a=1,2,$null,0.0} '.Mul(data, "a.3", 42)'

	# a.1.x
	update (New-MdbcUpdate -Mul @{'a.1.x'=2}) @{a=1,@{x=2},3} @{a=1,@{x=4},3} '.Mul(data, "a.1.x", 2)'

	# a.<less>.x
	update (New-MdbcUpdate -Mul @{'a.-2.x'=2}) @{a=1,2} -UError '*cannot use the part (a of a.-2.x)*' -EError '*Cannot insert at index (-2).*'

	# a.<more>.x
	update (New-MdbcUpdate -Mul @{'a.3.x'=2}) @{a=1,2} @{a=1,2,$null,@{x=0}} '.Mul(data, "a.3.x", 2)'
	update (New-MdbcUpdate -Mul @{'a.3.x'=2L}) @{a=1,2} @{a=1,2,$null,@{x=0L}} '.Mul(data, "a.3.x", 2)'
	update (New-MdbcUpdate -Mul @{'a.3.x'=2.0}) @{a=1,2} @{a=1,2,$null,@{x=0.0}} '.Mul(data, "a.3.x", 2)'
}

task Bitwise {
	# int32 x int32
	update (New-MdbcUpdate -BitwiseAnd @{n=2}) @{n=3} @{n=2} '.BitwiseAnd(data, "n", 2)'
	update (New-MdbcUpdate -BitwiseOr @{n=2}) @{n=3} @{n=3} '.BitwiseOr(data, "n", 2)'
	update (New-MdbcUpdate -BitwiseXor @{n=2}) @{n=3} @{n=1} '.BitwiseXor(data, "n", 2)'

	# int64 x int64
	update (New-MdbcUpdate -BitwiseAnd @{n=2L}) @{n=3L} @{n=2L} '.BitwiseAnd(data, "n", 2)'
	update (New-MdbcUpdate -BitwiseOr @{n=2L}) @{n=3L} @{n=3L} '.BitwiseOr(data, "n", 2)'
	update (New-MdbcUpdate -BitwiseXor @{n=2L}) @{n=3L} @{n=1L} '.BitwiseXor(data, "n", 2)'

	# int64 x int32
	update (New-MdbcUpdate -BitwiseAnd @{n=2}) @{n=3L} @{n=2L} '.BitwiseAnd(data, "n", 2)'
	update (New-MdbcUpdate -BitwiseOr @{n=2}) @{n=3L} @{n=3L} '.BitwiseOr(data, "n", 2)'
	update (New-MdbcUpdate -BitwiseXor @{n=2}) @{n=3L} @{n=1L} '.BitwiseXor(data, "n", 2)'

	#! v2.6 int32 x int64
	update (New-MdbcUpdate -BitwiseAnd @{n=5gb+1}) @{n=1} @{n=1L} '.BitwiseAnd(data, "n", 5368709121)'
	update (New-MdbcUpdate -BitwiseAnd @{n=1L}) @{n=1} @{n=1L} '.BitwiseAnd(data, "n", 1)'
	update (New-MdbcUpdate -BitwiseOr @{n=5gb+1}) @{n=1} @{n=5368709121} '.BitwiseOr(data, "n", 5368709121)'
	update (New-MdbcUpdate -BitwiseOr @{n=1L}) @{n=1} @{n=1L} '.BitwiseOr(data, "n", 1)'
	update (New-MdbcUpdate -BitwiseXor @{n=5gb+1}) @{n=1} @{n=5368709120} '.BitwiseXor(data, "n", 5368709121)'
	update (New-MdbcUpdate -BitwiseXor @{n=1L}) @{n=1} @{n=0L} '.BitwiseXor(data, "n", 1)'

	# bad
	$a = @{Document=@{x='3'}; UError='*Cannot apply $bit to a value of non-integral type.*'; EError='*Field "x" must be Int32 or Int64.*'}
	update (New-MdbcUpdate -BitwiseAnd @{'x'=2}) @a
	update (New-MdbcUpdate -BitwiseOr @{'x'=2}) @a
	update (New-MdbcUpdate -BitwiseXor @{'x'=2}) @a

	# bad
	$a = @{Document=@{a=3,'3'}; UError='*Cannot apply $bit to a value of non-integral type.*'; EError='*Item "a.1" must be Int32 or Int64.*'}
	update (New-MdbcUpdate -BitwiseAnd @{'a.1'=2}) @a
	update (New-MdbcUpdate -BitwiseOr @{'a.1'=2}) @a
	update (New-MdbcUpdate -BitwiseXor @{'a.1'=2}) @a

	# array item

	$a = @{Document=@{a=3,'3'}; UError='*cannot use the part (a of a.-1)*'; EError='*Cannot insert at index (-1).*'}
	update (New-MdbcUpdate -BitwiseAnd @{'a.-1'=2}) @a
	update (New-MdbcUpdate -BitwiseOr @{'a.-1'=2}) @a
	update (New-MdbcUpdate -BitwiseXor @{'a.-1'=2}) @a

	update (New-MdbcUpdate -BitwiseAnd @{'a.2'=2}) @{a=3,3} @{a=3,3,0} '.BitwiseAnd(data, "a.2", 2)'
	update (New-MdbcUpdate -BitwiseOr @{'a.2'=2}) @{a=3,3} @{a=3,3,2} '.BitwiseOr(data, "a.2", 2)'
	update (New-MdbcUpdate -BitwiseXor @{'a.2'=2}) @{a=3,3} @{a=3,3,2} '.BitwiseXor(data, "a.2", 2)'

	update (New-MdbcUpdate -BitwiseAnd @{'a.3'=2}) @{a=3,3} @{a=3,3,$null,0} '.BitwiseAnd(data, "a.3", 2)'
	update (New-MdbcUpdate -BitwiseOr @{'a.3'=2}) @{a=3,3} @{a=3,3,$null,2} '.BitwiseOr(data, "a.3", 2)'
	update (New-MdbcUpdate -BitwiseXor @{'a.3'=2}) @{a=3,3} @{a=3,3,$null,2} '.BitwiseXor(data, "a.3", 2)'

	update (New-MdbcUpdate -BitwiseAnd @{'a.1'=2}) @{a=3,3} @{a=3,2} '.BitwiseAnd(data, "a.1", 2)'
	update (New-MdbcUpdate -BitwiseOr @{'a.1'=2}) @{a=3,3} @{a=3,3} '.BitwiseOr(data, "a.1", 2)'
	update (New-MdbcUpdate -BitwiseXor @{'a.1'=2}) @{a=3,3} @{a=3,1} '.BitwiseXor(data, "a.1", 2)'
}

task AddToSet {
	# v2.6 error
	update (New-MdbcUpdate -AddToSet @{a=@{'bad.1'=1}}) @{a=@()} `
	-UError '*bad.1 is not valid for storage.*' -EError '*Invalid document element name: "bad.1".*'
	update (New-MdbcUpdate -AddToSetEach @{a=@{'bad.1'=1}}) @{a=@()} `
	-UError '*bad.1 is not valid for storage.*' -EError '*Invalid document element name: "bad.1".*'

	# AddToSet vs. AddToSetEach
	update (New-MdbcUpdate -AddToSet @{a=1,2}) @{a=@()} @{a=@(,@(1,2))} '.AddToSet(data, "a", [1, 2], False)'
	update (New-MdbcUpdate -AddToSet @{a=1,2}) @{a=@(,@(1,2))} @{a=@(,@(1,2))} '.AddToSet(data, "a", [1, 2], False)'
	update (New-MdbcUpdate -AddToSetEach @{a=1,2}) @{a=@()} @{a=1,2} '.AddToSet(data, "a", [1, 2], True)'
	update (New-MdbcUpdate -AddToSetEach @{a=1,2}) @{a=@(,@(1,2))} @{a=@(1,2),1,2} '.AddToSet(data, "a", [1, 2], True)'

	# empty array
	update (New-MdbcUpdate -AddToSet @{a=1}) @{a=@()} @{a=@(1)} '.AddToSet(data, "a", 1, False)'

	# empty array in array
	# fixed v2.6 https://jira.mongodb.org/browse/SERVER-12848
	update (New-MdbcUpdate -AddToSet @{'a.1'=1}) @{a=1,@()} @{a=1,@(1)} '.AddToSet(data, "a.1", 1, False)'

	# value exists
	update (New-MdbcUpdate -AddToSet @{a=1}) @{a=@(1.0)} @{a=@(1.0)} '.AddToSet(data, "a", 1, False)'
	update (New-MdbcUpdate -AddToSet @{'a.1'=1}) @{a=1,@(1.0)} @{a=1,@(1.0)} '.AddToSet(data, "a.1", 1, False)'

	# miss or out or range
	update (New-MdbcUpdate -AddToSet @{miss=1}) @{} @{miss=@(1)} '.AddToSet(data, "miss", 1, False)'
	update (New-MdbcUpdate -AddToSet @{'a.-2'=1}) @{a=1,2} -UError '*cannot use the part (a of a.-2)*' -EError '*Cannot insert at index (-2).*'
	# fixed v2.6 https://jira.mongodb.org/browse/SERVER-12848
	update (New-MdbcUpdate -AddToSet @{'a.3'=1}) @{a=1,2} @{a=1,2,$null,@(1)} '.AddToSet(data, "a.3", 1, False)'

	# m.1.m
	# fixed v2.6 https://jira.mongodb.org/browse/SERVER-12848
	update (New-MdbcUpdate -AddToSet @{'m.1.m'=42}) @{} @{m=@{'1'=@{m=@(42)}}} '.AddToSet(data, "m.1.m", 42, False)'

	# a.1.m
	update (New-MdbcUpdate -AddToSet @{'a.1.m'=42}) @{a=@()} @{a=$null,@{m=@(42)}} '.AddToSet(data, "a.1.m", 42, False)'

	# not array
	update (New-MdbcUpdate -AddToSet @{a=1}) @{a=1} -UError '*Cannot apply $addToSet to a non-array field.*' -EError '*Value "a" must be array.*'
	update (New-MdbcUpdate -AddToSet @{'a.1'=1}) @{a=1,2} -UError '*Cannot apply $addToSet to a non-array field.*' -EError '*Value "a.1" must be array.*'
}

task Pop {
	# pop 0|null|bad ~ Last
	update @{'$pop'=@{a=0}} @{a=1,2,3} @{a=1,2} '.Pop(data, "a", 0)'
	update @{'$pop'=@{a=$null}} @{a=1,2,3} @{a=1,2} '.Pop(data, "a", 0)'
	update @{'$pop'=@{a='bad'}} @{a=1,2,3} @{a=1,2} '.Pop(data, "a", 0)'

	# pop -2
	update @{'$pop'=@{a=-2}} @{a=1,2,3} @{a=2,3} '.Pop(data, "a", -2)'

	# empty
	update (New-MdbcUpdate -PopFirst a) @{a=@()} @{a=@()} '.Pop(data, "a", -1)'
	update (New-MdbcUpdate -PopLast a) @{a=@()} @{a=@()} '.Pop(data, "a", 1)'

	# miss, bad
	update (New-MdbcUpdate -PopFirst miss) @{a=1,2,3} @{a=1,2,3} '.Pop(data, "miss", -1)'
	update (New-MdbcUpdate -PopFirst bad) @{bad=1} -UError '*Can only $pop from arrays.*' -EError '*Value "bad" must be array.*'

	# a.index
	update (New-MdbcUpdate -PopLast a.1) @{a=1,@(1,2)} @{a=1,@(1)} '.Pop(data, "a.1", 1)'
	#_140322_065506
	update (New-MdbcUpdate -PopLast a.-2) @{a=1,2} `
	-UError '*cannot use the part (a of a.-2)*' -EError '*Invalid negative array index in (a.-2).*'
	#fixed _140322_064404 v2.6 https://jira.mongodb.org/browse/SERVER-12846
	update (New-MdbcUpdate -PopLast a.3) @{a=1,2} @{a=1,2} '.Pop(data, "a.3", 1)'
	update (New-MdbcUpdate -PopLast a.1) @{a=1,'bad'} -UError '*Can only $pop from arrays.*' -EError '*Value "a.1" must be array.*'
}

task Pull {
	# numerics
	update (New-MdbcUpdate -Pull @{a=1}) @{a=1,2,3,1,1L,1.0} @{a=2,3} '.Pull(data, "a", 1)'
	update (New-MdbcUpdate -Pull @{a=1}) @{a=1,2,3,1,1L,1.0} @{a=2,3} '.Pull(data, "a", 1)'

	# pull array
	update (New-MdbcUpdate -Pull @{a=1,2}) @{a=1,@(1,2),3} @{a=1,3} '.Pull(data, "a", [1, 2])'
	update (New-MdbcUpdate -PullAll @{a=1,2}) @{a=1,@(1,2),3} @{a=@(1,2),3} '.PullAll(data, "a", [1, 2])'

	# Pull query
	update (New-MdbcUpdate -Pull @{a=@{x=1}}) @{a=1,@{x=1;y=1},3} @{a=1,3} '.Pull(data, "a", { "x" : 1 })'
	#_131130_103226 BsonDocumentWrapper https://jira.mongodb.org/browse/CSHARP-864
	update (New-MdbcUpdate -Pull @{a=New-MdbcQuery x 1}) @{a=1,@{x=1;y=1},3} @{a=1,3} '.Pull(data, "a", { "x" : 1 })'

	# PullAll document
	update @{'$pullAll'=@{a=@{x=1}}} @{} -UError '*$pullAll requires an array argument but*' -EError '*Pull all value must be array.*'
	update (New-MdbcUpdate -PullAll @{a=@{x=1}}) @{a=1,@{x=1;y=1},3} @{a=1,@{x=1;y=1},3} '.PullAll(data, "a", [{ "x" : 1 }])'

	# d.a.1.a
	update (New-MdbcUpdate -Pull @{'d.a.1.a'=2}) @{d=@{a=1,@{a=1,2,3}}} @{d=@{a=1,@{a=1,3}}} '.Pull(data, "d.a.1.a", 2)'

	# a.1|less|more
	update (New-MdbcUpdate -Pull @{'a.1'=1}) @{a=1,@(1,2)} @{a=1,@(2)} '.Pull(data, "a.1", 1)'
	#_140322_065506
	update (New-MdbcUpdate -Pull @{'a.-2'=1}) @{a=1,2} `
	-UError '*cannot use the part (a of a.-2)*' -EError '*Invalid negative array index in (a.-2).*'
	#_140322_065637 v2.6 https://jira.mongodb.org/browse/SERVER-12847
	update (New-MdbcUpdate -Pull @{'a.3'=1}) @{a=1,2} @{a=1,2} '.Pull(data, "a.3", 1)'

	# bad
	update (New-MdbcUpdate -Pull @{b=1}) @{b=1} -UError '*Cannot apply $pull to a non-array value*' -EError '*Value "b" must be array.*'
	update (New-MdbcUpdate -Pull @{'a.1'=1}) @{a=1,'bad'} -UError '*Cannot apply $pull to a non-array value*' -EError '*Value "a.1" must be array.*'

	# miss
	update (New-MdbcUpdate -Pull @{m=1}) @{x=1} @{x=1} '.Pull(data, "m", 1)'
}

task Push {
	# bad field
	update (New-MdbcUpdate -Push @{b=1}) @{b=1} -UError "*The field 'b' must be an array but*" -EError '*Value "b" must be array.*'
	update (New-MdbcUpdate -PushAll @{b=1}) @{b=1} -UError "*The field 'b' must be an array but*" -EError '*Value "b" must be array.*'
	update @{'$push'=@{b=@{'$each'=@(42)}}} @{b=1} -UError "*The field 'b' must be an array but*" -EError '*Value "b" must be array.*'

	# bad argument (but not for New-MdbcUpdate)
	update (New-MdbcUpdate -PushAll @{a=42}) @{a=1,2} @{a=1,2,42} '.PushAll(data, "a", [42], -1)'
	update @{'$pushAll'=@{a=42}} @{} -UError '*$pushAll requires an array of values but*' -EError '*Push all/each value must be array.*'
	update @{'$push'=@{a=@{'$each'=42}}} @{} -UError '*The argument to $each in $push must be an array but*' -EError '*Push all/each value must be array.*'

	# a.1
	update (New-MdbcUpdate -Push @{'a.1'=41,42}) @{a=1,@(1,2)} @{a=1,@(1,2,@(41,42))} '.Push(data, "a.1", [41, 42])'
	update (New-MdbcUpdate -PushAll @{'a.1'=41,42}) @{a=1,@(1,2)} @{a=1,@(1,2,41,42)} '.PushAll(data, "a.1", [41, 42], -1)'

	# miss
	update (New-MdbcUpdate -Push @{'a'=41,42}) @{} @{a=@(,@(41,42))} '.Push(data, "a", [41, 42])'
	update (New-MdbcUpdate -PushAll @{'a'=41,42}) @{} @{a=41,42} '.PushAll(data, "a", [41, 42], -1)'

	# a.less, a.more
	update (New-MdbcUpdate -Push @{'a.-2'=42}) @{a=1,2} -UError '*cannot use the part (a of a.-2)*' -EError '*Cannot insert at index (-2).*' #!v2.4
	update (New-MdbcUpdate -Push @{'a.3'=42}) @{a=1,2} @{a=1,2,$null,@(42)} '.Push(data, "a.3", 42)' #!
	update (New-MdbcUpdate -Push @{'a.3.x'=42}) @{a=1,2} @{a=1,2,$null,@{x=@(42)}} '.Push(data, "a.3.x", 42)' #!

	### push

	# v2.4 stores with bad names, v2.6 fixed
	update @{'$push'=@{a=@{'$bad'=42}}} @{a=@()} `
	-UError '*The dollar ($) prefixed field * is not valid for storage.*' -EError '*Invalid document element name: "$bad".*'

	# ditto but presents "missing $each"
	update @{'$push'=@{a=@{'$sort'=1}}} @{a=@()} @{a=@(@{})} `
	-UError '*The dollar ($) prefixed field * is not valid for storage.*' -EError '*Invalid document element name: "$sort".*'

	# empty document
	update @{'$push'=@{a=@{}}} @{a=@()} @{a=@(@{})} `
	'.Push(data, "a", { })'

	# some document
	update @{'$push'=@{a=@{x=1; y=2}}} @{a=@()} @{a=@(@{x=1; y=2})} `
	'.Push(data, "a", { "y" : 2, "x" : 1 })'

	### each

	# v2.6 should fail
	update @{'$push'=@{a=@{'$bad'=42; '$each'=1,2}}} @{a=@()} `
	-UError '*Unrecognized clause in $push: $bad*' -EError '*Unrecognized clause in $push: ($bad).*'

	update @{'$push'=@{a=@{'$each'=1,2; bad=42}}} @{a=@()} `
	-UError '*Unrecognized clause in $push: bad*' -EError '*Unrecognized clause in $push: (bad).*'

	### slice

	update @{'$push'=@{a=@{'$each'=1,2; '$slice'='bad'}}} @{a=@()} `
	-UError '*The value for $slice must be a numeric value*' -EError '*$slice must be a numeric value.*'

	# v2.6 slice can be >0
	update @{'$push'=@{a=@{'$each'=1,2; '$slice'=1}}} @{a=@()} @{a=@(1)} '.PushAll(data, "a", [1], -1)'

	update @{'$push'=@{a=@{'$each'=1,2; '$slice'=-1}}} @{a=@()} @{a=@(2)} '.PushAll(data, "a", [2], -1)'

	### sort

	update @{'$push'=@{a=@{'$each'=@{x=2},'text'; '$sort'=0}}} @{a=@()} `
	-UError '*The $sort element value must be either 1 or -1*' -EError '*Numeric $sort value must be either 1 or -1.*'

	update @{'$push'=@{a=@{'$each'=@{x=2},'text'; '$sort'='bad'}}} @{a=@()} `
	-UError '*The $sort is invalid:*' -EError '*$sort value must be 1, -1, or a document.*'

	#TODO v2.6 does not require all documents, Mdbc still does
	update @{'$push'=@{a=@{'$each'=@{x=2},'text'; '$sort'=@{x=1}}}} @{a=@()} @{a='text',@{x=2}} `
	-EError '*$sort requires $each to be an array of objects.*'

	# v2.6 can have $sort without $slice
	update @{'$push'=@{a=@{'$each'=@{x=2},@{x=1}; '$sort'=@{x=1}}}} @{a=@()} @{a=@{x=1},@{x=2}} `
	'.PushAll(data, "a", [{ "x" : 1 }, { "x" : 2 }], -1)'

	update @{'$push'=@{a=@{'$each'=@{x=2},@{x=1}; '$sort'=@{x=1}; '$slice'='bad'}}} @{a=@()} `
	-UError '*$slice must be a numeric value*' -EError '*$slice must be a numeric value.*'

	update @{'$push'=@{a=@{'$each'=@{x=2},@{x=1}; '$sort'=@{x=1}; '$slice'=-1}}} @{a=@()} @{a=@(@{x=2})} `
	'.PushAll(data, "a", [{ "x" : 2 }], -1)'
}

# v2.6 $position
task PushPosition {
	# negative bug minor https://jira.mongodb.org/browse/SERVER-12959
	update @{'$push'=@{a=@{'$each'=@(3,4); '$position'=-1}}} @{a=1,2} `
	-UError '*The $position value in $push must be positive.*' -EError '*$position must not be negative.*'

	# bad type
	update @{'$push'=@{a=@{'$each'=@(3,4); '$position'=$null}}} @{a=1,2} `
	-UError '*The value for $position must be a positive numeric value not a NULL*' -EError '*$position must be a numeric value.*'

	# too big
	update @{'$push'=@{a=@{'$each'=@(3,4); '$position'=9}}} @{a=1,2} @{a=1,2,3,4} '.PushAll(data, "a", [3, 4], 9)'

	# 0
	update @{'$push'=@{a=@{'$each'=@(3,4); '$position'=0}}} @{a=1,2} @{a=3,4,1,2} '.PushAll(data, "a", [3, 4], 0)'
}
