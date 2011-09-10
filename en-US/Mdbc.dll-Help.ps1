
<#
.Synopsis
	Help script for [Helps](https://github.com/nightroman/Helps)
#>

# Import the module to make commands available for the builder.
Import-Module Mdbc

# Shared collection description.
$script:collection = @'
Collection object. It is obtained by Connect-Mdbc directly (using the
Collection parameter) or from returned database or server objects.
'@

# Shared [Mdbc.Dictionary] type info.
$script:typeMdbcDictionary = @{
	type = '[Mdbc.Dictionary]'
	description = 'Objects created by New-MdbcData or obtained by Get-MdbcData.'
}

# Shared SafeModeResult type info.
$script:typeSafeModeResult = @{
	type = '[MongoDB.Driver.SafeModeResult]'
	description = 'The result is returned if safe mode if enabled.'
}

### Connect-Mdbc
@{
	command = 'Connect-Mdbc'
	synopsis = 'Connects and gets a server, database, or collection object.'
	description = @'
	> Connect-Mdbc -ConnectionString
	Gets the connected server object. Use GetDatabase(), ...

	> Connect-Mdbc -ConnectionString -Database
	Gets the connected database object. Use GetCollection(), ...

	> Connect-Mdbc -ConnectionString -Database -Collection
	Gets the connected collection object. Use Add-MdbcData, Get-MdbcData, Remove-MdbcData, Update-MdbcData.
'@

	parameters = @{
		ConnectionString = @'
	Connection string (see the C# driver manual for details):
	mongodb://[username:password@]hostname[:port][/[database][?options]]
	Example: "." (same as "mongodb://localhost").
	Example: "mongodb://localhost:27017".
'@
		Database = 'Database name.'
		Collection = 'Collection name.'
		NewCollection = 'Tells to drop the collection if it exists and create a new one.'
	}
	inputs = @()
	outputs = @(
		@{ type = '[MongoDB.Driver.MongoServer]' }
		@{ type = '[MongoDB.Driver.MongoDatabase]' }
		@{ type = '[MongoDB.Driver.MongoCollection]' }
	)
	examples = @(
		@{
			code = {
				# Connect and get the collection (drop existing, create new)
				Import-Module Mdbc
				$collection = Connect-Mdbc . test test -NewCollection
			}
			test = {
				. $args[0]
				if ($collection.GetType().Name -ne 'MongoCollection`1') { throw }
			}
		}
		@{
			code = {
				# Connect and get the database
				Import-Module Mdbc
				$database = Connect-Mdbc . test

				# Then get collections
				$collection1 = $database.GetCollection('test')
				$collection2 = $database.GetCollection('process')
			}
			test = {
				. $args[0]
				if ($database.GetType().Name -ne 'MongoDatabase') { throw }
				if ($collection1.FullName -ne 'test.test' ) { throw }
				if ($collection2.FullName -ne 'test.process' ) { throw }
			}
		}
		@{
			code = {
				# Connect and get the server
				Import-Module Mdbc
				$server = Connect-Mdbc mongodb://localhost

				# Then get the database
				$database = $server.GetDatabase('test')
			}
			test = {
				. $args[0]
				if ($server.GetType().Name -ne 'MongoServer') { throw }
				if ($database.GetType().Name -ne 'MongoDatabase') { throw }
			}
		}
	)
	links = @(
		@{ text = 'Add-MdbcData' }
		@{ text = 'Get-MdbcData' }
		@{ text = 'Remove-MdbcData' }
		@{ text = 'Update-MdbcData' }
		@{ text = 'MongoDB'; URI = 'http://www.mongodb.org/' }
		@{ text = 'C# driver'; URI = 'http://www.mongodb.org/display/DOCS/CSharp+Driver+Tutorial' }
	)
}

### New-MdbcData
@{
	command = 'New-MdbcData'
	synopsis = 'Creates data documents and some other C# driver types.'
	description = @'
This command is mostly used in order to create documents to be stored in the database.
Without input objects it creates PowerShell friendly wrappers of C# driver documents.
'@
	parameters = @{
		DocumentId = @'
Sets the document _id to the specified value.
It makes sense when a document is being created.

With pipeline input it can be a script block that returns an ID value.
If this ID is an existing property/key value then the Select list should be specified.
Otherwise the same value is included twice as the document ID and the property/key value.
'@
		NewDocumentId = @'
Tells to generate and set a new document _id.
It makes sense when a document is being created.
'@
		InputObject = @'
.NET value to be converted to its BSON analogue.
'@
		Select = @'
Property or key names which values are to be included into new documents.
This parameter is used when input objects are converted into documents (see examples).
'@
	}
	inputs = @(
		@{
			type = '$null, [PSCustomObject], [Hashtable] (any dictionary, in fact)'
			description = @'
[Mdbc.Dictionary] document is created (BsonDocument helper).
The created document is empty if the input object is $null or empty.
Otherwise the document has the same fields and values as the input properties/keys and values.
'@
		}
		@{ type = '[System.Collections.IEnumerable]'; description = 'Mdbc array is created (BsonArray helper).' }
		@{ type = '[bool]'; description = 'is converted to BsonBoolean.' }
		@{ type = '[DateTime]'; description = 'is converted to BsonDateTime.' }
		@{ type = '[double]'; description = 'is converted to BsonDouble.' }
		@{ type = '[Guid]'; description = 'is converted to BsonBinaryData (and retrieved back as [Guid].' }
		@{ type = '[int]'; description = 'is converted to BsonInt32.' }
		@{ type = '[long]'; description = 'is converted to BsonInt64.' }
		@{ type = '[string]'; description = 'is converted to BsonString.' }
	)
	outputs = @(
		@{
			type = '[Mdbc.Dictionary]'
			description = 'PowerShell friendly wrapper of BsonDocument.'
		}
		@{
			type = '[Mdbc.Collection]'
			description = 'PowerShell friendly wrapper of BsonArray.'
		}
		@{
			type = '[MongoDB.Bson.BsonValue]'
			description = 'Other BsonValue types created from input objects.'
		}
	)
	examples = @(
		@{
			code = {
				# Connect and get the collection
				Import-Module Mdbc
				$collection = Connect-Mdbc . test test -NewCollection

				# Create a new document, set some data
				$data = New-MdbcData -DocumentId 12345
				$data.Text = 'Hello world'
				$data.Date = Get-Date

				# Add the document to the database
				$data | Add-MdbcData $collection

				# Query the document from the database
				$result = Get-MdbcData $collection (query _id 12345)
				$result
			}
			test = {
				. $args[0]
				if ($result.Text -ne 'Hello world') { throw }
			}
		}
		@{
			code = {
				# Connect and get the collection
				Import-Module Mdbc
				$collection = Connect-Mdbc . test test -NewCollection

				# Create data from input objects and add to the database
				Get-Process mongod |
				New-MdbcData -DocumentId {$_.Id} -Select Name, WorkingSet, StartTime |
				Add-MdbcData $collection

				# Query the data
				$result = Get-MdbcData $collection
				$result
			}
			test = {
				. $args[0]
				$result = @($result)
				if ($result[0].Name -ne 'mongod') { throw }
			}
		}
	)
	links = @(
		@{ text = 'Add-MdbcData' }
	)
}

### New-MdbcQuery
@{
	command = 'New-MdbcQuery'
	synopsis = 'Creates queries for Get-MdbcData, Remove-MdbcData, and Update-MdbcData.'
	sets = @{
		Where = '{ $where: "this.a > 3" }', @'
The database evaluates JavaScript expression for each object scanned. When the
result is true, the object is returned in the query results.
'@,
		@'
JavaScript executes more slowly than the native operators but is very flexible.
See the server-side processing page for more information (official site).
'@
	}
	parameters = @{
		Where = '$where argument, JavaScript Boolean expression.'
		Queries = @'
Queries for logical And, Nor, and Or operations.
By default it performs And. Use Nor and Or switches for other operations.
'@
		Nor = @'
Logical Nor query operator (MongoDB $nor).
It is not combined with other query tests.
'@
		Or = @'
Logical Or query operator (MongoDB $or).
It is not combined with other query tests.
'@
		Name = @'
Field name.
'@
		EQ = @'
Equality test. Parameter name is optional. Parameter value can be null.
It is not combined with other query tests.
'@
		IEQ = @'
Ignore case equality test for strings (no MongoDB analogue).
It is not combined with other query tests.
'@
		INE = @'
Ignore case inequality test for strings (no MongoDB analogue).
It is not combined with other query tests.
'@
		Match = @'
Regular expression test (MongoDB /.../imxs values, $regex and $options operators).
It is not combined with other query tests.
'@,
		@'
Value is an array of one or two items.
A single item is either a regular expression string pattern or a regular expression object.
Two items are both strings: a regular expression pattern and options, combination of 'i', 'm', 'x', 's' characters.
'@
		Not = @'
Tells to negate the whole query expression (MongoDB $not).
'@
		GE = @'
Greater or equal test (MongoDB $gte).
'@
		GT = @'
Greater than test (MongoDB $gt).
'@
		LE = @'
Less or equal test (MongoDB $lte).
'@
		LT = @'
Less than test (MongoDB $lt).
'@
		NE = @'
Inequality test (MongoDB $ne).
'@
		Exists = @'
Checks if the field exists (MongoDB $exists).
'@
		Matches = @'
Checks if an element in an array matches the specified query expression (MongoDB $elemMatch).
'@,
		@'
It is needed only when more than one field must be matched in the array element.
'@
		Mod = @'
Modulo test (MongoDB $mod).
The argument is an array or two items: the modulus and the result value to be tested.
'@
		Size = @'
Array element item count test (MongoDB $size).
'@
		Type = @'
Element type test (MongoDB $type).
'@
		All = @'
Checks if all the field values are in the specified set (MongoDB $all).
'@
		In = @'
Checks if the field has any value is in the specified set (MongoDB $in).
'@
		NotIn = @'
Checks if the field does not have any value in the specified set (MongoDB $nin).
'@
	}
	inputs = @()
	outputs = @{
		type = '[MongoDB.Driver.IMongoQuery]'
		description = 'Use it for Get-MdbcData, Remove-MdbcData, Update-MdbcData.'
	}
	links = @(
		@{ text = 'Get-MdbcData' }
		@{ text = 'Remove-MdbcData' }
		@{ text = 'Update-MdbcData' }
		@{ text = 'Advanced Queries'; URI = 'http://www.mongodb.org/display/DOCS/Advanced+Queries' }
	)
}

### New-MdbcUpdate
@{
	command = 'New-MdbcUpdate'
	synopsis = 'Creates update expressions for Update-MdbcData.'
	sets = @{
		AddToSet = '{ $addToSet : { field : value } }', @'
Adds value to the array only if its not in the array already, if field is an
existing array, otherwise sets field to the array value if field is not
present. If field is present but is not an array, an error condition is raised.
'@
		AddToSetEach = '{ $addToSet : { a : { $each : [ 3 , 5 , 6 ] } } }', @'
To add many values.
'@
		Band = '{ $bit : { field : { and : 5 } } }', @'
Does a bitwise-and update of field. Can only be used with integers.
'@
		Bor = '{ $bit : { field : { or : 5 } } }', @'
Does a bitwise-or update of field. Can only be used with integers.
'@
		Increment = '{ $inc : { field : value } }', @'
Increments field by the number value if field is present in the object,
otherwise sets field to the number value.
'@
		PopFirst = '{ $pop : { field : -1  } }', @'
Removes the first element in an array.
'@
		PopLast = '{ $pop : { field : 1  } }', @'
Removes the last element in an array.
'@
		Pull = '{ $pull : { field : value } }', @'
Removes all occurrences of value from field, if field is an array. If field is
present but is not an array, an error condition is raised.
'@,
'{ $pull : { field : {<match-criteria>} } }', @'
Removes array elements meeting match criteria.
'@
		PullAll = '{ $pullAll : { field : value_array } }', @'
Removes all occurrences of each value in value_array from field, if field is an
array. If field is present but is not an array, an error condition is raised.
'@
		Push = '{ $push : { field : value } }', @'
Appends value to field, if field is an existing array, otherwise sets field to
the array [value] if field is not present. If field is present but is not an
array, an error condition is raised.
'@
		PushAll = '{ $pushAll : { field : value_array } }', @'
Appends each value in value_array to field, if field is an existing array,
otherwise sets field to the array value_array if field is not present. If field
is present but is not an array, an error condition is raised.
'@
		Rename = '{ $rename : { old_field_name : new_field_name } }', @'
Renames the field with name 'old_field_name' to 'new_field_name'. Does not
expand arrays to find a match for 'old_field_name'.
'@
		Set = '{ $set : { field : value } }', @'
Sets field to value. All data types are supported.
'@
		Unset = '{ $unset : { field : 1} }', @'
Deletes a given field.
'@
	}
	parameters = @{
		Name = 'Name of a field to be updated.'
		AddToSet = '$addToSet argument. If it is a collection then it is treated as a single value to add.'
		AddToSetEach = '$addToSet $each argument, a collection of values, each value is added.'
		Band = '$bit "and" argument, [int] or [long].'
		Bor = '$bit "or" argument, [int] or [long].'
		Increment = '$inc argument, [int], [long], or [double].'
		PopFirst = 'Tells to remove the first element in an array.'
		PopLast = 'Tells to remove the last element in an array.'
		Pull = '$pull argument, a value or a query. If it is a collection then it is treated as a single value to pull.'
		PullAll = '$pullAll argument, a collection of values, each value is pulled.'
		Push = '$push argument. If it is a collection then it is treated as a single value to push.'
		PushAll = '$pushAll argument, a collection of values, each value is pushed.'
		Rename = '$rename argument, the new field name.'
		Set = '$set argument. All standard types are supported.'
		Unset = 'Tells to remove the field.'
	}
	inputs = @()
	outputs = @{ type = 'Update expression'; description = 'Use these expression objects for Update-MdbcData.' }
	links = @{ text = 'Update-MdbcData' }
}

### Add-MdbcData
@{
	command = 'Add-MdbcData'
	synopsis = 'Adds new documents to the database collection or updates existing.'
	parameters = @{
		Collection = $collection
		InputObject = 'Document (Mdbc.Dictionary, BsonDocument, or PSCustomObject).'
		Safe = 'Tells to enable safe mode.'
		SafeMode = 'Advanced safe mode options.'
		Update = 'Tells to update existing documents with the same _id or add new documents otherwise.'
	}
	inputs = @(
		$script:typeMdbcDictionary
		@{
			type = '[PSCustomObject]'
			description = 'Custom objects often created by Select-Object but not only.'
		}
		@{
			type = '[MongoDB.Bson.BsonDocument]'
			description = 'This type is supported but normally it should not be used directly.'
		}
	)
	outputs = $script:typeSafeModeResult
	links = @(
		@{ text = 'New-MdbcData' }
		@{ text = 'Select-Object' }
	)
}

### Get-MdbcData
@{
	command = 'Get-MdbcData'
	synopsis = @'
Gets documents from the database collection.
'@
	description = @'
Gets documents from the database collection.
'@
	parameters = @{
		Collection = $collection
		Query = @'
Query expression obtained by New-MdbcQuery.
'@
		Count = @'
Tells to return the number of documents that match the query.
'@
		Cursor = @'
Tells to return a cursor to be used for further operations.
See the C# driver manual.
'@
		Select = @'
Subset of fields to be retrieved.
Note: document _id is always included.
'@
		Modes = @'
Additional query flags.
See the C# driver manual.
'@
		Limit = @'
Maximum number of documents to be returned.
'@
		Skip = @'
Number of documents to skip.
'@
		Size = @'
Number of documents taking into account the Limit and Skip values.
'@
	}
	links = @(
		@{ text = 'Connect-Mdbc' }
		@{ text = 'New-MdbcQuery' }
	)
}

### Remove-MdbcData
@{
	command = 'Remove-MdbcData'
	synopsis = 'Removes specified documents from the collection.'
	description = ''
	parameters = @{
		Collection = $script:collection
		Modes = 'Additional removal flags. See the C# driver manual.'
		Query = 'Specifies the documents to be removed.'
		Safe = 'Tells to enable safe mode.'
		SafeMode = 'Advanced safe mode options.'
	}
	inputs = @()
	outputs = $script:typeSafeModeResult
	links = @(
		@{ text = 'Connect-Mdbc' }
		@{ text = 'New-MdbcQuery' }
	)
}

### Update-MdbcData
@{
	command = 'Update-MdbcData'
	synopsis = 'Updates specified documents.'
	description = ''
	parameters = @{
		Collection = $script:collection
		InputObject = ''
		Modes = 'Additional update flags. See the C# driver manual.'
		Safe = 'Tells to enable safe mode.'
		SafeMode = 'Advanced safe mode options.'
		Updates = 'Update expressions.'
	}
	inputs = @( ### ???
		@{
			type = ''
			description = ''
		}
	)
	outputs = $script:typeSafeModeResult
	links = @(
		@{ text = 'Connect-Mdbc' }
		@{ text = 'New-MdbcUpdate' }
	)
}
