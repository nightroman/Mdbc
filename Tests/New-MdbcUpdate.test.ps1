
. .\Zoo.ps1
Import-Module Mdbc
Set-Alias test Test-Expression

# DateTime value as PSObject for tests
$date = [PSObject][DateTime]'2011-11-11'

# Guid value as PSObject for tests
$guid = [PSObject][Guid]'12345678-1234-1234-1234-123456789012'

# BsonArray value for tests
$bsonArray = New-MdbcData -Value 1, 2, 3
Test-Type $bsonArray MongoDB.Bson.BsonArray

# MdbcArray value for tests
$mdbcArray = [Mdbc.Collection]$bsonArray
Test-Type $mdbcArray Mdbc.Collection

# we want at least some operators to be in a predicted order
task Order {
	test { New-MdbcUpdate -Unset x -Rename @{x='y'} -Set @{x=1} -SetOnInsert @{x=1} } `
	'{ "$unset" : { "x" : 1 }, "$rename" : { "x" : "y" }, "$set" : { "x" : 1 }, "$setOnInsert" : { "x" : 1 } }'
}

task Unset {
	test { New-MdbcUpdate -Unset Name } '{ "$unset" : { "Name" : 1 } }'
	test { New-MdbcUpdate -Unset a, b } '{ "$unset" : { "a" : 1, "b" : 1 } }'
}

task CurrentDate {
	test { New-MdbcUpdate -CurrentDate Name } '{ "$currentDate" : { "Name" : true } }'
	test { New-MdbcUpdate -CurrentDate a, b } '{ "$currentDate" : { "a" : true, "b" : true } }'
}

task Rename {
	test { New-MdbcUpdate -Rename @{One = 'Two'} } '{ "$rename" : { "One" : "Two" } }'
	test { New-MdbcUpdate -Rename @{a = 1; b = 2}, @{c = 3} } '{ "$rename" : { "a" : "1", "b" : "2", "c" : "3" } }'
}

task Set-SetOnInsert {
	test { New-MdbcUpdate @{Name = $null} } '{ "$set" : { "Name" : null } }'

	test { New-MdbcUpdate -Set @{Name = 'one'} } '{ "$set" : { "Name" : "one" } }'
	test { New-MdbcUpdate -SetOnInsert @{Name = 'one'} } '{ "$setOnInsert" : { "Name" : "one" } }'

	test { New-MdbcUpdate -Set @{a = 1; b = 2}, @{c = 3} } '{ "$set" : { "a" : 1, "b" : 2, "c" : 3 } }'
	test { New-MdbcUpdate -SetOnInsert @{a = 1; b = 2}, @{c = 3} } '{ "$setOnInsert" : { "a" : 1, "b" : 2, "c" : 3 } }'
}

task MinMax {
	test { New-MdbcUpdate -Min @{Name = 'one'} } '{ "$min" : { "Name" : "one" } }'
	test { New-MdbcUpdate -Max @{Name = 'one'} } '{ "$max" : { "Name" : "one" } }'

	test { New-MdbcUpdate -Min @{a = 1; b = 2}, @{c = 3} } '{ "$min" : { "a" : 1, "b" : 2, "c" : 3 } }'
	test { New-MdbcUpdate -Max @{a = 1; b = 2}, @{c = 3} } '{ "$max" : { "a" : 1, "b" : 2, "c" : 3 } }'
}

task Inc {
	test { New-MdbcUpdate -Inc @{Name = 1} } '{ "$inc" : { "Name" : 1 } }'
	test { New-MdbcUpdate -Inc @{Name = 1L} } '{ "$inc" : { "Name" : NumberLong(1) } }'
	test { New-MdbcUpdate -Inc @{Name = 1.1} } '{ "$inc" : { "Name" : 1.1 } }'
	test { New-MdbcUpdate -Inc @{a = 1; b = 2}, @{c = 3} } '{ "$inc" : { "a" : 1, "b" : 2, "c" : 3 } }'
}

task Mul {
	test { New-MdbcUpdate -Mul @{Name = 1} } '{ "$mul" : { "Name" : 1 } }'
	test { New-MdbcUpdate -Mul @{Name = 1L} } '{ "$mul" : { "Name" : NumberLong(1) } }'
	test { New-MdbcUpdate -Mul @{Name = 1.1} } '{ "$mul" : { "Name" : 1.1 } }'
	test { New-MdbcUpdate -Mul @{a = 1; b = 2}, @{c = 3} } '{ "$mul" : { "a" : 1, "b" : 2, "c" : 3 } }'
}

task Bitwise {
	test { New-MdbcUpdate -BitwiseAnd @{Name = 1} } '{ "$bit" : { "Name" : { "and" : 1 } } }'
	test { New-MdbcUpdate -BitwiseOr @{Name = 1} } '{ "$bit" : { "Name" : { "or" : 1 } } }'
	test { New-MdbcUpdate -BitwiseXor @{Name = 1} } '{ "$bit" : { "Name" : { "xor" : 1 } } }'

	test { New-MdbcUpdate -BitwiseAnd @{Name = 1L} } '{ "$bit" : { "Name" : { "and" : NumberLong(1) } } }'
	test { New-MdbcUpdate -BitwiseOr @{Name = 1L} } '{ "$bit" : { "Name" : { "or" : NumberLong(1) } } }'
	test { New-MdbcUpdate -BitwiseXor @{Name = 1L} } '{ "$bit" : { "Name" : { "xor" : NumberLong(1) } } }'

	test { New-MdbcUpdate -BitwiseAnd @{a = 1; b = 2}, @{c = 3} } '{ "$bit" : { "a" : { "and" : 1 }, "b" : { "and" : 2 }, "c" : { "and" : 3 } } }'
	test { New-MdbcUpdate -BitwiseOr @{a = 1; b = 2}, @{c = 3} } '{ "$bit" : { "a" : { "or" : 1 }, "b" : { "or" : 2 }, "c" : { "or" : 3 } } }'
	test { New-MdbcUpdate -BitwiseXor @{a = 1; b = 2}, @{c = 3} } '{ "$bit" : { "a" : { "xor" : 1 }, "b" : { "xor" : 2 }, "c" : { "xor" : 3 } } }'
}

task AddToSet {
	test { New-MdbcUpdate -AddToSet @{Name = 1} } '{ "$addToSet" : { "Name" : 1 } }'
	test { New-MdbcUpdate -AddToSetEach @{Name = 1} } '{ "$addToSet" : { "Name" : { "$each" : [1] } } }'

	test { New-MdbcUpdate -AddToSet @{Name = 1, 2} } '{ "$addToSet" : { "Name" : [1, 2] } }'
	test { New-MdbcUpdate -AddToSetEach @{Name = 1, 2} } '{ "$addToSet" : { "Name" : { "$each" : [1, 2] } } }'

	test { New-MdbcUpdate -AddToSet @{Name = $mdbcArray} } '{ "$addToSet" : { "Name" : [1, 2, 3] } }'
	test { New-MdbcUpdate -AddToSetEach @{Name = $mdbcArray} } '{ "$addToSet" : { "Name" : { "$each" : [1, 2, 3] } } }'

	test { New-MdbcUpdate -AddToSet @{Name = $bsonArray} } '{ "$addToSet" : { "Name" : [1, 2, 3] } }'
	test { New-MdbcUpdate -AddToSetEach @{Name = $bsonArray} } '{ "$addToSet" : { "Name" : { "$each" : [1, 2, 3] } } }'

	test { New-MdbcUpdate -AddToSet @{a = 1; b = 2}, @{c = 3} } '{ "$addToSet" : { "a" : 1, "b" : 2, "c" : 3 } }'
	test { New-MdbcUpdate -AddToSetEach @{a = 1; b = 2}, @{c = 3} } `
	'{ "$addToSet" : { "a" : { "$each" : [1] }, "b" : { "$each" : [2] }, "c" : { "$each" : [3] } } }'
}

task Pop {
	test { New-MdbcUpdate -PopFirst Name } '{ "$pop" : { "Name" : -1 } }'
	test { New-MdbcUpdate -PopLast Name } '{ "$pop" : { "Name" : 1 } }'

	test { New-MdbcUpdate -PopFirst a, b } '{ "$pop" : { "a" : -1, "b" : -1 } }'
	test { New-MdbcUpdate -PopLast a, b } '{ "$pop" : { "a" : 1, "b" : 1 } }'
}

task Pull {
	# Pull query
	$q = New-MdbcQuery x -GT 1
	test { New-MdbcUpdate -Pull @{a = $q} } '{ "$pull" : { "a" : { "x" : { "$gt" : 1 } } } }'
	test { New-MdbcUpdate -Pull @{a = $q; b = $q } } '{ "$pull" : { "a" : { "x" : { "$gt" : 1 } }, "b" : { "x" : { "$gt" : 1 } } } }'
	test { New-MdbcUpdate -Pull @{a = $q}, @{b = $q } } '{ "$pull" : { "a" : { "x" : { "$gt" : 1 } }, "b" : { "x" : { "$gt" : 1 } } } }'

	# Pull and PullAll

	test { New-MdbcUpdate -Pull @{Name = 1} } '{ "$pull" : { "Name" : 1 } }'
	test { New-MdbcUpdate -PullAll @{Name = 1} } '{ "$pullAll" : { "Name" : [1] } }'

	test { New-MdbcUpdate -Pull @{Name = 1, 2} } '{ "$pull" : { "Name" : [1, 2] } }'
	test { New-MdbcUpdate -PullAll @{Name = 1, 2} } '{ "$pullAll" : { "Name" : [1, 2] } }'

	test { New-MdbcUpdate -Pull @{Name = $mdbcArray} } '{ "$pull" : { "Name" : [1, 2, 3] } }'
	test { New-MdbcUpdate -PullAll @{Name = $mdbcArray} } '{ "$pullAll" : { "Name" : [1, 2, 3] } }'

	test { New-MdbcUpdate -Pull @{Name = $bsonArray} } '{ "$pull" : { "Name" : [1, 2, 3] } }'
	test { New-MdbcUpdate -PullAll @{Name = $bsonArray} } '{ "$pullAll" : { "Name" : [1, 2, 3] } }'

	test { New-MdbcUpdate -Pull @{a = 1; b = 2}, @{c = 3} } '{ "$pull" : { "a" : 1, "b" : 2, "c" : 3 } }'
	test { New-MdbcUpdate -PullAll @{a = 1; b = 2}, @{c = 3} } '{ "$pullAll" : { "a" : [1], "b" : [2], "c" : [3] } }'
}

task Push {
	test { New-MdbcUpdate -Push @{Name = 1} } '{ "$push" : { "Name" : 1 } }'
	test { New-MdbcUpdate -PushAll @{Name = 1} } '{ "$pushAll" : { "Name" : [1] } }'

	test { New-MdbcUpdate -Push @{Name = 1, 2} } '{ "$push" : { "Name" : [1, 2] } }'
	test { New-MdbcUpdate -PushAll @{Name = 1, 2} } '{ "$pushAll" : { "Name" : [1, 2] } }'

	test { New-MdbcUpdate -Push @{Name = $mdbcArray} } '{ "$push" : { "Name" : [1, 2, 3] } }'
	test { New-MdbcUpdate -PushAll @{Name = $mdbcArray} } '{ "$pushAll" : { "Name" : [1, 2, 3] } }'

	test { New-MdbcUpdate -Push @{Name = $bsonArray} } '{ "$push" : { "Name" : [1, 2, 3] } }'
	test { New-MdbcUpdate -PushAll @{Name = $bsonArray} } '{ "$pushAll" : { "Name" : [1, 2, 3] } }'

	test { New-MdbcUpdate -Push @{a = 1; b = 2}, @{c = 3} } '{ "$push" : { "a" : 1, "b" : 2, "c" : 3 } }'
	test { New-MdbcUpdate -PushAll @{a = 1; b = 2}, @{c = 3} } '{ "$pushAll" : { "a" : [1], "b" : [2], "c" : [3] } }'
}
