<#
.Synopsis
	PowerShell classes for tests of saving and reading with -As.

.Description
	Tip: Define types with Bson* attributes in a separate script and dot-source
	it to the consumer script after `Import-Module Mdbc`. If you define classes
	right in the consumer script PowerShell may fail to parse Bson* attributes.

	For Bson* serialization attributes and type mapping, see:
	https://mongodb.github.io/mongo-csharp-driver/2.9/reference/bson/mapping/

	See Classes.test.ps1 for tests with this script classes.
#>

# To avoid long type names
using namespace MongoDB.Bson.Serialization.Attributes
using namespace System.Collections.Generic

##############################################################################
### Serialized types
# Serialized types are registered by Register-MdbcClassMap.
# Use Bson* attributes in order to customise serialization.

# This class ignores fields other than .c and .a
# and maps them as .c ~ .PostCode, .a ~ .Address

[BsonIgnoreExtraElements()]
class Address {
	[BsonElement('c')]
	[string] $PostCode

	[BsonElement('a')]
	[string] $Address
}

# This class maps .Pin to ._id and puts all extra fields to .Extra of the
# convenient type Mdbc.Dictionary. BsonExtraElements works both ways: on
# reading extras are added to $Extra, on saving $Extra's entries become
# fields of the saved document.

class Person {
	[BsonId()]
	[int] $Pin

	[string] $Name

	[BsonIgnoreIfDefault()]
	[Address] $Address

	[BsonExtraElements()]
	[Mdbc.Dictionary] $Extra
}

# Register types as serialized, either using the types or full names.
# Other parameters are not needed, attributes drive the serialization.

Register-MdbcClassMap ([Address])
Register-MdbcClassMap Person

##############################################################################
### Polymorphic sub-documents
# - PolyBase: base type for PolyType1 and PolyType2
# - PolyData: document using mixed PolyType1 and PolyType2

class PolyBase {
	$b1
}

class PolyType1 : PolyBase {
	$p1
}

class PolyType2 : PolyBase {
	$p2
}

class PolyData {
	$name
	[List[PolyBase]]$data
}

# NOTE: In this scenario we tweak serialization by Register-MdbcClassMap, not
# by Bson* attributes. As a result, classes may be easily defined right where
# they are used, there is no need in a separate dot-sourced file with classes.

Register-MdbcClassMap PolyBase
Register-MdbcClassMap PolyType1 -Discriminator T1
Register-MdbcClassMap PolyType2 -Discriminator T2
Register-MdbcClassMap PolyData -IdProperty name

##############################################################################
### Polymorphic top documents
# - MyTypeBase
#   This is the base class for all top level documents. It contains .id (driver
#   maps to _id automatically). Top level documents are defined by child
#   classes. Important: set DiscriminatorIsRequired
# - MyType1, MyType2
#   Top level documents are classes derived from MyTypeBase.

class MyTypeBase {
	$id
}

class MyType1 : MyTypeBase {
	$p1
}

class MyType2 : MyTypeBase {
	$p2
}

Register-MdbcClassMap MyTypeBase -Init {
	$_.AutoMap()
	$_.SetDiscriminatorIsRequired($true)
}
Register-MdbcClassMap MyType1
Register-MdbcClassMap MyType2

##############################################################################
### Simple types
# Simple types are not registered by Register-MdbcClassMap and should not have
# Bson* attributes. On saving they are converted to documents by properties, on
# reading with -As fields are literally mapped to properties.

# Trivial class: no types, no attributes, even one-liner.
# (Array -> Mdbc.Collection, Document -> Mdbc.Dictionary)
class PlainObject {$_id; $foo; $arr; $doc}

# Ditto with some types, to change default Array/Document types:
class PlainObject2 {
	$_id
	$foo
	[object[]]$arr
	[hashtable]$doc
}

# Some members may have to be declared with an appropriate type:

class FooByteArray {
	$_id
	[byte[]]$foo
}

class FooBsonValue {
	$_id
	[MongoDB.Bson.BsonValue]$foo
}

##############################################################################
### More technical cases

class SerialWithContainers1 {$_id; $arr; $doc}
Register-MdbcClassMap ([SerialWithContainers1])

class SerialWithContainers2 {$_id; [Mdbc.Collection]$arr; [Mdbc.Dictionary]$doc}

# Register using Init, just for testing in here.
# In practice, this way is used for fine tuning.
# See [MongoDB.Bson.Serialization.BsonClassMap]
Register-MdbcClassMap ([SerialWithContainers2]) -Init {
	$_.AutoMap()
}
