# Mdbc Release Notes

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
