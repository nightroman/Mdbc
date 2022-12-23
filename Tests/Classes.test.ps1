<#
.Synopsis
	Tests of saving and reading using classes, serialized and plain.
#>

# Tip: Import module in one script, dot-source classes from another.
# Otherwise PowerShell may fail on Bson* serialization attributes.
Import-Module Mdbc
. ./Classes.lib.ps1

# Test saving and reading serialized types [Person] and [Address].
task Person_Add_Update_Set {
	Connect-Mdbc -NewCollection

	# add a person
	$data = [Person] @{Pin = 1; Name = 'John'}
	$data | Add-MdbcData

	# test raw: .Pin ~ ._id, null .Address is not added
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "Name" : "John" }'

	# update: $set address and some extra
	$address = [Address] @{Address = 'Bar Street'}
	Update-MdbcData @{_id = 1} @{'$set' = @{Address = $address; p1 = 2}}

	# test raw: .PostCode ~ .c (null is added!), .Address ~ .a
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "Name" : "John", "Address" : { "c" : null, "a" : "Bar Street" }, "p1" : 2 }'

	# test typed: .Address is set, .p1 is in .Extra
	$data = Get-MdbcData -As ([Person])
	$r = $data | ConvertTo-Json -Compress
	equals $r '{"Pin":1,"Name":"John","Address":{"PostCode":null,"Address":"Bar Street"},"Extra":{"p1":2}}'

	# change data and replace the whole document
	$data.Name = 'Mary'
	$data.Address.PostCode = 'aa1'
	$data.Extra.p1 = 3
	$data | Set-MdbcData

	# test raw
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "Name" : "Mary", "Address" : { "c" : "aa1", "a" : "Bar Street" }, "p1" : 3 }'

	# remove
	$r = $data | Remove-MdbcData -Result
	equals $r.DeletedCount 1L
}

# Similar to the above with different commands and parameters.
task Person_SetAdd_GetSet {
	Connect-Mdbc -NewCollection

	# add person using Set -Add
	$data = [Person] @{Pin = 1; Name = 'John'; Extra = @{p1 = 1}}
	$data | Set-MdbcData -Add

	# change and replace the whole document by Get -Set and get old, i.e. added above
	$data.Address = [Address] @{Address = 'Bar Street'}
	$old = Get-MdbcData @{_id = 1} -Set $data -As ([Person])
	equals ($old | ConvertTo-Json -Compress) '{"Pin":1,"Name":"John","Address":null,"Extra":{"p1":1}}'

	# raw result
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "Name" : "John", "Address" : { "c" : null, "a" : "Bar Street" }, "p1" : 1 }'
}

# Save a typed object with an array of mixed typed data.
task PolymorphicSave {
	# item 1
	$t1 = [PolyType1] @{b1 = 1; p1 = 1}

	# item2
	$t2 = [PolyType2] @{b1 = 2; p2 = 2}

	# data with mixed items
	$data = [PolyData] @{name = 1; data = $t1, $t2}

	# save data
	Connect-Mdbc -NewCollection
	$data | Add-MdbcData

	# test raw
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "data" : [{ "_t" : "T1", "b1" : 1, "p1" : 1 }, { "_t" : "T2", "b1" : 2, "p2" : 2 }] }'

	# test typed
	$r = Get-MdbcData -As ([PolyData])
	equals $r.data[0].GetType() ([PolyType1])
	equals $r.data[1].GetType() ([PolyType2])
	equals ($r | ConvertTo-Json -Compress) '{"name":1,"data":[{"p1":1,"b1":1},{"p2":2,"b1":2}]}'
}

# Read a typed object with an array of mixed typed data.
task PolymorphicRead {
	Connect-Mdbc -NewCollection

	# create raw data using json from the above test
	'{ "_id" : 1, "data" : [{ "_t" : "T1", "b1" : 1, "p1" : 1 }, { "_t" : "T2", "b1" : 2, "p2" : 2 }] }' |
	ConvertFrom-Json | Add-MdbcData

	# read data -As PolyData -> .data is re-hydrated with PolyType1 and PolyType2 objects
	$r = Get-MdbcData -As ([PolyData])
	equals $r.data[0].GetType() ([PolyType1])
	equals $r.data[1].GetType() ([PolyType2])
	equals ($r | ConvertTo-Json -Compress) '{"name":1,"data":[{"p1":1,"b1":1},{"p2":2,"b1":2}]}'
}

# Test saving and reading polymorphic types as top level documents.
task PolymorphicTopLevel {
	Connect-Mdbc -NewCollection

	# MyType1
	$d1 = [MyType1] @{id = 1; p1 = 1}

	# MyType2
	$d2 = [MyType2] @{id = 2; p2 = 2}

	# add mixed documents
	$d1, $d2 | Add-MdbcData

	# get typed -As MyTypeBase
	$r1, $r2 = Get-MdbcData -As MyTypeBase
	equals $r1.GetType() ([MyType1])
	equals $r2.GetType() ([MyType2])

	# test raw
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "_t" : "MyType1", "p1" : 1 } { "_id" : 2, "_t" : "MyType2", "p2" : 2 }'
}

# Test work with simple classes and compare some alternatives.
task AsObject_vs_AsPlainObject {
	Connect-Mdbc -NewCollection
	@{_id = 1; foo = 'bar'; arr = @(1, 2); doc = @{p1 = 1}} | Add-MdbcData

	# -As Object -> ExpandoObject (not much different from dictionary in PowerShell)
	$r = Get-MdbcData -As ([object])
	$r | Out-String
	equals $r.GetType() ([System.Dynamic.ExpandoObject])
	equals $r._id 1
	equals $r.foo bar
	equals $r.arr.GetType() ([System.Collections.Generic.List[object]])
	equals $r.doc.GetType() ([System.Dynamic.ExpandoObject])

	# -As PlainObject
	$r = Get-MdbcData -As ([PlainObject])
	$r | Out-String
	equals $r.GetType() ([PlainObject])
	equals $r._id 1
	equals $r.foo bar
	equals $r.arr.GetType() ([Mdbc.Collection])
	equals $r.doc.GetType() ([Mdbc.Dictionary])

	# -As PlainObject2
	$r = Get-MdbcData -As ([PlainObject2])
	$r | Out-String
	equals $r.GetType() ([PlainObject2])
	equals $r._id 1
	equals $r.foo bar
	equals $r.arr.GetType() ([object[]])
	equals $r.doc.GetType() ([hashtable])

	#_191112_180148 Why Array -> Mdbc.Collection, Document -> Mdbc.Dictionary?
	# Let's use some bson types without direct mapping to .net, e.g. Binary:
	# -As Object fails, -As PlainObject works and preserves data.
	Update-MdbcData @{_id = 1} @{'$set' = @{'doc.p1' = [byte[]](1, 2)}}

	# -As Object -> ERROR
	$r = try { Get-MdbcData -As ([object]) } catch { $_ }
	equals "$r" "ObjectSerializer does not support BSON type 'Binary'."

	# -As PlainObject -> OK
	$r = Get-MdbcData -As ([PlainObject])
	equals $r.doc.p1.ToString() Binary:0x0102

	#! save PlainObject using Set-MdbcData (replace)
	$r.foo = 'bar2'
	$r | Set-MdbcData
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "foo" : "bar2", "arr" : [1, 2], "doc" : { "p1" : new BinData(0, "AQI=") } }'
}

# The above test shows that Mdbc.Collection/Dictionary accept and preserve some
# special BSON types in array and document fields. What about scalar fields?
# Alas, if .foo is declared as [object] then it cannot accept special types.
# Lesson: some class members may require appropriate types.
# Ultimately, use [MongoDB.Bson.BsonValue] for unknown.
task WhatAboutFoo {
	Connect-Mdbc -NewCollection
	@{_id = 1; foo = [byte[]](1, 2)} | Add-MdbcData

	# cannot get data as too simple PlainObject
	$r = try { Get-MdbcData -As ([PlainObject]) } catch { $_ }
	equals "$r" "An error occurred while deserializing the foo property of class PlainObject: ObjectSerializer does not support BSON type 'Binary'."

	# .foo should be declared as [byte[]] or [MongoDB.Bson.BsonBinaryData]
	$r = Get-MdbcData -As ([FooByteArray])
	equals $r.foo.GetType() ([byte[]])

	# or [MongoDB.Bson.BsonValue], it accepts any type, [MongoDB.Bson.BsonBinaryData] in here
	$r = Get-MdbcData -As ([FooBsonValue])
	equals $r.foo.GetType() ([MongoDB.Bson.BsonBinaryData])
}

# Use -Init if other parameters of Register-MdbcClassMap is not enough.
task RegisterUsingInitScript {
	class TBase {$id}
	class TChild : TBase {$p1}

	Register-MdbcClassMap TBase -Init {
		# normally call this first
		$_.AutoMap()
		# this cannot be done by parameters
		$_.AddKnownType([TChild])
	}
}

##############################################################################
### More technical, less how-to cases

# Cover issues in serialized classes with container types.
# - Untyped containers re-hydrate as lists and dynamics.
# - Mdbc containers serialize as Mdbc types.

# _191115_060729 Untyped containers used to read as Mdbc.X and save with _t and _v.
# That is why in serial types we let the driver read containers as list and dynamic.
# Mdbc containers in serial types must be specified explicitly, unlike in simple types.

task SerialWithContainers {
	Connect-Mdbc -NewCollection
	@{_id = 1; arr = @(1, 2); doc = @{p1 = 1}} | Add-MdbcData

	# -As SerialWithContainers1
	$r = Get-MdbcData -As ([SerialWithContainers1])
	equals $r.arr.GetType() ([System.Collections.Generic.List[object]])
	equals $r.doc.GetType() ([System.Dynamic.ExpandoObject])
	equals $r.doc.p1 1

	# change and set
	$r.doc.p1 = 2
	$r | Set-MdbcData
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "arr" : [1, 2], "doc" : { "p1" : 2 } }'

	# -As SerialWithContainers2
	$r = Get-MdbcData -As ([SerialWithContainers2])
	equals $r.arr.GetType() ([Mdbc.Collection])
	equals $r.doc.GetType() ([Mdbc.Dictionary])
	equals $r.doc.p1 2

	# change and set
	$r.doc.p1 = 3
	$r | Set-MdbcData
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "arr" : [1, 2], "doc" : { "p1" : 3 } }'
}

# It is fine to register the same type twice in Mdbc. Just ensure that it is
# the same line of code or at least the same map definition. Mdbc cannot check
# the same definition, it just writes a verbose message, not warning, it's fine.

task RegisteredByMdbc {
	class RegisteredByMdbc {$_id}
	$IsClassMapRegistered = [MongoDB.Bson.Serialization.BsonClassMap]::IsClassMapRegistered([RegisteredByMdbc])

	if (!$IsClassMapRegistered) {
		($r = Register-MdbcClassMap RegisteredByMdbc -Verbose 4>&1)
		equals $r $null
	}

	# repeat, check verbose message
	($r = Register-MdbcClassMap RegisteredByMdbc -Verbose 4>&1)
	assert ("$r" -like 'Type *.RegisteredByMdbc was registered by Mdbc, doing nothing.')
}

# It is not allowed to register a type already registered by driver if the call
# tweaks the map by parameters other than -Type and -Force.

task RegisteredByDriver {
	# register by the driver, not Mdbc (pretend it is done in some assembly)
	class RegisteredByDriver {$_id}
	$null = [MongoDB.Bson.Serialization.BsonClassMap]::LookupClassMap([RegisteredByDriver])

	# use some settings, e.g. -Discriminator -> both calls should fail, i.e. not registered by Mdbc
	$text = 'Class map is registered by driver. If this is expected invoke with just -Type and -Force.'

	Register-MdbcClassMap RegisteredByDriver -Discriminator Z -Verbose -ErrorAction Continue -ErrorVariable err1
	equals "$err1" $text

	Register-MdbcClassMap RegisteredByDriver -Discriminator Z -Verbose -ErrorAction Continue -ErrorVariable err2
	equals "$err2" $text
}

# It is allowed to register a type already registered by driver if the call
# uses parameters -Type and -Force.

task RegisteredByDriverForce {
	class RegisteredByDriver {$_id}
	$IsClassMapRegistered = [MongoDB.Bson.Serialization.BsonClassMap]::IsClassMapRegistered([RegisteredByDriver])

	if (!$IsClassMapRegistered) {
		# register by the driver, not Mdbc (pretend it is done in some assembly)
		$null = [MongoDB.Bson.Serialization.BsonClassMap]::LookupClassMap([RegisteredByDriver])

		# use -Force, check verbose message
		($r = Register-MdbcClassMap RegisteredByDriver -Force -Verbose 4>&1)
		assert ("$r" -like 'Type *.RegisteredByDriver was registered by driver, registering by Mdbc.')
	}

	# repeat, check different verbose message
	($r = Register-MdbcClassMap RegisteredByDriver -Force -Verbose 4>&1)
	assert ("$r" -like 'Type *.RegisteredByDriver was registered by Mdbc, doing nothing.')
}

# Test parameters of Register-MdbcClassMap.
task RegisterParameters {
	class RegisterParameters {
		$name
		[System.Collections.Generic.Dictionary[string,object]]$extra
	}

	$param = @{
		IdProperty = 'name'
		Discriminator = 'z'
		DiscriminatorIsRequired = $true
		IgnoreExtraElements = $true
		ExtraElementsProperty = 'extra'
		Init = {
			$_.AutoMap()
			# ...
		}
	}

	Register-MdbcClassMap RegisterParameters @param

	$r = [MongoDB.Bson.Serialization.BsonClassMap]::LookupClassMap([RegisterParameters])
	equals $r.IdMemberMap.MemberName name
	equals $r.Discriminator z
	equals $r.DiscriminatorIsRequired $true
	equals $r.IgnoreExtraElements $true
	equals $r.ExtraElementsMemberMap.MemberName extra
}

# Default class map seems to ignore `get` only properties.
# `MapProperty` tells to save a property anyway.
# https://github.com/nightroman/Mdbc/issues/74
task MapProperty {
	Register-MdbcClassMap -Type ([System.Management.Automation.PSDriveInfo]) -Init {
		$_.AutoMap()
		$null = $_.MapProperty('Name')
	}

	Connect-Mdbc -NewCollection

	Get-PSDrive C | Add-MdbcData

	$r = Get-MdbcData
	equals $r.Name C
}
