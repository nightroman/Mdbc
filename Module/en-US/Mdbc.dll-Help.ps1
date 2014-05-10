
<#
.Synopsis
	Help script (https://github.com/nightroman/Helps)
#>

Import-Module Mdbc
Set-StrictMode -Version 2

### Shared descriptions

$CollectionVariable = @'
Name of a new variable in the current scope with the connected collection. The
default variable name is Collection. The default variable is used implicitly by
cmdlets operating on collection data.
'@

$IdParameter = @'
The document _id value to be assigned or a script block returning this value
for the input object represented by the variable $_.

_id must not exist in input objects or be specified again by Property.
'@

$NewIdParameter = @'
Tells to generate and assign a new document _id as MongoDB.Bson.ObjectId.

_id must not exist in input objects or be specified again by Property.
'@

$ConvertParameter = @'
A script called on exceptions during conversion of unknown data to BsonValue.
The variable $_ is the problem object to be converted. The script returns a
single value to be tried instead or nothing for nulls.

Examples: {} converts unknown data to nulls. {"$_"} converts data to strings,
it is useful for preserving as much information as possible on dumping objects
for later analysis.

Converters should be used sparingly, normally with unknown or varying data.
Consider to use Property for selecting standard and converting not standard
known data.
'@

$PropertyParameter = @'
Specifies properties or keys which values are to be included into documents or
defines calculated fields. Missing input properties and keys are ignored.

Arguments are defined in three ways:

1. Strings define property or key names and the corresponding result document
field names.

2. Hashtables @{Key=Value} define renamed and calculated fields. The key is a
new document field name. The value is either a string (input object property
name) or a script block (field value calculated from the input object $_).

3. Hashtables @{Name=...; Expression=...} or @{Label=...; Expression=...} are
similar but use the same convention as the parameter Property of Select-Object.

See New-MdbcData examples.
'@

$CollectionParameter = @'
Collection object. It is obtained by Connect-Mdbc or from database or server
objects. If it is not specified then the current variable Collection is used.
'@

$QueryTypes = @'
The following types are used as or converted to queries: IMongoQuery (created
by New-MdbcQuery), Mdbc.Dictionary, BsonDocument, JSON-like hashtables. Other
values are treated as _id and converted to _id queries.
'@

$QueryParameter = "Specifies documents to be processed. $QueryTypes"
$QueryParameterMandatory = @'
The parameter is mandatory and does not accept nulls. In order to specify all
documents use an empty query, e.g. @{}. Note that an empty string implies
@{_id=''}, not @{}.
'@

$AsParameter = @'
Specifies the representation of output documents. The argument is either a
required type or a shortcut enum value for special types.

A type specifies the output type literally. Type properties must match the
document fields or the custom type serialization must be registered.

Shortcuts, either enum values or strings:

	Default
		Default output, Mdbc.Dictionary with underlying BsonDocument.

	Lazy
		Mdbc.LazyDictionary with underlying LazyBsonDocument.
		Call Dispose() after use.

	Raw
		Mdbc.RawDictionary with underlying RawBsonDocument.
		Read only. Call Dispose() after use.

	PS
		PowerShell custom object.

By default result documents are represented by Mdbc.Dictionary with underlying
BsonDocument. See New-MdbcData for details. Use of its Lazy or Raw form may
improve performance in some cases.

In some scenarios other output types may be suitable like native .NET types
(-As ([Type])) and PowerShell custom objects (-As PS).

On choosing an output type keep in mind that Mdbc.Dictionary (BsonDocument)
field names are case sensitive unlike object properties in PowerShell.
'@

$SortByParameter = @'
Specifies sorting field names and directions. Values are either field names or
hashtables with single entries @{Field = <Boolean>}. $true and $false or their
equivalents are for ascending and descending sorting.
'@

$TypeWriteConcernResult = @{
	type = '[MongoDB.Driver.WriteConcernResult]'
	description = 'Result object from the driver is written if the switch Result is present.'
}

$AboutResultAndErrors = @'
In order to output command result objects from a server use the switch Result.

Depending on operations some server exceptions are caught and written as not
terminating errors, i.e. processing of remaining pipelined objects continues.

Parameters ErrorAction and variables $ErrorActionPreference are used to alter
error actions. See help about_CommonParameters and about_Preference_Variables.
'@

$DocumentInputs = @(
	@{
		type = '$null'
		description = @'
Null is converted to an empty document by New-MdbcData and ignored by
Add-MdbcData and Export-MdbcData.
'@
	}
	@{
		type = '[Mdbc.Dictionary]'
		description = @'
Objects created by New-MdbcData or obtained by Get-MdbcData or Import-MdbcData.
This type is the most effective and safe as input/output of Mdbc data cmdlets.

The native driver document [MongoDB.Bson.BsonDocument] can be used as well but
normally it should not be used directly. Its wrapper [Mdbc.Dictionary] is more
suitable in PowerShell.
'@
	}
	@{
		type = '[IDictionary]'
		description = @'
Dictionaries are converted to new documents. Keys are strings used as new field
names. Collection, dictionary, and custom object values are converted to BSON
container types recursively. Other values are converted to BsonValue.
'@
	}
	@{
		type = '[PSObject]'
		description = @'
Objects are converted to new documents. Property names are used as new field
names. Collection, dictionary, and custom object values are converted to BSON
container types recursively. Other values are converted to BsonValue.
'@
	}
)

$QueryInputs = @(
	@{
		type = '[MongoDB.Driver.IMongoQuery]'
		description = 'Query expression. See New-MdbcQuery (query).'
	}
	@{
		type = '[Mdbc.Dictionary]'
		description = @'
A document which _id is used for identification. Documents are created by
New-MdbcData or obtained by Get-MdbcData.
'@
	}
	@{
		type = '[object]'
		description = 'Other values are treated as requested _id values.'
	}
)

$FileFormatParameter = @'
Specifies the data file format:

 	Bson
 		BSON format

 	Json
 		JSON format

 	Auto (default)
 		The format is defined by the file extension: ".json" is for JSON,
 		other extensions are for BSON.

Input JSON is a sequence of objects and arrays of objects. Arrays are unrolled.
Top objects and arrays are optionally separated by spaces, tabs, and new lines.
'@

### Connect-Mdbc
@{
	command = 'Connect-Mdbc'
	synopsis = 'Connects a server, database, and collection.'
	description = @'
The cmdlet connects the specified server, database, and collection and creates
their reference variables in the current scope. With default names they are
Server, Database, and Collection.

The * used as a name tells to get all database names for a server or collection
names for a database.

If none of the parameters ConnectionString, DatabaseName, CollectionName is
specified then they are assumed to be ., test, test respectively.
'@

	parameters = @{
		ConnectionString = @'
	Connection string (see driver manuals for details):
	mongodb://[username:password@]hostname[:port][/[database][?options]]

	"." is used for the default driver connection.

	Example:
	mongodb://localhost:27017
'@
		DatabaseName = 'Database name. * is used in order to get all database objects.'
		CollectionName = 'Collection name. * is used in order to get all collection objects.'
		NewCollection = 'Tells to remove an existing collection if any and connect a new one.'
		ServerVariable = 'Name of a new variable in the current scope with the connected server. The default variable name is Server.'
		DatabaseVariable = 'Name of a new variable in the current scope with the connected database. The default variable name is Database.'
		CollectionVariable = $CollectionVariable
		Timeout = 'Determines the maximum time to wait before timing out.'
	}
	outputs = @(
		@{ type = 'None or database or collection names.' }
	)
	examples = @(
		@{
			code = {
				# Connect to a new collection (drop existing)
				Import-Module Mdbc
				Connect-Mdbc . test test -NewCollection
			}
			test = {
				. $args[0]
				if ($Collection.GetType().Name -ne 'MongoCollection`1') { throw }
			}
		}
		@{
			code = {
				# Connect to the database
				Import-Module Mdbc
				Connect-Mdbc . test

				# Then get collections
				$collection1 = $Database.GetCollection('test')
				$collection2 = $Database.GetCollection('process')
			}
			test = {
				. $args[0]
				if ($Database.GetType().Name -ne 'MongoDatabase') { throw }
				if ($collection1.FullName -ne 'test.test' ) { throw }
				if ($collection2.FullName -ne 'test.process' ) { throw }
			}
		}
		@{
			code = {
				# Connect to the server
				Import-Module Mdbc
				Connect-Mdbc mongodb://localhost

				# Then get the database
				$Database = $Server.GetDatabase('test')
			}
			test = {
				. $args[0]
				if ($Server.GetType().Name -ne 'MongoServer') { throw }
				if ($Database.GetType().Name -ne 'MongoDatabase') { throw }
			}
		}
		@{
			code = {
				# Connect to the default server and get all databases
				Import-Module Mdbc
				Connect-Mdbc . *
			}
			test = {
				$databases = . $args[0]
				# at least: local, test
				if ($databases.Count -lt 2) { throw }
				if ($databases[0].GetType().Name -ne 'MongoDatabase') { throw }
			}
		}
		@{
			code = {
				# Connect to the database 'test' and get all collections
				Import-Module Mdbc
				Connect-Mdbc . test *
			}
			test = {
				$collections = . $args[0]
				# at least: test, process
				if ($collections.Count -lt 2) { throw }
				if ($collections[0].GetType().Name -ne 'MongoCollection`1') { throw }
			}
		}
	)
	links = @(
		@{ text = 'Add-MdbcData' }
		@{ text = 'Get-MdbcData' }
		@{ text = 'Remove-MdbcData' }
		@{ text = 'Update-MdbcData' }
		@{ text = 'MongoDB'; URI = 'http://www.mongodb.org' }
	)
}

### ADatabase
$ADatabase = @{
	parameters = @{
		Database = @'
The database instance. If it is not specified then the variable Database is
used: it is defined by Connect-Mdbc or assigned explicitly before the call.
'@
	}
}

### ACollection
$ACollection = @{
	parameters = @{
		Collection = $CollectionParameter
	}
}

### AWrite
$AWrite = Merge-Helps $ACollection @{
	parameters = @{
		WriteConcern = 'Write concern options.'
		Result = 'Tells to output an object returned by the driver.'
	}
}

### New-MdbcData
@{
	command = 'New-MdbcData'
	synopsis = 'Creates data documents and some other driver types.'
	description = @'
This command is used to create one or more documents (input objects come from
the pipeline or as the first parameter InputObject) or a single BsonValue (by
the named parameter Value).

Created documents are used by Add-MdbcData and Export-MdbcData. These cmdlets
also have parameters Id, NewId, Convert, Property for making documents from
input objects. Thus, in some cases intermediate use of New-MdbcData is not
needed.

Mdbc.Dictionary

Result documents are returned as Mdbc.Dictionary objects. Mdbc.Dictionary holds
an underlying BsonDocument (Document()) and implements IDictionary. It works as
a hashtable where keys are case sensitive strings and input and output values
are convenient .NET types instead of underlying BsonValues. Main features:

Useful members:

	$dictionary.Count
	$dictionary.Contains('key')
	$dictionary.Add('key', 'value')
	$dictionary.Remove('key')
	$dictionary.Clear()

Setting values:

	$dictionary['key'] = ...
	$dictionary.key = ...

Getting values:

	.. = $dictionary['key']
	.. = $dictionary.key

NOTE: On getting values the form "$dictionary.key" fails in strict mode (see
Set-StrictMode) if the "key" is missing. The form "$dictionary['key'] is safe,
it returns null for a missing key. Use Contains() in order to check existence
of a key for sure.
'@
	parameters = @{
		InputObject = @'
.NET object to be converted to Mdbc.Dictionary, PowerShell friendly wrapper of
BsonDocument. Objects suitable for conversion are dictionaries, custom objects,
and complex .NET types, normally not collections.
'@
		Id = $IdParameter
		NewId = $NewIdParameter
		Convert = $ConvertParameter
		Property = $PropertyParameter
		Value = @'
An object to be converted to a BsonValue.

Cmdlets and helper types do not need BsonValue's, they convert everything
themselves. But BsonValue's may be needed for calling driver methods directly.

Containers:

	[IDictionary] is converted to BsonDocument.
	[IEnumerable] is converted to BsonArray.

Primitives:

	[bool]     is converted to BsonBoolean.
	[DateTime] is converted to BsonDateTime.
	[double]   is converted to BsonDouble.
	[Guid]     is converted to BsonBinaryData (and retrieved back as [Guid]).
	[int]      is converted to BsonInt32.
	[long]     is converted to BsonInt64.
	[string]   is converted to BsonString.

If a primitive type is known than it is much more effective to create it
directly than by this cmdlet, e.g. for a string:

	[MongoDB.Bson.BsonString]'Some text'
'@
	}
	inputs = $DocumentInputs
	outputs = @(
		@{
			type = '[Mdbc.Dictionary]'
			description = 'BsonDocument wrapper created from InputObject.'
		}
		@{
			type = '[MongoDB.Bson.BsonValue]'
			description = 'BsonValue objects created from Value.'
		}
	)
	examples = @(
		@{
			code = {
				# Connect to the collection
				Import-Module Mdbc
				Connect-Mdbc . test test -NewCollection

				# Create a new document, set some data
				$data = New-MdbcData -Id 12345
				$data.Text = 'Hello world'
				$data.Date = Get-Date

				# Add the document to the database
				$data | Add-MdbcData

				# Query the document from the database
				$result = Get-MdbcData (New-MdbcQuery _id 12345)
				$result
			}
			test = {
				. $args[0]
				if ($result.Text -ne 'Hello world') { throw }
			}
		}
		@{
			code = {
				# Connect to the collection
				Import-Module Mdbc
				Connect-Mdbc . test test -NewCollection

				# Create data from input objects and add to the database
				Get-Process mongod |
				New-MdbcData -Id {$_.Id} -Property Name, WorkingSet, StartTime |
				Add-MdbcData

				# Query the data
				$result = Get-MdbcData
				$result
			}
			test = {
				. $args[0]
				$result = @($result)
				if ($result[0].Name -ne 'mongod') { throw }
			}
		}
		@{
			code = {
				# Example of various forms of property expressions.
				# Note that ExitCode throws, so that Code will be null.

				New-MdbcData (Get-Process -Id $Pid) -Property `
					Name,                         # existing property name
					Missing,                      # missing property name is ignored
					@{WS1 = 'WS'},                # @{name = old name} - renamed property
					@{WS2 = {$_.WS}},             # @{name = scriptblock} - calculated field
					@{Ignored = 'Missing'},       # renaming of a missing property is ignored
					@{n = '_id'; e = 'Id'},       # @{name=...; expression=...} like Select-Object does
					@{l = 'Code'; e = 'ExitCode'} # @{label=...; expression=...} another like Select-Object
			}
			test = {
				$r = . $args[0]
				if ($r.Count -ne 5) { throw }
			}
		}
	)
	links = @(
		@{ text = 'Add-MdbcData' }
		@{ text = 'Export-MdbcData' }
	)
}

### New-MdbcQuery
$OneArgumentAndOr = @'
One argument can be used as well. For a previously created query it creates the
same query. But it can be used for creating a query from other supported input
types like hashtables.
'@
@{
	command = 'New-MdbcQuery'
	synopsis = 'Creates a query expression for other commands.'
	description = @'
The cmdlet creates a query expression used by Get-MdbcData, Remove-MdbcData,
Update-MdbcData. Parameters are named after the driver query builder methods.
Most of queries have their alternative JSON-like forms, see parameter help.
'@
	parameters = @{
		Name = @'
Field name for a field value test.
'@
		Not = @'
Tells to negate the query expression.
JSON-like form: @{name = @{'$not' = operator-expression}
'@, $QueryTypes
		And = @'
Logical And, normally on two or more query expressions.
JSON-like form: @{'$and' = @(query-expression1, query-expression2, ...)}
'@, $OneArgumentAndOr, $QueryTypes
		Or = @'
Logical Or, normally on two or more query expressions.
JSON-like form: @{'$or' = @(query-expression1, query-expression2, ...)}
'@, $OneArgumentAndOr, $QueryTypes
		EQ = @'
Equality test. Parameter name is optional.
JSON-like form: @{name = value}
'@
		NE = @'
Inequality test.
JSON-like form: @{name = @{'$ne' = value}}
'@
		IEQ = @'
Ignore case equality test for strings.
JSON-like form is not available.
'@
		INE = @'
Ignore case inequality test for strings.
JSON-like form is not available.
'@
		GT = @'
Greater than test.
JSON-like form: @{name = @{'$gt' = value}}
'@
		GTE = @'
Greater or equal test.
JSON-like form: @{name = @{'$gte' = value}}
'@
		LT = @'
Less than test.
JSON-like form: @{name = @{'$lt' = value}}
'@
		LTE = @'
Less or equal test.
JSON-like form: @{name = @{'$lte' = value}}
'@
		Exists = @'
Checks if the field exists.
JSON-like form: @{name = @{'$exists' = $true}}
'@
		NotExists = @'
Checks if the field is missing.
JSON-like form: @{name = @{'$exists' = $false}}
'@
		Matches = @'
Regular expression test.
JSON-like form: @{name = @{'$regex' = pattern; '$options' = 'i|m|x|s'}}
'@, @'
The argument is one or two items. A single item is either a regular expression
string pattern or a regular expression object. Two items are both strings: a
regular expression pattern and options, combination of characters 'i', 'm',
'x', 's'.
'@
		Mod = @'
Modulo test.
JSON-like form: @{name = @{'$mod' = @(divisor, remainder)}}
'@, @'
The argument is an array of two items: the modulus and the result value to be tested.
'@
		Size = @'
Array item count test.
JSON-like form: @{name = @{'$size' = value}}
'@
		Type = @'
Element type test.
JSON-like form: @{name = @{'$type' = type}}
'@
		In = @'
Checks if the field value equals or matches to one of the specified values or
regular expressions.
JSON-like form: @{name = @{'$in' = @(value1, value2, ...)}
'@
		NotIn = @'
Checks if the field is missing or its value does not equal or match to any of
the specified values or regular expressions.
JSON-like form: @{name = @{'$nin' = @(value1, value2, ...)}
'@
		All = @'
Checks if the array contains all the specified values.
JSON-like form: @{name = @{'$all' = @(value1, value2, ...)}
'@
		ElemMatch = @'
Checks if an element in an array matches all the specified query expressions.
JSON-like form: @{name = @{'$elemMatch' = @(expression1, expression2, ...)}}
'@, @'
It is needed only when more than one field must be matched in an array element.
'@
		Where = @'
JavaScript Boolean expression test.
JSON-like form: @{'$where' = code}
'@, @'
The database evaluates the expression for each object scanned. JavaScript
executes more slowly than native operators but is very flexible. See the
server-side processing page for more information (official site).
'@
	}
	outputs = @{
		type = '[MongoDB.Driver.IMongoQuery]'
		description = 'Used by Get-MdbcData, Remove-MdbcData, Update-MdbcData, ...'
	}
	links = @(
		@{ text = 'Get-MdbcData' }
		@{ text = 'Remove-MdbcData' }
		@{ text = 'Update-MdbcData' }
		@{ text = 'MongoDB'; URI = 'http://www.mongodb.org' }
	)
}

### New-MdbcUpdate
@{
	command = 'New-MdbcUpdate'
	synopsis = 'Creates an update expression for Update-MdbcData.'
	description = @'
This cmdlet creates update expressions used by Update-MdbcData. Parameters are
named after driver update builder methods. They can be combined in order to
create complex updates in a single call.

Some parameters (Unset, PopFirst, PopLast) require only field names (String[]).
Example:

	New-MdbcUpdate -Unset field1 -PopLast field2, field3

Other parameters require field names and associated arguments. Such parameters
accept one or more hashtables (IDictionary). Each hashtable defines field names
as keys and arguments as their values. The following commands are essentially
the same:

	# Two hashtables with single entries
	New-MdbcUpdate -Set @{field1 = value1}, @{field2 = value2}

	# One hashtable with two entries
	New-MdbcUpdate -Set @{
		field1 = value1
		field2 = value2
	}
'@
	parameters = @{
		AddToSet = @'
Adds a value to an array only if the value is not in the array already.

If a field argument is a collection then it is treated as a single value to
add. Use AddToSetEach in order to add each value.

Mongo: { $addToSet: { field: <addition> }
'@
		AddToSetEach = @'
Adds values to an array only if the values are not in the array already.

Mongo: { $addToSet: { field: { $each: [ <value1>, <value2> ... ] } } }
'@
		BitwiseAnd = @'
Performs bitwise AND update of integer values (int or long).

Mongo: { $bit: { field: { and: NumberInt(5) } } }
'@
		BitwiseOr = @'
Performs bitwise OR update of integer values (int or long).

Mongo: { $bit: { field: { or: NumberInt(5) } } }
'@
		BitwiseXor = @'
Performs bitwise XOR update of integer values (int or long).

Mongo: { $bit: { field: { xor: NumberInt(5) } } }
'@
		Inc = @'
Increments a field by a specified number. If a field does not exist, it adds
the field and sets it to the specified value. It accepts positive and negative
values (int, long, or double).

Mongo: { $inc: { field: <number> } }
'@
		Mul = @'
Multiplies a field by a specified number. The field to update must contain a
numeric value. If the field does not exist, it creates the field and sets the
value to zero of the same numeric type as the multiplier.

Mongo: { $mul: { field: <number> } }
'@
		Min = @'
The $min updates the value of the field to a specified value if the specified
value is less than the current value of the field. If the field does not
exists, the $min operator sets the field to the specified value. The $min
operator can compare values of different types, using the BSON comparison
order.

Mongo: { $min: { field: <value> } }
'@
		Max = @'
The $max operator updates the value of the field to a specified value if the
specified value is greater than the current value of the field. If the field
does not exists, the $max operator sets the field to the specified value. The
$max operator can compare values of different types, using the BSON comparison
order.

Mongo: { $max: { field: <value> } }
'@
		PopFirst = @'
Removes the first element in an array.

It fails if a field is not an array. When it removes the last remaining item
a field holds an empty array.

Mongo: { $pop: { field: -1 } }
'@
		PopLast = @'
Removes the last element in an array.

It fails if a field is not an array. When it removes the last remaining item
a field holds an empty array.

Mongo: { $pop: { field: 1 } }
'@
		Pull = @"
Removes matching values from a field if it is an array. It fails if a field is
present but it is not an array.

If a field argument is a collection then it is treated as a single value to
pull. Use PullAll in order to remove each value.

If a field argument is a query expression than items matching the expression
are removed. $QueryTypes

Mongo: { `$pull: { field: <value>|<query> } }
"@
		PullAll = @'
Removes multiple values from an existing array. PullAll provides the inverse
operation of the PushAll operator.

Mongo: { $pullAll: { field: [ value1, value2, ... ] } }
'@
		Push = @'
Appends a value to a field if it is an existing array, otherwise sets a field
to an array with one value. It fails if a field is present but it is not an
array.

If a field argument is a collection then it is treated as a single value to
push. Use PushAll in order to push all values.

Mongo: { $push: { field: <value> }
'@
		PushAll = @'
Appends all values to an array.

Mongo: { $push: { field: { $each: [ value1, valu2 ... ] } } }
'@
		Rename = @'
Renames a field. A field argument is a new field name.

Mongo: { $rename: { <old name1>: <new name1> }, ... }
'@
		Set = @'
Sets a field value. This parameter name can be omitted in a command, i.e. these
commands are the same:

	New-MdbcUpdate @{field = value}

	New-MdbcUpdate -Set @{field = value}

Mongo: { $set: { field1: <value1>, ... } }
'@
		SetOnInsert = @'
Sets a field value on adding a new document during update. It has no effect on
updates that modify existing documents.

Mongo: { $setOnInsert: { field1: <value1>, ... } }
'@
		Unset = @'
Tells to remove a field from an existing document.

Mongo: { $unset: { field1: "", ... } }
'@
		CurrentDate = @'
The $currentDate operator sets the value of a field to the current date.

Mongo: { $currentDate: { field: true } }
'@
	}
	outputs = @{
		type = '[MongoDB.Driver.IMongoUpdate]';
		description = 'Update expression used by Update-MdbcData.'
	}
	links = @(
		@{ text = 'Update-MdbcData' }
	)
}

### Add-MdbcData
Merge-Helps $AWrite @{
	command = 'Add-MdbcData'
	synopsis = 'Adds new documents to the database collection or updates existing.'
	description = 'Adds new documents to the database collection or updates existing.', $AboutResultAndErrors
	parameters = @{
		InputObject = 'Document or a similar object, see INPUTS.'
		Update = 'Tells to update existing documents with the same _id or add new documents otherwise.'
		Id = $IdParameter
		NewId = $NewIdParameter
		Convert = $ConvertParameter
		Property = $PropertyParameter
	}
	inputs = $DocumentInputs
	outputs = $TypeWriteConcernResult
	links = @(
		@{ text = 'New-MdbcData' }
		@{ text = 'Select-Object' }
	)
}

### Get-MdbcData
Merge-Helps $ACollection @{
	command = 'Get-MdbcData'
	synopsis = @'
Gets documents or information from a database collection.
'@
	description = @'
This cmdlets invokes queries for the specified or default collection and
outputs result documents or other data according to the parameters.
'@
	parameters = @{
		Query = $QueryParameter
		As = $AsParameter
		Count = @'
Tells to return the number of all documents or matching the Query.
The First and Skip values are taken into account.
'@
		Distinct = @'
Specifies the field name and tells to return its distinct values for all
documents or documents matching the Query.
'@
		Remove = @'
Tells to remove and get the first document specified by Query and SortBy.
'@
		Update = @'
Specifies an update expression and tells to update and get the first document
specified by Query and SortBy (FindAndModify method).
'@
		New = @'
Tells to return new documents on Update.
By default old documents are returned.
'@
		Add = @'
Tells to add new documents on Update if old documents do not exist.
'@
		Property = @'
Subset of fields to be retrieved. Note that the field _id is always included
unless it is explicitly excluded.

The argument is either strings specifying fields to be included or a single
IMongoFields object which provides more options on selection of fields and
their data (Include, Exclude, Slice, ElemMatch).
'@
		SortBy = $SortByParameter
		Modes = @'
Additional query options.
See the driver manual.
'@
		First = @'
Specifies the number of first documents to be returned.
Non positive values are ignored.
'@
		Last = @'
Specifies the number of last documents to be returned.
Non positive values are ignored.
'@
		Skip = @'
Specifies the number of documents to skip from the beginning or from the end if
Last is specified. Skipping is applied to results before taking First or Last.
Non positive values are ignored.
'@
		ResultVariable = @'
Tells to store the update result as a variable with the specified name. The
result object properties: DocumentsAffected (long), UpdatedExisting (bool).
'@
	}
	outputs = @(
		@{
			type = 'Int64'
			description = 'If Count or Size is requested.'
		}
		@{
			type = 'object'
			description = 'If the Distinct field name is specified.'
		}
		@{
			type = 'Mdbc.Dictionary or custom objects'
			description = 'Documents, see New-MdbcData about Mdbc.Dictionary.'
		}
	)
	links = @(
		@{ text = 'Connect-Mdbc' }
		@{ text = 'New-MdbcQuery' }
	)
}

### Remove-MdbcData
Merge-Helps $AWrite @{
	command = 'Remove-MdbcData'
	synopsis = 'Removes specified documents from the collection.'
	description = 'Removes specified documents from the collection.', $AboutResultAndErrors
	parameters = @{
		Query = $QueryParameter, $QueryParameterMandatory
		One = @'
Tells to remove one document. By default the command removes all matching
documents. Note that this is different to default Update-MdbcData and the
difference is kept in order to follow the driver API.
'@
	}
	inputs = $QueryInputs
	outputs = $TypeWriteConcernResult
	links = @(
		@{ text = 'Connect-Mdbc' }
		@{ text = 'New-MdbcQuery' }
	)
}

### Update-MdbcData
Merge-Helps $AWrite @{
	command = 'Update-MdbcData'
	synopsis = 'Updates the specified documents.'
	description = @'
Applies the specified update to documents matching the specified query.
'@, $AboutResultAndErrors
	parameters = @{
		Query = $QueryParameter, $QueryParameterMandatory
		Update = @'
One or more update expressions either created by New-MdbcUpdate or hashtables
representing JSON-like updates. Two and more expression are combined together
internally.

The parameter is mandatory and does not accept nulls.
'@
		Add = @'
Tells to add a document based on the update and query if nothing was updated.
'@
		All = @'
Tells to update all matching documents. By default one is updated. Note that
this is different to default Remove-MdbcData and the difference is kept in
order to follow the driver API.
'@
	}
	inputs = $QueryInputs
	outputs = $TypeWriteConcernResult
	links = @(
		@{ text = 'Connect-Mdbc' }
		@{ text = 'New-MdbcUpdate' }
	)
}

### Add-MdbcCollection
Merge-Helps $ADatabase @{
	command = 'Add-MdbcCollection'
	synopsis = 'Creates a new collection in a database.'
	description = @'
This cmdlet is needed only for creation of collections with extra options, like
capped collections. Ordinary collections do not have to be added explicitly.
'@
	parameters = @{
		Name = @'
The name of a new collection.
'@
		MaxSize = @'
Sets the max size of a capped collection.
'@
		MaxDocuments = @'
Sets the max number of documents in a capped collection in addition to MaxSize.
'@
		AutoIndexId = @'
It may be set to true or false to explicitly enable or disable automatic
creation of a unique key index on the _id field.
'@
	}
}

### Invoke-MdbcCommand
Merge-Helps $ADatabase @{
	command = 'Invoke-MdbcCommand'
	synopsis = 'Invokes a command for a database.'
	description = @'
This cmdlet is normally used in order to invoke commands not covered by the
driver or Mdbc helpers. See MongoDB manuals for available commands and their
parameters.
'@
	parameters = @{
		Command = @'
Either the name of command with no arguments or one argument or a JSON-like
hashtable that defines a more complex command, for example:

	Invoke-MdbcCommand @{create='test'; capped=$true; size=1kb; max=5 }

If the element order in a command is important then hashtables may not work.
Use Mdbc.Dictionary instead:

	$c = New-MdbcData
	$c.create = 'test'
	$c.capped = $true
	$c.size = 1kb
	$c.max = 5
	Invoke-MdbcCommand $c
'@
		Value = @'
The argument value required by the command with one argument.
'@
	}
	outputs = @{
		type = 'Mdbc.Dictionary'
		description = 'The response document wrapped by Mdbc.Dictionary.'
	}
	links = @(
		@{ text = 'MongoDB'; URI = 'http://www.mongodb.org' }
	)
	examples = @(
		@{
			code = {
				# Invoke the command `serverStatus` just by name.

				Connect-Mdbc . test
				Invoke-MdbcCommand serverStatus
			}
			test = {
				$response = . $args[0]
				if ($response.host -ne $env:COMPUTERNAME) {throw}
			}
		}
		@{
			code = {
				# Connect to the database `test` and invoke the command with a
				# single parameter `global` with the `admin` database specified
				# explicitly (because the current is `test` and the command is
				# admin-only)

				Connect-Mdbc . test
				Invoke-MdbcCommand getLog global -Database $Server['admin']
			}
			test = {
				$response = . $args[0]
				if (!$response.log) {throw}
			}
		}
		@{
			code = {
				# The example command creates a capped collection with maximum
				# set to 5 documents, adds 10 documents, then gets all back (5
				# documents are expected).

				Connect-Mdbc . test test -NewCollection

				$c = New-MdbcData
				$c.create = 'test'
				$c.capped = $true
				$c.size = 1kb
				$c.max = 5

				$null = Invoke-MdbcCommand $c

				# set the default collection
				$Collection = $Database['test']

				# add 10 documents
				1..10 | %{ @{_id = $_} } | Add-MdbcData

				# get 5 documents
				Get-MdbcData
			}
			test = {
				$data = . $args[0]
				if ($data.Count -ne 5) {throw}
			}
		}
	)
}

### Invoke-MdbcAggregate
Merge-Helps $ACollection @{
	command = 'Invoke-MdbcAggregate'
	synopsis = 'Invokes aggregate operations and outputs result documents.'
	description = @'
The driver currently provides just a raw API for aggregate operations. So does
this cmdlet. When the API change the cmdlet will be redesigned.
'@
	parameters = @{
		Pipeline = @'
One or more aggregation pipeline operations represented by JSON-like hashtables.
'@
		BatchSize = 'Specifies the size of a batch when using a cursor.'
		MaxTime = 'Specifies the max time the server should spend on the aggregation command.'
		AllowDiskUse = 'Tells to allow disk use.'
	}
	outputs = @(
		@{
			type = '[Mdbc.Dictionary]'
			description = 'Result documents.'
		}
	)
	examples = @(
		@{
			# _131016_142302
			code = {
				# Data: current process names and memory working sets
				Connect-Mdbc . test test -NewCollection
				Get-Process | Add-MdbcData -Property Name, WorkingSet

				# Group by names, count, sum memory, get top 3
				Invoke-MdbcAggregate @(
					@{ '$group' = @{
						_id = '$Name'
						Count = @{ '$sum' = 1 }
						Memory = @{ '$sum' = '$WorkingSet' }
					}}
					@{ '$sort' = @{Memory = -1} }
					@{ '$limit' = 3 }
				)
			}
		}
	)
}

### Invoke-MdbcMapReduce
Merge-Helps $ACollection @{
	command = 'Invoke-MdbcMapReduce'
	synopsis = 'Invokes a Map/Reduce command.'
	description = ''
	parameters = @{
		As = $AsParameter, @'
This parameter is used with inline output.
'@
		First = @'
The maximum number of input documents.
It is used together with Query and normally with SortBy.
'@
		Function = @'
Two (Map and Reduce) or three (Map, Reduce, Finalize) JavaScript snippets which
define the functions. Use Scope in order to set variables that can be used in
the functions.
'@
		JSMode = @'
Tells to use JS mode which avoids some conversions BSON <-> JS. The execution
time may be significantly reduced. Note that this mode is limited by JS heap
size and a maximum of 500k unique keys.
'@
		OutCollection = @'
Name of the output collection. If it is omitted then inline output mode is
used, result documents are written to the output directly.
'@
		OutDatabase = @'
Name of the output database, used together with Collection.
By default the database of the input collection is used.
'@
		OutMode = @'
Specifies the output mode, used together with Collection. The default value is
Replace (all the existing data are replaced with new). Other valid values are
Merge and Reduce. Merge: new data are either added or replace existing data
with the same keys. Reduce: the Reduce function is applied.
'@
		Query = $QueryParameter
		ResultVariable = @'
Tells to get the result object as a variable with the specified name. The
result object type is MapReduceResult. Some properties: Ok, ErrorMessage,
InputCount, EmitCount, OutputCount, Duration.
'@
		Scope = @'
Specifies the variables that can be used by Map, Reduce, and Finalize functions.
'@
		SortBy = $SortByParameter, @'
This parameter is used together with Query.
'@
	}
	outputs = @(
		@{
			type = 'Mdbc.Dictionary or custom objects'
			description = 'Result documents of Map/Reduce on inline output.'
		}
	)
	links = @(
		@{ text = 'MongoDB'; URI = 'http://www.mongodb.org' }
	)
}

### Export-MdbcData
$ExampleIOCode = {
	@{ p1 = 'Name1'; p2 = 42 }, @{ p1 = 'Name2'; p2 = 3.14 } | Export-MdbcData test.bson
	Import-MdbcData test.bson -As PS
}
@{
	command = 'Export-MdbcData'
	synopsis = 'Exports objects to a BSON file.'
	description = @'
The cmdlet writes BSON representation of input objects to the specified file.
The output file has the same format as .bson files produced by mongodump.exe.

Cmdlets Export-MdbcData and Import-MdbcData do not need any database connection
or even MongoDB installed. They are used for file based object persistence on
their own.

Files created by Export-MdbcData may be opened as collections by Open-MdbcFile
with some caveats. Documents should not contain invalid names *.* and $*. If
documents do not have unique _id's then the switch Simple should be used.
'@
	parameters = @{
		Path = @'
Specifies the path to the file where BSON representation of objects will be stored.
'@
		Append = 'Tells to append data to the file if it exists.'
		InputObject = 'Document or a similar object, see INPUTS.'
		Id = $IdParameter
		NewId = $NewIdParameter
		Convert = $ConvertParameter
		Property = $PropertyParameter
		FileFormat = $FileFormatParameter
		Retry = @'
Tells to retry on failures to open the file and specifies one or two arguments.
The first is the retry timeout. The second is the retry interval, the default
is 50 milliseconds.
'@
	}
	inputs = $DocumentInputs
	examples = @(
		@{
			code = $ExampleIOCode
			test = {
				Push-Location C:\TEMP
				$data = . $args[0]
				if ($data.Count -ne 2) {throw}
				Remove-Item test.bson
				Pop-Location
			}
		}
		@{code={
			# "Safe" logging by several writers
			$data | Export-MdbcData $file -Append -Retry ([TimeSpan]::FromSeconds(10))
		}}
	)
	links = @(
		@{ text = 'Import-MdbcData' }
		@{ text = 'Open-MdbcFile' }
		@{ text = 'Save-MdbcFile' }
	)
}

### Import-MdbcData
@{
	command = 'Import-MdbcData'
	synopsis = 'Imports data from a file.'
	description = @'
The cmdlet reads data from a BSON file. Such files are produced, for example,
by the cmdlet Export-MdbcData or by the utility mongodump.exe.

Cmdlets Export-MdbcData and Import-MdbcData do not need any database connection
or even MongoDB installed. They are used for file based object persistence on
their own.
'@
	parameters = @{
		Path = @'
Specifies the path to the BSON file where objects will be restored from.
'@
		As = $AsParameter
		FileFormat = $FileFormatParameter
	}

	outputs = @(
		@{
			type = '[Mdbc.Dictionary]'
			description = 'Default, Lazy, or Raw form depending on the parameter As.'
		}
		@{
			type = '[object]'
			description = 'Custom objects specified by the parameter As.'
		}
	)

	examples = @(
		@{code=$ExampleIOCode}
		@{code={
	# Import data produced by ConvertTo-Json (PowerShell V3)
	Get-Process | ConvertTo-Json | Set-Content process.json
	Import-MdbcData process.json
		}}
	)

	links = @(
		@{ text = 'Export-MdbcData' }
		@{ text = 'Open-MdbcFile' }
		@{ text = 'Save-MdbcFile' }
	)
}

### Open-MdbcFile
$OpenSaveExample = @{
	code = {
		# Open existing or new bson file collection
		Open-MdbcFile data.bson

		# Use Get-MdbcData, Add-MdbcData, Remove-MdbcData, Update-MdbcData
		# ...

		# Save data
		Save-MdbcFile
	}
}
@{
	command = 'Open-MdbcFile'
	synopsis = 'Opens a bson file as a collection.'
	description = @'
This cmdlet opens a bson file as a collection for operations Get-MdbcData,
Add-MdbcData, Remove-MdbcData, and Update-MdbcData. Save-MdbcFile is used in
order to save data to the source file or another file. Such scenarios do not
require MongoDB running or even installed.

NORMAL AND SIMPLE DATA

In the normal mode which is the default documents in a file must have unique
_id's. If new documents have no _id's then they are generated on insertions.

The simple mode is specified by the switch Simple. Presence and uniqueness of
document _id's is not maintained. Operations like Add-MdbcData -Update are not
supported.

INVALID ELEMENT NAMES

Document element names like *.* and $* are invalid in collections because query
and update expressions use the dot notation for nested items and special names
$* for operators.

Nevertheless Open-MdbcFile does not perform name checks on reading assuming
that the file was created and maintained only by cmdlets listed above and it
contains valid names.

Remember that files created in a different way, for example by Export-MdbcData,
may contain problematic names for using them as collections with Open-MdbcFile.
'@
	parameters = @{
		Path = @'
Specifies the bson file path. If the file does not exists then the collection
is empty and the file is not created until it is saved. If the path is omitted
or empty then the collection is empty and Save-MdbcFile will require a path.
'@
		Simple = @'
Tells to operate on simple data, i.e. do not maintain presence and uniqueness
of document _id's. Some operations like Add-MdbcData -Update are not supported.
'@
		NewCollection = @'
Tells to open an empty collection. If the source file path is specified then it
is simply stored for saving, the source file is not touched at this moment.
'@
		CollectionVariable = $CollectionVariable
		FileFormat = $FileFormatParameter
	}

	examples = $OpenSaveExample, @{code={
	# Open and query data produced by ConvertTo-Json (PowerShell V3)
	Get-Process | ConvertTo-Json -Depth 1 | Set-Content process.json
	Open-MdbcFile process.json -Simple
	Get-MdbcData @{Name='mongod'}
	}}

	links = @(
		@{ text = 'Save-MdbcFile' }
		@{ text = 'Get-MdbcData' }
		@{ text = 'Add-MdbcData' }
		@{ text = 'Remove-MdbcData' }
		@{ text = 'Update-MdbcData' }
	)
}

### Save-MdbcFile
@{
	command = 'Save-MdbcFile'
	synopsis = 'Saves data to a bson file.'
	description = @'
This cmdlet saves the collection data to the specified or the original file.
'@
	parameters = @{
		Collection = @'
Collection object created by Open-MdbcFile. If it is omitted then the variable
Collection is used which is assumed to be created by Open-MdbcFile by default.

It is not an error to call this cmdlet for a native driver collection. Such a
call is simply ignored.
'@
		Path = @'
Specifies the bson file path for saving data. If it is omitted or empty then
the path used on opening is assumed. If it was not provided as well then an
error is thrown.
'@
		FileFormat = $FileFormatParameter, @'
This parameter is ignored if the path is omitted or empty.
'@
	}
	examples = @($OpenSaveExample)
	links = @(
		@{ text = 'Open-MdbcFile' }
		@{ text = 'Get-MdbcData' }
		@{ text = 'Add-MdbcData' }
		@{ text = 'Remove-MdbcData' }
		@{ text = 'Update-MdbcData' }
	)
}
