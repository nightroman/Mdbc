
. .\Zoo.ps1
Import-Module Mdbc
Set-StrictMode -Version 2

function update (
	[Parameter(Position=0)]$Update, # update for the document
	[Parameter(Position=1)]$Document, # document to be updated
	[Parameter(Position=2)]$Sample, # updated document sample
	[Parameter(Position=3)]$ExpressionText, # update expression sample
	$Query, # query used on upsert update
	$UpError, # update error wildcard
	$ExError # expression error wildcard
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
			Update-MdbcData -Update $Update -Query $Query -Modes Upsert
		}
		else {
			Update-MdbcData -Update $Update -Query @{}
		}
		$r = Get-MdbcData
		$r.Remove('_id')
		$r.ToString()
	}
	catch {
		if (!$UpError) {Write-Error $_}
		if ($_ -notlike $UpError) {Write-Error "`n Update error sample : $UpError`n Update error result : $_"}
		$err = $_
	}
	if ($UpError -and !$err) {Write-Error "Expected error on update."}

	# test base result
	if (!$UpError) {
		try { Test-Table $Sample $r -Force }
		catch { Write-Error "Update sample vs. result : $_" }
	}

	# linq update
	$err = $null
	try {
		if ($Update -is [Hashtable]) { $Update = (New-MdbcData $Update).Document() }
		$expression = [Mdbc.UpdateCompiler]::GetExpression($Update, $Query, $Query)
		$Document = New-MdbcData $Document
		$null = [Mdbc.UpdateCompiler]::GetFunction($expression).Invoke($Document.Document())
		$Document.ToString()
	}
	catch {
		if (!$ExError) {Write-Error $_}
		if ($_ -notlike $ExError) {Write-Error "`n Expression error sample : $ExError`n Expression error result : $_"}
		$err = $_
	}
	if ($ExError -and !$err) {Write-Error "Expected error on expression."}

	# test linq result
	if (!$ExError) {
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
	update (New-MdbcUpdate -Unset a.1 -Pull @{a=1}) -UpError '*conflicting mods in update*' -ExError '*Conflicting fields "a.1" and "a".*'
	update (New-MdbcUpdate -Unset a -Pull @{'a.1'=1}) -UpError '*conflicting mods in update*' -ExError '*Conflicting fields "a" and "a.1".*'
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
	update (New-MdbcUpdate -Unset a.-2) @{a=1,2,3} @{a=1,2,3} '.Unset(data, "a.-2")'
	update (New-MdbcUpdate -Unset a.99) @{a=1,2,3} @{a=1,2,3} '.Unset(data, "a.99")'
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
	-UpError '*$rename source field invalid*' -ExError '*"Array indexes are not supported."'
}

task Set {
	# errors
	update (New-MdbcUpdate -Set @{'x.y.z'=1}) @{x=@{y=1}} -UpError '* 10145,*' -ExError '*"Field (y) in (x.y.z) is not a document."'
	update (New-MdbcUpdate -Set @{'a.x'=1}) @{a=@{x=1},@{x=1}} -UpError '* 13048,*' -ExError '*"Field (a) in (a.x) is not a document."'
	update @{x=1; '$inc'=@{y=2}} @{} -UpError '* 10147,*' -ExError '*Update cannot mix operators and fields.*' #_131103_204607

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
	update (New-MdbcUpdate -Set @{'a.-2'=42}) @{a=1,2} @{a=42,1,2} '.Set(data, "a.-2", 42)'

	# set a.<more>
	update (New-MdbcUpdate -Set @{'a.3'=42}) @{a=1,2} @{a=1,2,$null,42} '.Set(data, "a.3", 42)'

	# set a.1.x
	update (New-MdbcUpdate -Set @{'a.1.x'=42}) @{a=0,@{x=1;y=1}} @{a=0,@{x=42;y=1}} '.Set(data, "a.1.x", 42)'

	# set a.1.x, error [1] is not document
	update (New-MdbcUpdate -Set @{'a.1.x'=42}) @{a=0,1} -UpError '* 10145,*' -ExError '*"Array item at (1) in (a.1.x) is not a document."'

	# set a.<less>.x
	update (New-MdbcUpdate -Set @{'a.-2.x'=42}) @{a=0,@{x=1}} @{a=@{x=42},0,@{x=1}} '.Set(data, "a.-2.x", 42)'

	# set a.<more>.x
	update (New-MdbcUpdate -Set @{'a.3.x'=42}) @{a=0,@{x=1}} @{a=0,@{x=1},$null,@{x=42}} '.Set(data, "a.3.x", 42)'
}

task SetOnInsert {
	# not insert
	update (New-MdbcUpdate -SetOnInsert @{x=42}) @{} @{} ''

	# insert
	update (New-MdbcUpdate -SetOnInsert @{x=42}) @{} @{x=42} -Query @{'$exists'=@{m=1}} '.Set(data, "x", 42)'

	# update overrides query
	update (New-MdbcUpdate -Set @{x=42}) @{} @{x=42} -Query @{x=1} '.Set(data, "x", 1).Set(data, "x", 42)'

	# two fields in query
	update (New-MdbcUpdate -Set @{x=42}) @{} @{x=42;y=1;z=1} -Query @{y=1;z=1} '.Set(data, "z", 1).Set(data, "y", 1).Set(data, "x", 42)'
}

task Inc {
	# missing
	update (New-MdbcUpdate -Inc @{miss=1}) @{} @{miss=1} '.Inc(data, "miss", 1)'

	# int += int -> int
	update (New-MdbcUpdate -Inc @{x=1}) @{x=1} @{x=2} '.Inc(data, "x", 1)'

	# int += long -> int or long
	update (New-MdbcUpdate -Inc @{x=1L}) @{x=1} @{x=2} '.Inc(data, "x", 1)'
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
	update (New-MdbcUpdate -Inc @{x=1}) @{x=$null} -UpError '* 10140,*' -ExError '*Field "x" must be numeric.*'
	update (New-MdbcUpdate -Inc @{x=1}) @{x='bad'} -UpError '* 10140,*' -ExError '*Field "x" must be numeric.*'
	update (New-MdbcUpdate -Inc @{'a.1'=1}) @{a=1,'2'} -UpError '* 10140,*' -ExError '*Item "a.1" must be numeric.*'

	# value is not numeric
	Test-Error {New-MdbcUpdate -Inc @{x=$null}} '*Exception setting "Inc": "Invalid type. Expected types: int, long, double."'
	update @{'$inc'=@{x=$null}} -UpError '* 10152,*' -ExError '*"Increment value must be numeric."'
	update @{'$inc'=@{x='bad'}} -UpError '* 10152,*' -ExError '*"Increment value must be numeric."'

	# nested
	update (New-MdbcUpdate -Inc @{'x.deep'=-1}, @{'x.miss'=-1}) @{x=@{deep=-1}} @{x=@{deep=-2; miss=-1}} '.Inc(data, "x.deep", -1).Inc(data, "x.miss", -1)'

	# a.1
	update (New-MdbcUpdate -Inc @{'a.1'=1}) @{a=1,2,3} @{a=1,3,3} '.Inc(data, "a.1", 1)'

	# a.<less>
	update (New-MdbcUpdate -Inc @{'a.-2'=42}) @{a=1,2} @{a=42,1,2} '.Inc(data, "a.-2", 42)'

	# a.<more>
	update (New-MdbcUpdate -Inc @{'a.3'=42}) @{a=1,2} @{a=1,2,$null,42} '.Inc(data, "a.3", 42)'

	# a.1.x
	update (New-MdbcUpdate -Inc @{'a.1.x'=1}) @{a=1,@{x=2},3} @{a=1,@{x=3},3} '.Inc(data, "a.1.x", 1)'

	# a.<less>.x
	update (New-MdbcUpdate -Inc @{'a.-2.x'=1}) @{a=1,2} @{a=@{x=1},1,2} '.Inc(data, "a.-2.x", 1)'

	# a.<more>.x
	update (New-MdbcUpdate -Inc @{'a.3.x'=1}) @{a=1,2} @{a=1,2,$null,@{x=1}} '.Inc(data, "a.3.x", 1)'
}

task Bitwise {
	# int32 x int32
	update (New-MdbcUpdate -BitwiseAnd @{n=2}) @{n=3} @{n=2} '.BitwiseAnd(data, "n", 2)'
	update (New-MdbcUpdate -BitwiseOr @{n=2}) @{n=3} @{n=3} '.BitwiseOr(data, "n", 2)'

	# int64 x int64
	update (New-MdbcUpdate -BitwiseAnd @{n=2L}) @{n=3L} @{n=2L} '.BitwiseAnd(data, "n", 2)'
	update (New-MdbcUpdate -BitwiseOr @{n=2L}) @{n=3L} @{n=3L} '.BitwiseOr(data, "n", 2)'

	# int64 x int32
	update (New-MdbcUpdate -BitwiseAnd @{n=2}) @{n=3L} @{n=2L} '.BitwiseAnd(data, "n", 2)'
	update (New-MdbcUpdate -BitwiseOr @{n=2}) @{n=3L} @{n=3L} '.BitwiseOr(data, "n", 2)'

	# int32 x int64
	update (New-MdbcUpdate -BitwiseAnd @{n=5gb+1}) @{n=1} @{n=1} '.BitwiseAnd(data, "n", 5368709121)'
	#bug BitwiseAnd with big Int64
	#update (New-MdbcUpdate -BitwiseOr @{n=5gb+1}) @{n=1} @{n=1073741825} '.BitwiseAnd(data, "n", 5368709121)'

	# bad
	update (New-MdbcUpdate -BitwiseAnd @{'x'=2}) @{x='3'} -UpError '* 10137,*' -ExError '*Field "x" must be Int32 or Int64.*'
	update (New-MdbcUpdate -BitwiseAnd @{'a.1'=2}) @{a=3,'3'} -UpError '* 10137,*' -ExError '*Item "a.1" must be Int32 or Int64.*'

	# array item
	update (New-MdbcUpdate -BitwiseAnd @{'a.-1'=2}) @{a=3,3} @{a=3,3} '.BitwiseAnd(data, "a.-1", 2)'
	update (New-MdbcUpdate -BitwiseAnd @{'a.2'=2}) @{a=3,3} @{a=3,3} '.BitwiseAnd(data, "a.2", 2)'
	update (New-MdbcUpdate -BitwiseAnd @{'a.1'=2}) @{a=3,3} @{a=3,2} '.BitwiseAnd(data, "a.1", 2)'
}

task AddToSet {
	# AddToSet vs. AddToSetEach
	update (New-MdbcUpdate -AddToSet @{a=1,2}) @{a=@()} @{a=@(,@(1,2))} '.AddToSet(data, "a", [1, 2], False)'
	update (New-MdbcUpdate -AddToSet @{a=1,2}) @{a=@(,@(1,2))} @{a=@(,@(1,2))} '.AddToSet(data, "a", [1, 2], False)'
	update (New-MdbcUpdate -AddToSetEach @{a=1,2}) @{a=@()} @{a=1,2} '.AddToSet(data, "a", [1, 2], True)'
	update (New-MdbcUpdate -AddToSetEach @{a=1,2}) @{a=@(,@(1,2))} @{a=@(1,2),1,2} '.AddToSet(data, "a", [1, 2], True)'

	# empty array
	update (New-MdbcUpdate -AddToSet @{a=1}) @{a=@()} @{a=@(1)} '.AddToSet(data, "a", 1, False)'
	update (New-MdbcUpdate -AddToSet @{'a.1'=1}) @{a=1,@()} @{a=1,@(1)} '.AddToSet(data, "a.1", 1, False)'

	# value exists
	update (New-MdbcUpdate -AddToSet @{a=1}) @{a=@(1.0)} @{a=@(1.0)} '.AddToSet(data, "a", 1, False)'
	update (New-MdbcUpdate -AddToSet @{'a.1'=1}) @{a=1,@(1.0)} @{a=1,@(1.0)} '.AddToSet(data, "a.1", 1, False)'

	# miss or out or range
	update (New-MdbcUpdate -AddToSet @{miss=1}) @{} @{miss=@(1)} '.AddToSet(data, "miss", 1, False)'
	update (New-MdbcUpdate -AddToSet @{'a.-2'=1}) @{a=1,2} @{a=@(1),1,2} '.AddToSet(data, "a.-2", 1, False)'
	update (New-MdbcUpdate -AddToSet @{'a.3'=1}) @{a=1,2} @{a=1,2,$null,@(1)} '.AddToSet(data, "a.3", 1, False)'

	# m.1.m
	update (New-MdbcUpdate -AddToSet @{'m.1.m'=42}) @{} @{m=@{'1'=@{m=@(42)}}} '.AddToSet(data, "m.1.m", 42, False)'

	# a.1.m
	update (New-MdbcUpdate -AddToSet @{'a.1.m'=42}) @{a=@()} @{a=$null,@{m=@(42)}} '.AddToSet(data, "a.1.m", 42, False)'

	# not array
	update (New-MdbcUpdate -AddToSet @{a=1}) @{a=1} -UpError '* 12591,*' -ExError '*Value "a" must be array.*'
	update (New-MdbcUpdate -AddToSet @{'a.1'=1}) @{a=1,2} -UpError '* 12591,*' -ExError '*Value "a.1" must be array.*'
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
	update (New-MdbcUpdate -PopFirst bad) @{bad=1} -UpError '* 10143,*' -ExError '*Value "bad" must be array.*'

	# a.index
	update (New-MdbcUpdate -PopLast a.1) @{a=1,@(1,2)} @{a=1,@(1)} '.Pop(data, "a.1", 1)'
	update (New-MdbcUpdate -PopLast a.-2) @{a=1,2} @{a=1,2} '.Pop(data, "a.-2", 1)'
	update (New-MdbcUpdate -PopLast a.3) @{a=1,2} @{a=1,2} '.Pop(data, "a.3", 1)'
	update (New-MdbcUpdate -PopLast a.1) @{a=1,'bad'} -UpError '* 10143,*' -ExError '*Value "a.1" must be array.*'
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
	update (New-MdbcUpdate -Pull @{a=New-MdbcQuery x 1}) @{a=1,@{x=1;y=1},3} @{a=1,3} '.Pull(data, "a", { "x" : 1 })' #!

	# PullAll document
	update @{'$pullAll'=@{a=@{x=1}}} @{} -UpError '* 10153,*' -ExError '*Pull all value must be array.*'
	update (New-MdbcUpdate -PullAll @{a=@{x=1}}) @{a=1,@{x=1;y=1},3} @{a=1,@{x=1;y=1},3} '.PullAll(data, "a", [{ "x" : 1 }])'

	# d.a.1.a
	update (New-MdbcUpdate -Pull @{'d.a.1.a'=2}) @{d=@{a=1,@{a=1,2,3}}} @{d=@{a=1,@{a=1,3}}} '.Pull(data, "d.a.1.a", 2)'

	# a.1|less|more
	update (New-MdbcUpdate -Pull @{'a.1'=1}) @{a=1,@(1,2)} @{a=1,@(2)} '.Pull(data, "a.1", 1)'
	update (New-MdbcUpdate -Pull @{'a.-2'=1}) @{a=1,2} @{a=1,2} '.Pull(data, "a.-2", 1)'
	update (New-MdbcUpdate -Pull @{'a.3'=1}) @{a=1,2} @{a=1,2} '.Pull(data, "a.3", 1)'

	# bad
	update (New-MdbcUpdate -Pull @{b=1}) @{b=1} -UpError '* 10142,*' -ExError '*Value "b" must be array.*'
	update (New-MdbcUpdate -Pull @{'a.1'=1}) @{a=1,'bad'} -UpError '* 10142,*' -ExError '*Value "a.1" must be array.*'

	# miss
	update (New-MdbcUpdate -Pull @{m=1}) @{x=1} @{x=1} '.Pull(data, "m", 1)'
	update (New-MdbcUpdate -Pull @{'a.3'=1}) @{a=1,2} @{a=1,2} '.Pull(data, "a.3", 1)'
	update (New-MdbcUpdate -Pull @{'a.-2'=1}) @{a=1,2} @{a=1,2} '.Pull(data, "a.-2", 1)'
}

task Push {
	# bad field
	update (New-MdbcUpdate -Push @{b=1}) @{b=1} -UpError '*10141,*' -ExError '*Value "b" must be array.*'
	update (New-MdbcUpdate -PushAll @{b=1}) @{b=1} -UpError '*10141,*' -ExError '*Value "b" must be array.*'
	update @{'$push'=@{b=@{'$each'=@(42)}}} @{b=1} -UpError '*10141,*' -ExError '*Value "b" must be array.*'

	# bad argument (but not for New-MdbcUpdate)
	update (New-MdbcUpdate -PushAll @{a=42}) @{a=1,2} @{a=1,2,42} '.PushAll(data, "a", [42])'
	update @{'$pushAll'=@{a=42}} @{} -UpError '* 10153,*' -ExError '*Push all/each value must be array.*'
	update @{'$push'=@{a=@{'$each'=42}}} @{} -UpError '* 16565,*' -ExError '*Push all/each value must be array.*'

	# a.1
	update (New-MdbcUpdate -Push @{'a.1'=41,42}) @{a=1,@(1,2)} @{a=1,@(1,2,@(41,42))} '.Push(data, "a.1", [41, 42])'
	update (New-MdbcUpdate -PushAll @{'a.1'=41,42}) @{a=1,@(1,2)} @{a=1,@(1,2,41,42)} '.PushAll(data, "a.1", [41, 42])'

	# miss
	update (New-MdbcUpdate -Push @{'a'=41,42}) @{} @{a=@(,@(41,42))} '.Push(data, "a", [41, 42])'
	update (New-MdbcUpdate -PushAll @{'a'=41,42}) @{} @{a=41,42} '.PushAll(data, "a", [41, 42])'

	# a.less, a.more
	update (New-MdbcUpdate -Push @{'a.-2'=42}) @{a=1,2} @{a=@(42),1,2} '.Push(data, "a.-2", 42)' #!
	update (New-MdbcUpdate -Push @{'a.3'=42}) @{a=1,2} @{a=1,2,$null,@(42)} '.Push(data, "a.3", 42)' #!
	update (New-MdbcUpdate -Push @{'a.3.x'=42}) @{a=1,2} @{a=1,2,$null,@{x=@(42)}} '.Push(data, "a.3.x", 42)' #!

	function doc {
		$$ = New-MdbcData
		while($args) {
			$n, $v, $args = $args
			$$.Add($n, $v)
		}
		$$
	}

	#! Mongo adds documents with bad names
	update @{'$push'=@{a=@{'$bad'=42}}} @{a=@()} @{a=@(@{'$bad'=42})} '.Push(data, "a", { "$bad" : 42 })'
	$$=doc '$bad' 42 '$each' 1,2; update @{'$push'=@{a=$$}} @{a=@()} @{a=@($$)} '.Push(data, "a", { "$bad" : 42, "$each" : [1, 2] })'

	$m = '*$each term takes only $slice (and optionally $sort) as complements*'
	$$=doc '$each' 1,2 'bad' 42; update @{'$push'=@{a=$$}} @{a=@()} -UpError $m -ExError $m

	# slice

	$m = '*$slice value must be a numeric integer*'
	$$=doc '$each' 1,2 '$slice' bad; update @{'$push'=@{a=$$}} @{a=@()} @{a=@(2)} -UpError $m -ExError $m

	$m = '*$slice value must be negative or zero*'
	$$=doc '$each' 1,2 '$slice' 1; update @{'$push'=@{a=$$}} @{a=@()} @{a=@(2)} -UpError $m -ExError $m

	$$=doc '$each' 1,2 '$slice' (-1)
	update @{'$push'=@{a=$$}} @{a=@()} @{a=@(2)} '.PushAll(data, "a", [2])'

	# sort

	$m = '*$sort component of $push must be an object*'
	$$=doc '$each' @{x=2},bad '$sort' bad; update @{'$push'=@{a=$$}} @{a=@()} -UpError $m -ExError $m

	$m = '*$sort requires $each to be an array of objects*'
	$$=doc '$each' @{x=2},bad '$sort' @{x=1}; update @{'$push'=@{a=$$}} @{a=@()} -UpError $m -ExError $m

	$m = '*cannot have a $sort without a $slice*'
	$$=doc '$each' @{x=2},@{x=1} '$sort' @{x=1}; update @{'$push'=@{a=$$}} @{a=@()} -UpError $m -ExError $m

	$m = '*$slice value must be a numeric integer*'
	$$=doc '$each' @{x=2},@{x=1} '$sort' @{x=1} '$slice' bad; update @{'$push'=@{a=$$}} @{a=@()} -UpError $m -ExError $m

	$m = '*$slice value must be negative or zero*'
	$$=doc '$each' @{x=2},@{x=1} '$sort' @{x=1} '$slice' 1; update @{'$push'=@{a=$$}} @{a=@()} -UpError $m -ExError $m

	$$=doc '$each' @{x=2},@{x=1} '$sort' @{x=1} '$slice' (-1)
	update @{'$push'=@{a=$$}} @{a=@()} @{a=@(@{x=2})} '.PushAll(data, "a", [{ "x" : 2 }])'
}
