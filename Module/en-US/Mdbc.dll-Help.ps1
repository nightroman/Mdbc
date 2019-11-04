<#
.Synopsis
	Help script (https://github.com/nightroman/Helps)
#>

Import-Module Mdbc
Set-StrictMode -Version Latest

### Shared descriptions

$IdParameter = @'
The document _id value to be assigned or a script block returning this value
for the input object represented by the variable $_.

_id must not exist in input objects or Property.
'@

$NewIdParameter = @'
Tells to generate and assign a new document _id as MongoDB.Bson.ObjectId.

_id must not exist in input objects or Property.
'@

$ConvertParameter = @'
A script called on conversion of unknown data types. The variable $_ represents
the unknown object. The script returns a new object suitable for conversion.

Examples: {} converts unknown data to nulls. {"$_"} converts data to strings.

Converters should be used sparingly, normally with unknown or varying data.
'@

$PropertyParameter = @'
Specifies properties or keys which values are included into documents or
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

$ClientParameter = @'
Client instance. If it is omitted then the variable $Client is used.
It is obtained by Connect-Mdbc or using the driver API.
'@

$DatabaseParameter = @'
Database instance. If it is omitted then the variable $Database is used.
It is obtained by Connect-Mdbc, Get-MdbcDatabase, or using the driver API.
'@

$CollectionParameter = @'
Collection instance. If it is omitted then the variable $Collection is used.
It is obtained by Connect-Mdbc, Get-MdbcCollection, or using the driver API.
'@

$FilterParameter = @'
Specifies the document(s) to be processed.
The argument is either JSON or similar dictionary.
'@

$FilterParameterMandatory = @'
The parameter is mandatory and does not accept nulls. In order to specify all
documents use an empty filter, e.g. @{}.
'@

$UpdateParameter = @'
Specifies the update expression.
The argument is JSON, similar dictionary, or array for aggregate expressions.
'@

$AsParameter = @'
Specifies the output document type. The argument is either the required type or
the special type shortcut.

A type specifies the output type literally. Type properties should match the
document fields or the custom type serialization must be registered.

Special type shortcut strings or enum values:

	Default
		Default output, Mdbc.Dictionary with underlying BsonDocument.

	PS
		PowerShell custom object.

On choosing an output type keep in mind that Mdbc.Dictionary (BsonDocument)
field names are case sensitive unlike other object properties in PowerShell.
'@

$SortParameter = @'
Specifies the sorting expression, field names and directions.
The argument is either JSON or similar dictionary.

If two or more fields are specified then mind the order.
Use JSON or ordered dictionaries, e.g. `[ordered]@{..}`.
'@

$ResultParameter = @'
Tells to output the operation result info.
'@

$AboutResultAndErrors = @'
In order to output the result info use the switch Result.

Depending on operations and settings some server exceptions are caught and
written as not terminating errors, i.e. processing continues.

Parameters ErrorAction and variables $ErrorActionPreference are used to alter
error actions. See help about_CommonParameters and about_Preference_Variables.
'@

$DocumentInputs = @(
	@{
		type = '[Mdbc.Dictionary]'
		description = @'
Objects created by New-MdbcData or obtained by Get-MdbcData or Import-MdbcData.
This type is the most effective and safe as input/output of Mdbc data cmdlets.

The native driver document [MongoDB.Bson.BsonDocument] may be used as well but
its wrapper [Mdbc.Dictionary] is more suitable in PowerShell.
'@
	}
	@{
		type = '[IDictionary]'
		description = @'
Hashtables and other dictionaries are converted to new documents. Keys are
strings used as field names. Nested collections, dictionaries, and custom
objects are converted to BSON documents and collections recursively. Other
values are converted to BSON values.
'@
	}
	@{
		type = '[PSObject]'
		description = @'
Objects are converted to new documents. Property names are used as field names.
Nested collections, dictionaries, and custom objects are converted to BSON
documents and collections recursively. Other values are converted to BSON
values.
'@
	}
	@{
		type = '$null'
		description = @'
Null is converted to an empty document by New-MdbcData and ignored by
Add-MdbcData and Export-MdbcData.
'@
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
	synopsis = 'Connects the client, database, and collection.'
	description = @'
The cmdlet connects to the specified server and creates the variables for
client, database, and collection in the current scope. By default they are
$Client, $Database, and $Collection.

If none of the parameters ConnectionString, DatabaseName, CollectionName is
specified then they are assumed to be ".", "test", "test" respectively.
'@

	parameters = @{
		ConnectionString = @'
	Connection string (see driver manuals for details):
	mongodb://[username:password@]hostname[:port][/[database][?options]]

	"." is used for the default driver connection.

	Examples:
		mongodb://localhost:27017
		mongodb://myaccount:mypass@remotehost.example.com
'@
		DatabaseName = 'Database name. Use * in order to get available names.'
		CollectionName = 'Collection name. Use * in order to get available names.'
		NewCollection = 'Tells to remove an existing collection before connecting the specified.'
		ClientVariable = @'
Name of a new variable in the current scope with the connected client.
The default variable is $Client.
Cmdlets with the parameter Client use it as the default value.
'@
		DatabaseVariable = @'
Name of a new variable in the current scope with the connected database.
The default variable is $Database.
Cmdlets with the parameter Database use it as the default value.
'@
		CollectionVariable = @'
Name of a new variable in the current scope with the connected collection.
The default variable is $Collection.
Cmdlets with the parameter Collection use it as the default value.
'@
	}
	outputs = @(
		@{ type = 'None or database or collection names.' }
	)
	examples = @(
		@{
			code = {
				# Connect a new collection (drop existing)
				Import-Module Mdbc
				Connect-Mdbc . test test -NewCollection
			}
			test = {
				. $args[0]
				if ($Collection.GetType().Name -notmatch 'MongoCollection') { throw }
			}
		}
		@{
			code = {
				# Connect the database `test`
				Import-Module Mdbc
				Connect-Mdbc . test

				# Then get collections
				$collection1 = Get-MdbcCollection test
				$collection2 = Get-MdbcCollection process
			}
			test = {
				. $args[0]
				if ($Database.GetType().Name -notmatch 'MongoDatabase') { throw }
				if ($collection1.CollectionNamespace.FullName -ne 'test.test' ) { throw }
				if ($collection2.CollectionNamespace.FullName -ne 'test.process' ) { throw }
			}
		}
		@{
			code = {
				# Connect the client
				Import-Module Mdbc
				Connect-Mdbc mongodb://localhost

				# Then get the database
				$Database = Get-MdbcDatabase test
			}
			test = {
				. $args[0]
				if ($Client.GetType().Name -notmatch 'MongoClient') { throw }
				if ($Database.GetType().Name -notmatch 'MongoDatabase') { throw }
			}
		}
		@{
			code = {
				# Connect the local and get databases
				Import-Module Mdbc
				Connect-Mdbc . *
			}
			test = {
				$databases = . $args[0]
				# at least local, test
				if ($databases.Count -lt 2) { throw }
				if ($databases -notcontains 'local') { throw }
			}
		}
		@{
			code = {
				# Connect the database 'test' and get collections
				Import-Module Mdbc
				Connect-Mdbc . test *
			}
			test = {
				$collections = @(. $args[0])
				if (!$collections -or $collections[0].GetType().Name -ne 'String') { throw }
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

### AClient
$AClient = @{
	parameters = @{
		Client = $ClientParameter
	}
}

### ADatabase
$ADatabase = @{
	parameters = @{
		Database = $DatabaseParameter
	}
}

### ACollection
$ACollection = @{
	parameters = @{
		Collection = $CollectionParameter
	}
}

### New-MdbcData
@{
	command = 'New-MdbcData'
	synopsis = 'Creates data documents.'
	description = @'
This command is used to create Mdbc.Dictionary documents.
Input objects come from the pipeline or as the parameter.

Created documents are used by other module commands. Note that Add-MdbcData and
Export-MdbcData also have parameters Id, NewId, Convert, Property for making
documents from input objects, so that in some cases intermediate use of
New-MdbcData is not needed.

Result documents are returned as Mdbc.Dictionary objects. Mdbc.Dictionary wraps
BsonDocument and implements IDictionary. It works as a hashtable where keys are
case sensitive strings and values are convenient .NET types.

Useful members:

	$dictionary.Count
	$dictionary.Contains('key')
	$dictionary.Add('key', ..)
	$dictionary.Remove('key')
	$dictionary.Clear()

Setting values:

	$dictionary['key'] = ..
	$dictionary.key = ..

Getting values:

	.. = $dictionary['key']
	.. = $dictionary.key

NOTE: In order to create an empty document with specified _id=X or a new filter
expression for queries _id=X, use the following effective syntax:

	[Mdbc.Dictionary] X

NOTE: On getting values, `$dictionary.key` fails if the key is missing in the
strict mode. Use Contains() in order to check for missing keys. Or get values
using `$dictionary['key']`, it returns nulls for missing keys.
'@
	parameters = @{
		InputObject = @'
Specifies the object to be converted to Mdbc.Dictionary. Suitable objects are
dictionaries, PowerShell custom objects, and complex .NET types, normally not
collections.

If the input object is omitted or null then an empty document is created.
'@
		Id = $IdParameter
		NewId = $NewIdParameter
		Convert = $ConvertParameter
		Property = $PropertyParameter
	}
	inputs = $DocumentInputs
	outputs = @(
		@{
			type = '[Mdbc.Dictionary]'
			description = 'PowerShell friendly BsonDocument wrapper.'
		}
	)
	examples = @(
		@{
			code = {
				# How to create empty documents
				New-MdbcData
				New-Object Mdbc.Dictionary
				[Mdbc.Dictionary]::new() # PowerShell v5

				# How to create documents with specified _id=42
				New-MdbcData -Id 42
				[Mdbc.Dictionary] 42
				New-Object Mdbc.Dictionary 42
				[Mdbc.Dictionary]::new(42) # PowerShell v5
			}
			test = {
				. $args[0]
			}
		}
		@{
			code = {
				# Connect collection
				Import-Module Mdbc
				Connect-Mdbc . test test -NewCollection

				# Create a new document, set some data
				$data = New-MdbcData -Id 12345
				$data.Text = 'Hello world'
				$data.Date = Get-Date

				# Add the document to the database
				$data | Add-MdbcData

				# Query the document from the database
				$result = Get-MdbcData @{_id = 12345}
				$result
			}
			test = {
				. $args[0]
				if ($result.Text -ne 'Hello world') { throw }
			}
		}
		@{
			code = {
				# Connect collection
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

### Add-MdbcData
Merge-Helps $ACollection @{
	command = 'Add-MdbcData'
	synopsis = 'Adds new documents to the database collection.'
	description = @'
This command adds strictly new documents to the database collection.
If an input document has the field _id which already exists then the command writes an error.
'@
	parameters = @{
		InputObject = 'Document or a similar object, see INPUTS.'
		Id = $IdParameter
		NewId = $NewIdParameter
		Convert = $ConvertParameter
		Property = $PropertyParameter
	}
	inputs = $DocumentInputs
	links = @(
		@{ text = 'New-MdbcData' }
		@{ text = 'Select-Object' }
	)
}

### Get-MdbcData
Merge-Helps $ACollection @{
	command = 'Get-MdbcData'
	synopsis = @'
Gets data from database collections.
'@
	description = @'
This cmdlet queries the specified or default collection.
'@
	parameters = @{
		Filter = $FilterParameter
		As = $AsParameter
		Count = @'
Tells to return the number of documents matching the Filter.
Note that the optional First and Skip are taken into account.
For example `-Count -First 1` may be used as effective "exists".
'@
		Distinct = @'
Specifies the field name and tells to return its distinct values from documents
matching the Filter.
'@
		Remove = @'
Tells to remove and get the first document specified by Filter and Sort.
'@
		Set = @'
Specifies the document which replaces the first document specified by Filter and Sort.
The returned document depends on New and Project.
'@
		Update = $UpdateParameter, @'
This parameter tells to update the first document specified by Filter and Sort.
The returned document depends on New and Project.
'@
		New = @'
Tells to return new documents on Replace and Update.
By default old documents are returned if they exist.
'@
		Add = @'
Tells to add new documents on Replace and Update if old documents do not exist.
'@
		Project = @'
Specifies the projection, i.e. fields to be retrieved.
The field _id is always included unless it is explicitly excluded.

The argument is either JSON or similar dictionary.
'@
		Sort = $SortParameter
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
	}
	outputs = @(
		@{
			type = '[Int64]'
			description = 'Number of documents, if Count is requested.'
		}
		@{
			type = '[object]'
			description = 'Field values, if Distinct is specified.'
		}
		@{
			type = '[Mdbc.Dictionary] or other types depending on As.'
			description = 'Documents, see New-MdbcData about Mdbc.Dictionary.'
		}
	)
	links = @(
		@{ text = 'Connect-Mdbc' }
	)
}

### Remove-MdbcData
Merge-Helps $ACollection @{
	command = 'Remove-MdbcData'
	synopsis = 'Removes documents from collections.'
	description = @'
This cmdlet removes the specified documents from the specified or default collection.
'@, $AboutResultAndErrors
	parameters = @{
		Filter = $FilterParameter, $FilterParameterMandatory
		Many = @'
Tells to remove all matching documents.
By default the first matching document is removed.
'@
		Result = $ResultParameter
	}
	outputs = @{
		type = '[MongoDB.Driver.DeleteResult]'
		description = 'Returned if the Result is specified. Useful members: DeletedCount.'
	}
	links = @(
		@{ text = 'Connect-Mdbc' }
	)
}

### Set-MdbcData
Merge-Helps $ACollection @{
	command = 'Set-MdbcData'
	synopsis = 'Replaces documents in collections.'
	description = @'
Replaces the old document matching Filter with the new document specified by Set.
'@, $AboutResultAndErrors
	parameters = @{
		Filter = $FilterParameter, $FilterParameterMandatory
		Set = @'
Specifies the new document which replaces the old matching Filter.
'@
		Add = @'
Tells to add the new document if the old does not exist.
'@
		Options = 'Extra options, see MongoDB.Driver.UpdateOptions'
		Result = $ResultParameter
	}
	outputs = @{
		type = '[MongoDB.Driver.ReplaceOneResult]'
		description = 'Returned if Result is specified. Useful members: MatchedCount, ModifiedCount, UpsertedId.'
	}
	links = @(
		@{ text = 'Connect-Mdbc' }
		@{ text = 'Update-MdbcData' }
	)
}

### Update-MdbcData
Merge-Helps $ACollection @{
	command = 'Update-MdbcData'
	synopsis = 'Updates documents in collections.'
	description = @'
Applies the specified Update to documents matching the specified Filter.
'@, $AboutResultAndErrors
	parameters = @{
		Filter = $FilterParameter, $FilterParameterMandatory
		Update = @{
			required = $true
			description = $UpdateParameter, @'
The parameter is mandatory and does not accept nulls.
'@
		}
		Add = @'
Tells to add a document based on the filter and update if nothing was updated.
'@
		Many = @'
Tells to update all matching documents.
By default the first matching document is updated.
'@
		Options = 'Extra options, see MongoDB.Driver.UpdateOptions'
		Result = $ResultParameter
	}
	outputs = @{
		type = '[MongoDB.Driver.UpdateResult]'
		description = 'Returned if Result is specified. Useful members: MatchedCount, ModifiedCount, UpsertedId.'
	}
	links = @(
		@{ text = 'Connect-Mdbc' }
		@{ text = 'Update-MdbcData' }
	)
}

### Add-MdbcCollection
Merge-Helps $ADatabase @{
	command = 'Add-MdbcCollection'
	synopsis = 'Creates a new collection in the database.'
	description = @'
This cmdlet is needed for creation of collections with extra options, like
capped collections. Ordinary collections do not have to be added explicitly.
'@
	parameters = @{
		Name = 'Specifies the name of a new collection.'
		Options = 'Extra options, see MongoDB.Driver.CreateCollectionOptions'
	}
}

### Invoke-MdbcCommand
Merge-Helps $ADatabase @{
	command = 'Invoke-MdbcCommand'
	synopsis = 'Invokes database commands.'
	description = @'
This cmdlet is useful in order to invoke commands not covered by the module.
See MongoDB for available commands and syntax.
'@
	parameters = @{
		Command = @{
			required = $true
			description = @'
Specifies the command to be invoked.
The argument is JSON, ordered dictionary, Mdbc.Dictionary, one item hashtable.

JSON:

	Invoke-MdbcCommand '{create: "test", capped: true, size: 10485760}'

Ordered dictionary:

	Invoke-MdbcCommand ([ordered]@{create='test'; capped=$true; size=10mb })

Mdbc.Dictionary, ordered by definition:

	$c = New-MdbcData
	$c.create = 'test'
	$c.capped = $true
	$c.size = 10mb
	Invoke-MdbcCommand $c
'@
		}
		As = $AsParameter
	}
	outputs = @(
		@{
			type = '[Mdbc.Dictionary]'
			description = 'The response document wrapped by Mdbc.Dictionary.'
		}
		@{
			type = '[object]'
			description = 'Other object type depending on As.'
		}
	)
	links = @(
		@{ text = 'MongoDB'; URI = 'http://www.mongodb.org' }
	)
	examples = @(
		@{
			code = {
				# Get the server status, one item hashtable is fine

				Connect-Mdbc . test
				Invoke-MdbcCommand @{serverStatus = 1}
			}
			test = {
				$response = . $args[0]
				if ($response.host -ne $env:COMPUTERNAME) {throw}
			}
		}
		@{
			code = {
				# Connect the database `test`, get statistics for the collection
				# `test.test`. Mind [ordered], otherwise the command may fail:
				# "`scale` is unknown command".

				Connect-Mdbc . test
				Invoke-MdbcCommand ([ordered]@{collStats = "test"; scale = 1mb})
			}
			test = {
				# just run, used to fail without [ordered]
				. $args[0]
			}
		}
		@{
			code = {
				# Connect the database `test` and invoke the command with
				# the database `admin` specified explicitly (because the
				# current is `test` and the command is admin-only)

				Connect-Mdbc . test
				Invoke-MdbcCommand @{getLog = 'global'} -Database (Get-MdbcDatabase admin)
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

				# add 10 documents
				foreach($_ in 1..10) {Add-MdbcData @{_id = $_}}

				# get 5 documents
				Get-MdbcData
			}
			test = {
				$r = . $args[0]
				if ($r.Count -ne 5) {throw}
			}
		}
	)
}

### Invoke-MdbcAggregate
Merge-Helps $ACollection @{
	command = 'Invoke-MdbcAggregate'
	synopsis = 'Invokes aggregate operations.'
	description = @'
The cmdlet invokes the specified aggregation pipeline for the specified or default collection.
'@
	parameters = @{
		Pipeline = @{
			required = $true
			description = @'
One or more aggregation pipeline operations represented by JSON or similar dictionaries.
'@
		}
		Options = 'Extra options, see MongoDB.Driver.AggregateOptions'
		As = $AsParameter
	}
	outputs = @(
		@{
			type = '[Mdbc.Dictionary]'
			description = 'Result documents wrapped by Mdbc.Dictionary.'
		}
		@{
			type = '[object]'
			description = 'Other object types depending on As.'
		}
	)
	examples = @(
		@{
			# _131016_142302
			code = {
				# Data: current process names and memory working sets
				# Group by names, count, sum memory, get top 3 memory

				Connect-Mdbc . test test -NewCollection
				Get-Process | Add-MdbcData -Property Name, WorkingSet

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
			description = 'The default output type.'
		}
		@{
			type = '[object]'
			description = 'Custom type specified by the parameter As.'
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
	)
}

### Get-MdbcDatabase
Merge-Helps $AClient @{
	command = 'Get-MdbcDatabase'
	synopsis = 'Gets databases.'
	description = @'
This cmdlet gets the database instance specified by its name, existing or not.
This instance may be used as the parameter Database of relevant cmdlets.
Missing databases are created automatically as soon as needed.
'@
	parameters = @{
		Name = @'
Specifies the database name. If it is omitted then all databases are returned.
'@
		Settings = @'
Extra settings, see MongoDB.Driver.MongoDatabaseSettings
'@
	}

	outputs = @(
		@{
			type = '[MongoDB.Driver.IMongoDatabase]'
			description = 'Database instance.'
		}
	)

	links = @(
		@{ text = 'Connect-Mdbc' }
	)
}

### Remove-MdbcDatabase
Merge-Helps $AClient @{
	command = 'Remove-MdbcDatabase'
	synopsis = 'Removes a database.'
	description = @'
This cmdlet removes the specified database from the client, either default (the
variable $Client) or specified by the parameter Client.
'@
	parameters = @{
		Name = @'
Specifies the database name.
'@
	}

	links = @(
		@{ text = 'Connect-Mdbc' }
	)
}

### Get-MdbcCollection
Merge-Helps $ADatabase @{
	command = 'Get-MdbcCollection'
	synopsis = 'Gets collections.'
	description = @'
This cmdlet gets the collection instance specified by its name, existing or not.
This instance may be used as the parameter Collection of relevant cmdlets.
Missing collections are created automatically as soon as needed.
'@
	parameters = @{
		Name = @'
Specifies the collection name. If it is omitted then all collections are returned.
'@
		Settings = @'
Extra settings, see MongoDB.Driver.MongoCollectionSettings
'@
		NewCollection = @'
Tells to remove the existing collection.
'@
	}

	outputs = @(
		@{
			type = '[MongoDB.Driver.IMongoCollection[BsonDocument]]'
			description = 'Collection instance.'
		}
	)

	links = @(
		@{ text = 'Connect-Mdbc' }
	)
}

### Remove-MdbcCollection
Merge-Helps $ADatabase @{
	command = 'Remove-MdbcCollection'
	synopsis = 'Removes collections.'
	description = @'
This cmdlet removes the specified collection from the database, either default
(the variable $Database) or specified by the parameter Database.
'@
	parameters = @{
		Name = @'
Specifies the collection name.
'@
	}

	links = @(
		@{ text = 'Connect-Mdbc' }
	)
}

### Rename-MdbcCollection
Merge-Helps $ADatabase @{
	command = 'Rename-MdbcCollection'
	synopsis = 'Renames collections.'
	description = @'
This cmdlet renames the specified collection in the database, either default
(the variable $Database) or specified by the parameter Database.
'@
	parameters = @{
		Name = @'
Specifies the old collection name.
'@
		NewName = @'
Specifies the new collection name.
'@
		Force = @'
Tells to allow renaming if the target collection exists.
'@
	}

	links = @(
		@{ text = 'Connect-Mdbc' }
	)
}
