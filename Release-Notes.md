# Mdbc Release Notes

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
