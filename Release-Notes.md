Mdbc Release Notes
==================

## v3.0.2

C# driver 1.8

`New-MdbcData` - new parameter `SetOnInsert`.

## v3.0.1

C# driver 1.7.1

## v3.0.0

This version adopts major changes in C# driver 1.7.0. The driver is compatible
with existing code. In contrast, Mdbc introduces new and breaking changes now.

The switch `Safe` and the parameter `SafeMode` in writing commands are replaced
with the parameter `WriteConcern` (`Acknowledged` by default). Some cmdlets
that used to fail silently may write PowerShell errors.

The switch `Result` used to enable safe writes implicitly. Now it is not
related to write concern, it just tells to output a result object.

`Connect-Mdbc` drops the trick with `/?`. It was introduced mostly for shorter
connection strings like `/?safe=true`. Now they are not so useful.

For other details see the driver release notes and new documentation.

## v2.1.3

C# driver 1.6.1

`Get-MongoFile.ps1`: By default the search is for a regex pattern, not name.

## v2.1.2

C# driver 1.6, MongoDB 2.2

## v2.1.1

C# driver 1.5

`New-MdbcQuery` does not support the parameter `Nor`.

## v2.1.0

New cmdlet `Invoke-MdbcCommand` for invoking any MongoDB commands including not
covered by Mdbc or C# driver helpers. Mdbc becomes an interactive MongoDB shell
on PowerShell steroids. NOTE: The parameters are not perhaps stabilized, they
may depend on the feedback and suggestions.

Interactive profile *Mdbc.ps1*

- New global function `Get-MdbcHelp` gets help for MongoDB commands.
- New aliases `imc ~ Invoke-MdbcCommand, gmh ~ Get-MdbcHelp`.

## v2.0.0

### New concept of the default server, database, and collection

In many cases the same collection variable is used in commands repeatedly. In
order to avoid this redundancy this version introduces semi-automatic variables
`$Server`, `$Database`, and `$Collection` and changes the role of `Collection`
and `Database` parameters.

This change is breaking but easy to adopt. In scripts dealing with a single
collection the collection argument should be simply removed, the default
`$Collection` is used automatically. Alternatively, any collection can be
specified explicitly with the named parameter `Collection`.

Cmdlet `Connect-Mdbc`

- Renamed parameters `Database -> DatabaseName, Collection -> CollectionName`.
- Instead of returning a server, database, or collection object the cmdlet
  creates their variables in the current scope. By default they are
  `$Server, $Database, $Collection`.
- New parameters `ServerVariable, DatabaseVariable, CollectionVariable` can be
  used when several servers, databases, or collections are used in the same
  scope.

Cmdlets `*-MdbcData`

- The parameter `Collection` changed from positional (0) to named. It should be
  specified explicitly or not used at all. In the latter case the current
  variable `$Collection` is used.

Cmdlet `Add-MdbcCollection`

- The parameter `Database` changed from positional (0) to named. It should be
  specified explicitly or not used at all. In the latter case the current
  variable `$Database` is used.

### Changed safe mode output

Cmdlets `Add-MdbcData`, `Update-MdbcData`, and `Remove-MdbcData` do not write
safe mode results to output unless the new switch `Result` is used. In other
words, without `Result` they do not output anything regardless of the safe
mode.

If a safe mode result indicates an error then these cmdlets write an error. The
result object is attached to the error record. As usual, to fail or not to fail
depends on the current error action settings.

### Other changes

Cmdlet `New-MdbcData`

- Renamed parameters `DocumentId -> Id`, `NewDocumentId -> NewId`. The old
  names came from the C# driver where they were recently declared obsolete.

Cmdlet `Invoke-MdbcMapReduce`

- Renamed parameter `Result -> ResultVariable` for consistency. The old name
  `Result` still works as partial but it is recommended to use the new name.

## v1.5.0

New cmdlet `Invoke-MdbcMapReduce`. The parameters are not yet stabilized and
may change. **NOTE:** the `SortBy` requires an index though this is not
documented well (or it might be a bug).

Removed obsolete parameter aliases: `Limit` and `Select` of `Get-MdbcData` (use
`First` and `Property`) and `Select` of `New-MdbcData` (use `Property`).

Custom objects with the property `_id` can be used where a query is expected.
For example, objects from `Get-MdbcData -AsCustomObject` can be passed in
`Remove-MdbcData`, `Update-MdbcData`, and `Get-MdbcData` as queries.

`New-MdbcQuery -And|Or|Nor` - in addition to query objects arguments can be any
expressions convertible to queries (e.g. `@{Length = @{'$gt' = 1gb}}, @{..}`).

*Mdbc.ps1*

- The parameter `DatabaseName` accepts wildcards. If it is not resolved to an
  existing database name then the script prints all database names and exits.
- New operator helpers `$name = '$name'` for query and update operators may
  reduce typing and typos and make expressions to look more like JSON.

## v1.4.0

**Obsolete parameters**: The following parameters were renamed or removed in
order to follow PS guidelines; renamed still work but they will be removed in
vNext:

- `Update-MdbcData` - removed obsolete `Updates`, use `Update`.
- `Get-MdbcData` - renamed `Limit -> First`, `Select -> Property`;
- `New-MdbcData` - renamed `Select -> Property`.

Cmdlet `Get-MdbcData`

- New switch `AsCustomObject` tells to get documents represented by PS objects.
  They are more convenient in some use cases, especially interactive.
- New parameter `Last`. There is no analogue in the driver but in PowerShell it
  seems to be useful, especially in interactive sessions.

Removed the module script *Mdbc.psm1* with its functions `Convert-MdbcData`
(redundant, `Get-MdbcData` can now do this much more effectively) and
`Convert-MdbcJson` (not really useful in PowerShell).

Demo helper *Mdbc.ps1*: renamed aliases for conformance with PS guidelines.

## v1.3.0

Cmdlet `New-MdbcQuery`

- **Breaking change**. Revised parameters `And`, `Nor`, and `Or`. `And` cannot
  be omitted now. `Nor` and `Or` are not switches but, just as `And`, arrays of
  query expressions. This design is simpler and reduces chances of misuse.

Cmdlet `Update-MdbcData`

- **Obsolete parameter name**. The parameter `Updates` was renamed to `Update`.
  The old name still works as an alias but it will be removed in vNext.

Cmdlet `Get-MdbcData`

- New parameter `As` for getting strongly typed data (existing or added
  on-the-fly ad-hoc types, see *Test-Get-As.ps1*).
- New parameters `Remove`, `Update`, `New`, `Add`. They provide `FindAndRemove`
  and `FindAndModify` capabilities.
- New parameters `Distinct` and `SortBy`. The latter is used for standard
  queries and new `Update` and `Remove` modes.
- Removed redundant switch `Size`. The switch `Count` does exactly the same job
  when used together with `Limit` and `Skip`.
- Introduced parameter sets which prevent abuse of parameters. CAUTION: This
  change is potentially breaking, existing calls with meaningless parameter
  combinations will fail.

New helper script *Mdbc.ps1* adds helpers for interactive use. Use it only as
the example and base for your own interactive helpers. This script reflects
personal preferences, its features may not be suitable for all scenarios and
they may change at any time.

Added tests covering new features. Adapted scripts and tests to changes.

## v1.2.0

New cmdlet `Add-MdbcCollection`, mostly for creation of capped collections.

*Update-MongoFiles.ps1* - amended removal of unknown and orphan data.

## v1.1.0

C# driver 1.4.2 (official).

Avoided use of deprecated API.

"." as the connection string uses the driver default instead of duplicating.

Breaking change (easy to fix): removed aliases `query` and `update`. Replace
them with `New-MdbcQuery` and `New-MdbcUpdate` or use your own aliases. The
reasons: a) aliases are mostly for interactive use, up to a user; b) `query`
conflicts with `query.exe` (the alias wins but...); c) these two particular
aliases used to cause subtle PowerShell issues on module updates.

## v1.0.9

C# driver 1.4.2.33691

## v1.0.8

C# driver v1.4.1 patched for [CSHARP-447](https://jira.mongodb.org/browse/CSHARP-447).

Adapted for [CSHARP-446](https://jira.mongodb.org/browse/CSHARP-446).

Amended tests.

## v1.0.6, v1.0.7

Fixed weird silent PS errors on exporting module aliases.

## v1.0.5

C# driver v1.4.0.

Amended conversion of `null` and `BsonNull`.

`Update-MongoFiles.ps1` - updated for the latest version of Split-Pipeline.

## v1.0.4

Bug: `Update-MongoFiles.ps1 -Split` does not remove missing file records. Fixed.

## v1.0.3

New switch Split in the script Update-MongoFiles.ps1 tells to perform parallel
data processing and improve performance for large directories or entire drives.
It requires the PowerShell module SplitPipeline (it is not needed if Split is
not used). SplitPipeline may be useful for other database related tasks, too,
because processing of large data sets is typical.

## v1.0.2

C# driver v1.3.1.

## v1.0.1

C# driver v1.3.

Minor changes in tests and project infrastructure.
