<#
.Synopsis
	Connect-Mdbc tests.
#>

. .\Zoo.ps1
Import-Module Mdbc

# Test error messages on invalid input
task BadParameters {
	Test-Error {Connect-Mdbc -DatabaseName test} 'ConnectionString parameter is null or missing.'
	Test-Error {Connect-Mdbc -CollectionName test} 'ConnectionString parameter is null or missing.'
}

# By the convention, Connect-Mdbc without parameters is works as Connect-Mdbc . test test
task Parameterless {
	Connect-Mdbc
	Test-Type $Client MongoDB.Driver.MongoClient
	Test-Type $Database MongoDB.Driver.MongoDatabaseImpl
	Test-Type $Collection MongoDB.Driver.MongoCollectionImpl
	equals $Database.DatabaseNamespace.DatabaseName test
	equals $Collection.CollectionNamespace.FullName test.test
	equals $Collection.CollectionNamespace.CollectionName test
}

# By the convention, Connect-Mdbc .. * gets database objects.
task StarDatabase {
	$r = Connect-Mdbc . *
	assert ($r -ccontains 'test')
	assert ($r -ccontains 'local')
}

# By the convention, Connect-Mdbc .. .. * gets collection objects.
task StarCollection {
	$r = Connect-Mdbc . test *
	assert ($r -ccontains 'test')
}

task ConnectBySettings {
	$settings = [MongoDB.Driver.MongoClientSettings]::new()
	Connect-Mdbc $settings test test -NewCollection
	@{_id=1; name='_221110_1734'} | Add-MdbcData
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "name" : "_221110_1734" }'
}

task ConnectByUrl {
	$url = [MongoDB.Driver.MongoUrl]::new('mongodb://localhost:27017')
	Connect-Mdbc $url test test -NewCollection
	@{_id=1; name='_221110_1734'} | Add-MdbcData
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "name" : "_221110_1734" }'
}

task ConnectBySettingsTimeout {
	$settings = [MongoDB.Driver.MongoClientSettings]::new()
	$settings.Server = [MongoDB.Driver.MongoServerAddress]::new('localhost', 9999)
	$settings.ServerSelectionTimeout = New-TimeSpan -Seconds 1
	$r = try { Connect-Mdbc $settings test test -NewCollection } catch { $_ }
	"$r"
	assert ("$r".StartsWith('A timeout occurred after 1000ms'))
}

task ConnectByBuilderTimeout {
	$url = [MongoDB.Driver.MongoUrlBuilder]::new('mongodb://localhost:9999')
	$url.ServerSelectionTimeout = New-TimeSpan -Seconds 1
	equals "$url" 'mongodb://localhost:9999/?serverSelectionTimeout=1s'
	$r = try { Connect-Mdbc $url test test -NewCollection } catch { $_ }
	"$r"
	assert ("$r".StartsWith('A timeout occurred after 1000ms'))
}
