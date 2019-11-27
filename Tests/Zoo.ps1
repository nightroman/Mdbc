<#
.Synopsis
	Common test tools.
#>

Import-Module Mdbc

function Get-MdbcCollectionNew($Name, $Database=$Database) {
	$Collection = Get-MdbcCollection $Name -NewCollection
	Add-MdbcData @{_id = 1}
	Remove-MdbcData @{}
	$Collection
}

function Zoo1 {
	class T { $Version = [version]'0.0' }
	[T]::new()
}

function Get-ServerVersion {
	Connect-Mdbc . test
	$version = (Invoke-MdbcCommand '{buildInfo:1}').version
	assert ($version -match '^\d+\.\d+\.\d+$')
	[version]$version
}

# Invokes the test repeatedly with the specified contexts.
# Args: the test script block and context script blocks.
function Invoke-Test($Test)
{
	foreach(${+} in $args) {&{
		Write-Build 8 ${+}
		. ${+}
		. $Test
	}}
}

# Compares an object type with expected
function Test-Type($Value, $TypeName) {
	$name = $Value.GetType().FullName
	if (($tick = $name.IndexOf('`')) -ge 0) {$name = $name.Substring(0, $tick)}

	if ($TypeName -ne $name) {
		Write-Error -ErrorAction 1 "Expected type: $TypeName, actual type: $name"
	}
}

# Invokes a command and checks the error and the sample.
# Args: [0] script block [1] sample error wildcard.
function Test-Error([Parameter()]$Command, $Like, $Text) {
	trap {Write-Error -ErrorAction 1 -ErrorRecord $_}
	Remove-Variable Command, Like, Text

	${private:+result} = $null
	try { & $PSBoundParameters.Command }
	catch { ${+result} = "$_" }

	if (!${+result}) {
		throw 'Expected error.'
	}
	elseif ($_ = $PSBoundParameters['Like']) {
		if (${+result} -notlike $_) {
			throw "Sample/Result:`n$_`n${+result}"
		}
	}
	elseif ($_ = $PSBoundParameters['Text']) {
		if (${+result} -cne $_) {
			throw "Sample/Result:`n$_`n${+result}"
		}
	}
	else {
		throw 'Test-Error: missing error pattern parameter.'
	}
}

# Compares two dictionaries.
function Test-Table([System.Collections.IDictionary]$1, [System.Collections.IDictionary]$2, [switch]$Force) {
	if ($1.Count -ne $2.Count) {
		Write-Error -ErrorAction 1 "Different dictionary counts: $($1.Count) and $($2.Count)."
	}
	foreach($key in $1.Keys) {
		if (!$2.Contains($key)) {
			Write-Error -ErrorAction 1 "Second dictionary ($key) entry is missing."
		}
		$v1 = $1[$key]
		$v2 = $2[$key]

		if (($null -eq $v1) -and ($null -eq $v2)) {continue}

		if (($null -eq $v1) -ne ($null -eq $v2)) {
			Write-Error -ErrorAction 1 "Different dictionary ($key) nulls: $($null -eq $v1) and $($null -eq $v2)."
		}

		if ($v1.GetType() -ne $v2.GetType() -and (!$Force -or !(
			($v1 -is [System.Collections.IDictionary] -and $v2 -is [System.Collections.IDictionary]) -or
			($v1 -is [System.Collections.IList] -and $v2 -is [System.Collections.IList])))) {
			Write-Error -ErrorAction 1 "Different dictionary ($key) types: $($v1.GetType()) and $($v2.GetType())."
		}

		if ($v1 -is [System.Collections.IDictionary]) {
			try { Test-Table $v1 $v2 -Force:$Force }
			catch { Write-Error -ErrorAction 1 "Dictionary ($key): $_" }
			continue
		}

		if ($v1 -is [System.Collections.IList]) {
			try { Test-List $v1 $v2 -Force:$Force }
			catch { Write-Error -ErrorAction 1 "Dictionary ($key): $_" }
			continue
		}

		if ($v1 -cne $v2) {
			if ($Force -and $v1 -is [datetime] -and [math]::Abs(($v1 - $v2).TotalSeconds) -lt 2) {}
			else {
				Write-Error -ErrorAction 1 "Different dictionary ($key) values: ($v1) and ($v2)."
			}
		}
	}
}

# Compares two lists.
function Test-List([System.Collections.IList]$1, [System.Collections.IList]$2, [switch]$Force) {
	for($i = 0; $i -lt $1.Count; ++$i) {
		if ($i -ge $2.Count) {
			break
		}
		$v1 = $1[$i]
		$v2 = $2[$i]

		if (($null -eq $v1) -and ($null -eq $v2)) {continue}

		if (($null -eq $v1) -ne ($null -eq $v2)) {
			Write-Error -ErrorAction 1 "Different list ($i) nulls: $($null -eq $v1) and $($null -eq $v2)."
		}

		if ($v1.GetType() -ne $v2.GetType() -and (!$Force -or !(
				($v1 -is [System.Collections.IDictionary] -and $v2 -is [System.Collections.IDictionary]) -or
				($v1 -is [System.Collections.IList] -and $v2 -is [System.Collections.IList])))) {
			Write-Error -ErrorAction 1 "Different list ($i) types: $($v1.GetType()) and $($v2.GetType())."
		}

		if ($v1 -is [System.Collections.IDictionary]) {
			try { Test-Table $v1 $v2 -Force:$Force }
			catch { Write-Error -ErrorAction 1 "List ($i): $_" }
			continue
		}

		if ($v1 -is [System.Collections.IList]) {
			try { Test-List $v1 $v2 -Force:$Force }
			catch { Write-Error -ErrorAction 1 "List ($i): $_" }
			continue
		}

		if ($v1 -cne $v2) {
			if ($Force -and $v1 -is [datetime] -and [math]::Abs(($v1 - $v2).TotalSeconds) -lt 2) {}
			else {
				Write-Error -ErrorAction 1 "Different list ($i) values: ($v1) and ($v2)."
			}
		}
	}
	if ($1.Count -ne $2.Count) {
		Write-Error -ErrorAction 1 "Different list counts: $($1.Count) and $($2.Count)."
	}
}

# Log expression and sample, invoke expression, compare with sample
function Test-Expression($expression, $sample) {
	"$expression => $sample"
	$result = (. $expression).ToString()
	if ($result -cne $sample) {
		Write-Error -ErrorAction 1 "`n Sample : $sample`n Result : $result"
	}
}

# Gets a dictionary with all known bson types
function New-BsonBag {
	$m = New-MdbcData
	# 1 Double - round trip [double]
	$m.double = 3.14
	# 2 String - round trip [string]
	$m.string = 'bar'
	# 3 Object - object/dictionary -> BsonDocument -> Mdbc.Dictionary
	$m.object = @{bar = 1}
	# 4 Array - collection -> BsonArray -> Mdbc.Collection
	$m.array = @(1, 2)
	# 5 Binary - round trip [guid], one way [byte[]]
	# guid - round trip [guid]
	$m.binData04 = [guid]"cdccdb76-30a3-4d7c-97fa-5ae1ad28fd64"
	# bytes - one way byte[] -> BsonBinaryData
	$m.binData00 = [byte[]](1, 2)
	# 6 Undefined - Deprecated
	# 7 ObjectId - round trip [MongoDB.Bson.ObjectId]
	$m.objectId = [MongoDB.Bson.ObjectId]"5dc4c9808c94b4316c418f95"
	# 8 Boolean - round trip [bool]
	$m.bool = $true
	# 9 Date - round trip [DateTime]
	$m.date = [DateTime]"2019-11-11"
	# 10 Null - round trip $null
	$m.null = $null
	# 11 RegularExpression - one way [regex] -> BsonRegularExpression
	$m.regex = [regex]'bar'
	# 12 DBPointer - Deprecated
	# 13 JavaScript - just BsonJavaScript
	$m.javascript = [MongoDB.Bson.BsonJavaScript]'x = 42'
	# 14 Symbol - Deprecated
	# 15 JavaScriptWithScope - just BsonJavaScriptWithScope
	$m.javascriptWithScope = [MongoDB.Bson.BsonJavaScriptWithScope]::new('x = y', [Mdbc.Dictionary]::new())
	# 16 Int32 - round trip [int]
	$m.int = 42
	# 17 Timestamp - just BsonTimestamp
	$m.timestamp = [MongoDB.Bson.BsonTimestamp]12345
	# 18 Int64 - round trip [long]
	$m.long = 42L
	# 19 Decimal128 -- round trip [decimal]
	$m.decimal = 123456789.123456789d
	# -1 MinKey - singleton [MongoDB.Bson.BsonMinKey]
	$m.minKey = [MongoDB.Bson.BsonMinKey]::Value
	# 127 MaxKey - singleton [MongoDB.Bson.BsonMaxKey]
	$m.maxKey = [MongoDB.Bson.BsonMaxKey]::Value
	$m
}
