<#
.Synopsis
	Tests Mdbc.Dictionary and Mdbc.Collection and underlying types.

.Description
	Objects and collections are converted to BsonDocument and BsonArray and
	used in PowerShell as their wrappers Mdbc.Dictionary and Mdbc.Collection.

	Round trip types:
	[double], [string], [guid], [bool], [DateTime], $null, [int], [long], [decimal]

	One way types, not changed binary or functionally:
	[byte[]] -> BsonBinaryData, [regex] -> BsonRegularExpression

	Other BSON types do not look that useful in PowerShell.
	But their are supported using their BSON driver types.

	https://docs.mongodb.com/manual/reference/bson-types/
	http://bsonspec.org/spec.html
#>

Import-Module Mdbc
Set-StrictMode -Version Latest

# Tests data returned by Mdbc.Dictionary
function Test-Data($key, $type) {
	if ($null -eq ($v = $m[$key])) { equals $null $type }
	else { try { equals $v.GetType() $type } catch { Write-Error "$_" } }
}

# Tests underlying BSON types
function Test-Bson($key, $type) {
	try { equals $b[$key].GetType() $type } catch { Write-Error "$_" }
}

task BsonTypes {
	# Mdbc.Dictionary and its wrapped BsonDocument. Further, we use standard
	# MongoDB type aliases for $m.key and BsonType enum names in comments.
	$m = New-MdbcData
	$b = $m.ToBsonDocument()

	### 1 Double - round trip [double]
	$(
		$m.double = 3.14
		equals $m.double 3.14
		Test-Data double ([double])
		Test-Bson double ([MongoDB.Bson.BsonDouble])
	)

	### 2 String - round trip [string]
	$(
		$m.string = 'bar'
		equals $m.string bar
		Test-Data string ([string])
		Test-Bson string ([MongoDB.Bson.BsonString])
	)

	### 3 Object - object/dictionary -> BsonDocument -> Mdbc.Dictionary
	$(
		$m.object = @{bar = 1}
		equals $m.object $m.object
		Test-Data object ([Mdbc.Dictionary])
		Test-Bson object ([MongoDB.Bson.BsonDocument])

		# a new wrapper is returned each time
		assert (!([object]::ReferenceEquals($m.object, $m.object)))

		# but they share the same BsonDocument instance
		assert ([object]::ReferenceEquals($m.object.ToBsonDocument(), $m.object.ToBsonDocument()))

		# and `-eq`
		assert ($m.object -eq $m.object)
	)

	### 4 Array - collection -> BsonArray -> Mdbc.Collection
	$(
		$m.array = @(1, 2)
		equals $m.array $m.array
		Test-Data array ([Mdbc.Collection])
		Test-Bson array ([MongoDB.Bson.BsonArray])

		# a new wrapper is returned each time
		assert (!([object]::ReferenceEquals($m.array, $m.array)))

		# but they share the same BsonArray instance
		assert ([object]::ReferenceEquals($m.array.ToBsonArray(), $m.array.ToBsonArray()))

		# but `-ne` (PowerShell, why?)
		assert ($m.array -ne $m.array)
	)

	### 5 Binary - round trip [guid], one way [byte[]]
	$(
		# guid - round trip [guid]
		$v = [guid]"cdccdb76-30a3-4d7c-97fa-5ae1ad28fd64"
		$m.binData04 = $v
		equals $m.binData04 $v
		Test-Data binData04 ([guid])
		Test-Bson binData04 ([MongoDB.Bson.BsonBinaryData])

		# bytes - one way byte[] -> BsonBinaryData
		$v = [byte[]](1, 2)
		$m.binData00 = $v #_191108_183844
		equals $m.binData00 $m.binData00
		Test-Data binData00 ([MongoDB.Bson.BsonBinaryData])
		Test-Bson binData00 ([MongoDB.Bson.BsonBinaryData])

		# ReferenceEquals()
		assert ([object]::ReferenceEquals($m.binData00, $m.binData00))

		# the original byte[] instance
		assert ([object]::ReferenceEquals($m.binData00.Bytes, $v))
	)

	### 6 Undefined - Deprecated

	### 7 ObjectId - round trip [MongoDB.Bson.ObjectId]
	$(
		$v = [MongoDB.Bson.ObjectId]"5dc4c9808c94b4316c418f95"
		$m.objectId = $v
		equals $m.objectId $v
		Test-Data objectId ([MongoDB.Bson.ObjectId])
		Test-Bson objectId ([MongoDB.Bson.BsonObjectId])
	)

	### 8 Boolean - round trip [bool]
	$(
		$m.bool = $true
		equals $m.bool $true
		Test-Data bool ([bool])
		Test-Bson bool ([MongoDB.Bson.BsonBoolean])
	)

	### 9 Date - round trip [DateTime]
	$(
		$v = [DateTime]"2019-11-11"
		$m.date = $v
		equals $m.date $v
		Test-Data date ([DateTime])
		Test-Bson date ([MongoDB.Bson.BsonDateTime])
	)

	### 10 Null - round trip $null
	$(
		$m.null = $null
		equals $m.null $null
		Test-Data null $null
		Test-Bson null ([MongoDB.Bson.BsonNull])
	)

	### 11 RegularExpression - one way [regex] -> BsonRegularExpression
	$(
		$v = [regex]'bar'
		$m.regex = $v
		equals $m.regex $m.regex
		Test-Data regex ([MongoDB.Bson.BsonRegularExpression])
		Test-Bson regex ([MongoDB.Bson.BsonRegularExpression])

		# gets not same regex back but functionally same
		equals $m.regex.ToRegex().GetType() ([regex])
		assert (!([object]::Equals($m.regex.ToRegex(), $v)))
		assert (!([object]::ReferenceEquals($m.regex.ToRegex(), $v)))
	)

	### 12 DBPointer - Deprecated

	### 13 JavaScript - just BsonJavaScript
	$(
		$m.javascript = [MongoDB.Bson.BsonJavaScript]'x = 42'
		equals $m.javascript $m.javascript
		Test-Data javascript ([MongoDB.Bson.BsonJavaScript])
		Test-Bson javascript ([MongoDB.Bson.BsonJavaScript])
	)

	### 14 Symbol - Deprecated

	### 15 JavaScriptWithScope - just BsonJavaScriptWithScope
	$(
		$m.javascriptWithScope = [MongoDB.Bson.BsonJavaScriptWithScope]::new('x = y', [Mdbc.Dictionary]::new())
		equals $m.javascriptWithScope $m.javascriptWithScope
		Test-Data javascriptWithScope ([MongoDB.Bson.BsonJavaScriptWithScope])
		Test-Bson javascriptWithScope ([MongoDB.Bson.BsonJavaScriptWithScope])
	)

	### 16 Int32 - round trip [int]
	$(
		$m.int = 42
		equals $m.int 42
		Test-Data int ([int])
		Test-Bson int ([MongoDB.Bson.BsonInt32])
	)

	### 17 Timestamp - just BsonTimestamp
	$(
		$m.timestamp = [MongoDB.Bson.BsonTimestamp]12345
		equals $m.timestamp $m.timestamp
		Test-Data timestamp ([MongoDB.Bson.BsonTimestamp])
		Test-Bson timestamp ([MongoDB.Bson.BsonTimestamp])
	)

	### 18 Int64 - round trip [long]
	$(
		$m.long = 42L
		equals $m.long 42L
		Test-Data long ([long])
		Test-Bson long ([MongoDB.Bson.BsonInt64])
	)

	### 19 Decimal128 -- round trip [decimal]
	$(
		$m.decimal = 123456789.123456789d
		equals $m.decimal 123456789.123456789d
		Test-Data decimal ([decimal])
		Test-Bson decimal ([MongoDB.Bson.BsonDecimal128])
	)

	### -1 MinKey - singleton [MongoDB.Bson.BsonMinKey]
	$(
		$m.minKey = [MongoDB.Bson.BsonMinKey]::Value
		equals $m.minKey $m.minKey
		Test-Data minKey ([MongoDB.Bson.BsonMinKey])
		Test-Bson minKey ([MongoDB.Bson.BsonMinKey])
	)

	### 127 MaxKey - singleton [MongoDB.Bson.BsonMaxKey]
	$(
		$m.maxKey = [MongoDB.Bson.BsonMaxKey]::Value
		equals $m.maxKey $m.maxKey
		Test-Data maxKey ([MongoDB.Bson.BsonMaxKey])
		Test-Bson maxKey ([MongoDB.Bson.BsonMaxKey])
	)

	### pretty print all types
	Write-Host ($m.Print())
}
