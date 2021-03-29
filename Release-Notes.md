# Mdbc Release Notes
[C# driver releases]: https://github.com/mongodb/mongo-csharp-driver/releases

## v6.5.9

C# driver 2.12.1

## v6.5.8

C# driver 2.11.5

`Add-MdbcData` supports `IEnumerable` collections of documents as the explicitly specified parameter `InputObject`.

## v6.5.7

C# driver 2.11.2

`Export-MdbcData` - new `-FileFormat` values `JsonCanonicalExtended` and `JsonRelaxedExtended`.

## v6.5.6

C# driver 2.10.4

## v6.5.5

C# driver 2.10.3

## v6.5.4

C# driver 2.10.2

`Mdbc.Collection` - replace troublemaker `int IList.Add()` with PS friendly `void Add()`.

Get rid of unnecessary use of PSObject in some parameters.

## v6.5.3

C# driver 2.10.1

## v6.5.2

unlisted

## v6.5.1

Add `Mdbc.Dictionary` methods `FromJson` and `EnsureId` to avoid unnatural use
of driver methods and simplify known use cases.

## v6.5.0

**Export-MdbcData**

Supports so called "Strict" JSON. It is less friendly and may not preserve all
data types. But it is suitable for reading by other applications, for example
by PowerShell `ConvertFrom-Json`.

`FileFormat` parameter supports two new values: `JsonShell` and `JsonStrict`.
When the default `Auto` is used and the file extension is ".JSON" (all caps)
then the new `JsonStrict` is assumed. When the old `Json` is used then output
depends on global settings, the same behaviour as before, default is "Shell".

This change is potentially breaking if you used all caps ".JSON" extensions.
Either change the extensions or use `-FileFormat JsonShell` in the commands.

## v6.4.1

**Deprecated constructor `Mdbc.Dictionary(object)`**

Phase 3, retired. The following constructs now fail:

```powershell
[Mdbc.Dictionary]X
[Mdbc.Dictionary]::new(X)
New-Object Mdbc.Dictionary X
```

where `X` is not `IDictionary` or `BsonDocument`.
Replace them with `New-MdbcData [-Id]`.

**Module BsonFile**

Take a look at the related work, [BsonFile module](https://github.com/nightroman/BsonFile).

## v6.4.0

C# driver 2.10.0

**`Watch-MdbcChange`**

New cmdlet. It gets the cursor for watching changes in the specified
collection, database, or client. NOTE: For replicas and shards only.

**`Set-MdbcData`**

Changed the parameter `Options` type from `UpdateOptions` (deprecated by the
driver) to `ReplaceOptions` (added in 2.10.0).

**Deprecated constructor `Mdbc.Dictionary(object)`**

Phase 2. By default, the following constructs now fail:

```powershell
[Mdbc.Dictionary]X
[Mdbc.Dictionary]::new(X)
New-Object Mdbc.Dictionary X
```

where `X` is not `Mdbc.Dictionary`, `IDictionary`, or `BsonDocument`.
Replace them with `New-MdbcData [-Id]`.

If you set `$env:MdbcDictionaryLegacy = 1` then the deprecated code still
works. This temporary fallback will be removed in the next release.

## v6.3.1

**Fixes**

- Work around the regression [#33](https://github.com/nightroman/Mdbc/issues/33).
- PSGallery package help was missing.

**Deprecated constructor `Mdbc.Dictionary(object)`**

Phase 1, just the announcement. Review your scripts, consider removing constructs:

```powershell
[Mdbc.Dictionary]X
[Mdbc.Dictionary]::new(X)
New-Object Mdbc.Dictionary X
```

where `X` is not `Mdbc.Dictionary`, `IDictionary`, or `BsonDocument`.

By the old convention, this constructor creates documents with `_id = X` or
converts objects. This is cryptic, ambiguous, and PowerShell may convert X to
unexpected types. Use `New-MdbcData [-Id]` instead.

If you set `$env:MdbcDictionaryLegacy = 0` and run your code then deprecated
constructs fail with errors "Used deprecated Mdbc.Dictionary(object)".

## v6.3.0

**Transactions and Sessions**

*Work in progress, API may change in v6.x, feedback is welcome.*

New cmdlet `Use-MdbcTransaction` starts a transaction session and invokes the
specified script. The script calls data cmdlets and either succeeds or fails.
The cmdlet commits or aborts the transaction accordingly.

Data cmdlets have the new parameter `Session`. If it is omitted then the cmdlet
is invoked in the current default session, either its own or the transaction
session created by `Use-MdbcTransaction`.

Examples from help:

- [add several documents using a transaction](https://github.com/nightroman/Mdbc/blob/6a05d3d1f1780ab1b80153adf2c9275c6087b420/Module/en-US/Mdbc.dll-Help.ps1#L1221-L1225)
- [move a document using a transaction](https://github.com/nightroman/Mdbc/blob/6a05d3d1f1780ab1b80153adf2c9275c6087b420/Module/en-US/Mdbc.dll-Help.ps1#L1230-L1237)

**Set-MdbcData, Remove-MdbcData**

The cmdlets support pipeline input. Documents are found by input document
`_id`'s. Parameters `Filter`, `Set`, `Many` are not used with pipeline.

## v6.2.0

`Invoke-MdbcAggregate`

- New parameter `Group` specifies the low ceremony aggregate pipeline of just
  $group. It is particularly useful for $min, $max, $sum, etc. of all values.
  For example:

```powershell
# max of x (... and other x or y statistics)
Invoke-MdbcAggregate -Group '{max: {$max: "$x"} ... }'
```

It is arguably cleaner and more effective than the usual trick:

```powershell
# max of x
Get-MdbcData -First 1 -Sort '{x: -1}' -Project '{x: 1, _id: 0}'
```

`Register-MdbcClassMap`

- New switch `DiscriminatorIsRequired`, it is useful for base classes of mixed
  top level documents.
- Removed `KnownTypes`, it is not useful because Mdbc requires all serialized
  types registered explicitly, i.e. "known". In special (unknown) cases, use
  `-Init` with `$_.AddKnownType()`.

## v6.1.0

New features and changes in serialization, some potentially incompatible.

**Getting data**

If a simple PowerShell class `class MyType { $arr; $doc }` is used for `-As`
and array/document members declared as `[object]` (ditto omitted type) then
they are re-hydrated as `Mdbc.Collection` and `Mdbc.Dictionary` instead of
driver chosen list and dynamic (Mdbc containers preserve all bson types).

New and old container types are semantically similar.
Old code without assumptions about exact types should work fine.

Serialized types (see further) still re-hydrate containers by driver rules.

In `Get-MdbcData -As MyType -Project *`, the special value `*` tells to infer
projected fields from `MyType`. This makes composing queries with typed output
much easier.

Parameters `-As` accept type names in addition to types and special aliases.
For interactive use, `MyType` is better than `([MyType])`. For scripts, the
exact type might be preferable perhaps.

**Setting data**

EXPERIMENTAL: Types registered by `Register-MdbcClassMap` are serialized, not
converted. Use `-Property` (use `*` for all) in order to convert by properties.

`Mdbc.Dictionary` implements `IDictionary<string, object>` in addition to
`IDictionary` and can be used in serialized types for `BsonExtraElements`.

See [Classes.lib.ps1] for examples of classes with `Bson*` attributes and
[Classes.test.ps1] for saving and reading typed data.

[Classes.lib.ps1]: https://github.com/nightroman/Mdbc/blob/master/Tests/Classes.lib.ps1
[Classes.test.ps1]: https://github.com/nightroman/Mdbc/blob/master/Tests/Classes.test.ps1

## v6.0.3

C# driver 2.9.3

Amend work on #32.

## v6.0.2

Fix update expression conversion, #32

## v6.0.1

**Mdbc.Dictionary and Mdbc.Collection**

- Add/Set `byte[]` should map to `BsonBinaryData`, not `BsonArray`.
- Override `Equals` and `GetHashCode` similar to wrapped types.
- Map `decimal` <-> `BsonDecimal128`.

**/Scripts**

- `Mdbc.ArgumentCompleters.ps1` -- add name completers for `Get-MdbcDatabase`,
  `Remove-MdbcDatabase`, `Get-MdbcCollection`, `Remove-MdbcCollection`,
  `Rename-MdbcCollection`.
- Rework `Update-MongoFiles.ps1` -- save less data, use shorter lower case
  field names, add some comments.
- Remove `Get-MongoFile.ps1` as not quite useful or significant.

## v6.0.0

Many changes including breaking in order to adopt v2 driver API, improve
clarity and consistency, and retire some arguably excessive features.

We move from driver query, update, etc. builders API to JSON and dictionary
expressions, standard in MongoDB and literally translated to PowerShell.

**v2 driver methods and v6 module commands**

See [README](https://github.com/nightroman/Mdbc/blob/master/README.md)

**Mdbc.Dictionary**

Changed binary data view. If the sub-type is `Uuid*` then `[guid]` is used.
Otherwise `MongoDB.Bson.BsonBinaryData` is preserved. It is easier to use
as `_id` and comparison operators work properly in PowerShell.

**Removed cmdlets:**

- `New-MdbcQuery`, `New-MdbcUpdate`. Filter and update expressions are used instead, either JSON or similar dictionaries.
- `Open-MdbcFile`, `Save-MdbcFile`. File collections are no longer supported. Use `Export-MdbcData`, `Import-MdbcData`.
- `Invoke-MdbcMapReduce`

**Added cmdlets:**

- `Set-MdbcData`
- `Get-MdbcDatabase`
- `Get-MdbcCollection`
- `Remove-MdbcDatabase`
- `Remove-MdbcCollection`
- `Rename-MdbcCollection`

**Connect-Mdbc**

- replaced `-ServerVariable` with `-ClientVariable` and default `$Server` with `$Client`
- removed `Timeout`

**Add-MdbcData**

- removed `-Update` (use `Get-MdbcData -Set -Add`)

**Get-MdbcData**

- added `-Set`
- removed `-Modes`, `-ResultVariable`
- replaced `-Query` with `-Filter`, `-SortBy` with `-Sort`, `-Property` with `-Project`

**Remove-MdbcData**

- replaced `-One` with `-Many`

**Update-MdbcData**

- added `-Options`
- renamed `-All` to `-Many`
- replaced `-Query` with `-Filter`

**Invoke-MdbcCommand**

- added `-As`
- removed `-Value` (`-Command` is enough)

**Invoke-MdbcAggregate**

- added `-As`, `-Options`
- removed `-BatchSize`, `-MaxTime`, `-AllowDiskUse` (use `-Options`)

**Add-MdbcCollection**

- added `-Options`
- removed `-MaxSize` and `-MaxDocuments` (use `Options`)

***

[Other versions](https://github.com/nightroman/Mdbc/tree/master/About)
