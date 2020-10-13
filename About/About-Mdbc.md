# About Mdbc

***
## C# driver

- [GitHub](https://github.com/mongodb/mongo-csharp-driver)
- [Releases](https://github.com/mongodb/mongo-csharp-driver/releases)
- [Documentation](http://mongodb.github.io/mongo-csharp-driver/)

***
# Notes

***
## 2020-10-13 driver v2.11.2, Guid, JSON

<https://github.com/mongodb/mongo-csharp-driver/releases/tag/v2.11.0>

- [Guid serialization](http://mongodb.github.io/mongo-csharp-driver/2.11/reference/bson/guidserialization/)
    - [GuidRepresentationMode](http://mongodb.github.io/mongo-csharp-driver/2.11/reference/bson/guidserialization/guidrepresentationmode/guidrepresentationmode/)
    -- we do not use it, i.e. it is the default old `[MongoDB.Bson.BsonDefaults]::GuidRepresentationMode` = V2
    - Maybe in v3 they switch to standard Guid as default
    -- we will drop our workaround with env variables
- [BSON/JSON](http://mongodb.github.io/mongo-csharp-driver/2.11/reference/bson/bson/)
    - [JsonOutputMode Enumeration](http://mongodb.github.io/mongo-csharp-driver/2.11/apidocs/html/T_MongoDB_Bson_IO_JsonOutputMode.htm)
    -- new options and obsolete Strict
    - Maybe in v3 they drop JSON Strict
    -- we will remove it and use canonical instead.

***
## 2020-10-13 MongoDB v4.4.1, v4.4 drops tools

<https://docs.mongodb.com/manual/release-notes/4.4/>

#### EOL Notice

<https://docs.mongodb.com/manual/tutorial/install-mongodb-on-windows/>

MongoDB 4.4 Community Edition supports the following 64-bit versions of Windows on x86_64 architecture:

- Windows Server 2019
- Windows 10 / Windows Server 2016

#### Tools excluded, e.g. `mongodump`, `mongorestore`.

Get rid of tools in tests.
