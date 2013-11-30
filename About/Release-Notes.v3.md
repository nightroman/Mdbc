Mdbc Release Notes
==================

## v3.2.0

The parameter `Not` of `New-MdbcQuery` works with any other query types.

`Mdbc.Document` and `Mdbc.Collection` unwrap `BsonObjectId` to `ObjectId`.

Fixed bugs with input nulls in `New-MdbcData -Value` and `New-MdbcQuery`.

## v3.1.0

New cmdlets `Export-MdbcData` and `Import-MdbcData` for storing and restoring
objects without need of database connections or even MongoDB installed.

Potentially breaking change in `New-MdbcData`. `InputObject` is only for new
documents and the new named parameter `Value` is for `BsonValue`. This should
not break too much because the cmdlet is mostly for creation of documents and
direct use of `BsonValue` is rare. The change resolves ambiguities in some
cases and improves compatibility with `Add-MdbcData`, `Export-MdbcData`.

Added control of cyclic references on data conversion to documents and avoided
potential stack overflows. An exception 'Cyclic reference.' is thrown instead.

Properties and dictionary entries with null values are preserved on conversion
to BsonDocument's. Properties which throws are also preserved with null values.

Cmdlets `New-MdbcData`, `Add-MdbcData`, and `Export-MdbcData` have four common
parameters which make it easier to create documents from pipeline input:

- `Id` - specifies a document's `_id`
- `NewId` - tells to generate the `_id`
- `Convert` - converts unknown data on errors
- `Property` - property expressions similar to `Select-Object`

Thus, in some cases intermediate use of `New-MdbcData` is not needed now.

Note that omitted `Id` does not take an existing  property `Id` for `_id`
automatically anymore. This effect was unwanted and rather confusing.

`New-MdbcData`, `Add-MdbcData`, and `Export-MdbcData`: driver exceptions on
BSON conversion and MondoException are caught for every input object and an
error is written instead. Differences:

- Errors include failed objects as TargetObject (for recovery, logging)
- Cmdlets may use the ErrorAction parameter or variable (better control)
- By default ErrorAction is Continue, i.e. such errors do not terminate

Removed not documented use of script blocks as input to `Add-MdbcData`.

Converted tests to special test scripts invoked by `Invoke-Build`.

## v3.0.4

C# driver 1.8.2

## v3.0.3

C# driver 1.8.1

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
