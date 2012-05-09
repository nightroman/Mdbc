Mdbc Release Notes
==================

## v1.3.1

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

Update-MongoFiles.ps1 - updated for the latest version of Split-Pipeline.

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
