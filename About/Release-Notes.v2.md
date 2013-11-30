Mdbc Release Notes
==================

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
