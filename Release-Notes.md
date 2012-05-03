Mdbc Release Notes
==================

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
