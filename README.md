
[![PSGV](https://img.shields.io/powershellgallery/v/Mdbc)![PSGD](https://img.shields.io/powershellgallery/dt/Mdbc)](https://www.powershellgallery.com/packages/Mdbc)

# Mdbc

MongoDB Cmdlets for Windows PowerShell 5.1 and PowerShell Core

The PowerShell module based on the official [MongoDB C# driver](https://github.com/mongodb/mongo-csharp-driver)

## Quick start

**Step 1:** Get and install [Mdbc](https://www.powershellgallery.com/packages/Mdbc) from the PSGallery:

```powershell
Install-Module Mdbc
```

**Step 2:** Import the module:

```powershell
Import-Module Mdbc
```

**Step 3:** See help and available commands:

```powershell
help about_Mdbc
help Connect-Mdbc
Get-Command -Module Mdbc
```

**Step 4:** Make sure mongod is running and try some commands:

```powershell
# Load the module
Import-Module Mdbc

# Connect the new collection test.test
Connect-Mdbc . test test -NewCollection

# Add two documents
@{_id = 1; value = 42}, @{_id = 2; value = 3.14} | Add-MdbcData

# Get documents as PS objects
Get-MdbcData -As PS | Format-Table

# Get the document by _id
Get-MdbcData @{_id = 1}

# Update the document, set 'value' to 100
Update-MdbcData @{_id = 1} @{'$set' = @{value = 100}}

# Get the document again, 'value' is 100
$doc = Get-MdbcData @{_id = 1}

# Remove the document
$doc | Remove-MdbcData

# Count documents, 1
Get-MdbcData -Count
```

## Next Steps

[Mdbc.ArgumentCompleters.ps1]: https://github.com/nightroman/Mdbc/blob/main/Scripts/Mdbc.ArgumentCompleters.ps1
[Update-MongoFiles.ps1]: https://github.com/nightroman/Mdbc/blob/main/Scripts/Update-MongoFiles.ps1
[HowTo.test.ps1]: https://github.com/nightroman/Mdbc/blob/main/Tests/HowTo.test.ps1
[Classes.lib.ps1]: https://github.com/nightroman/Mdbc/blob/main/Tests/Classes.lib.ps1
[Classes.test.ps1]: https://github.com/nightroman/Mdbc/blob/main/Tests/Classes.test.ps1
[BsonFile]: https://github.com/nightroman/BsonFile

Read cmdlet help topics and take a look at examples for some basic use cases.

Use [Mdbc.ArgumentCompleters.ps1] for database and collection name completion and property completion.
You may install this script from the PSGallery as [Mdbc.ArgumentCompleters](https://www.powershellgallery.com/packages/Mdbc.ArgumentCompleters):

```powershell
Install-Script Mdbc.ArgumentCompleters
```

Use [Update-MongoFiles.ps1], either for making some test data or for tracking file changes in practice.

See also tests, for example:

- [HowTo.test.ps1] - assorted how-to samples
- [Classes.lib.ps1] - PowerShell classes for saving and reading
- [Classes.test.ps1] - tests using the above classes are how-to samples
- [BsonFile] - Mdbc based script module for BSON/JSON file collections

## Driver methods and module commands

| Driver | Module  | Output
| :----- | :-----  | :-----
| **Client** | |
| MongoClient | Connect-Mdbc | $Client $Database $Collection
| GetDatabase | Get-MdbcDatabase | database(s)
| DropDatabase | Remove-MdbcDatabase | none
| Transactions | Use-MdbcTransaction | -
| Watch | Watch-MdbcChange -Client | cursor
| **Database** | |
| RunCommand | Invoke-MdbcCommand | document
| GetCollection | Get-MdbcCollection | collection(s)
| CreateCollection | Add-MdbcCollection | none
| RenameCollection | Rename-MdbcCollection | none
| DropCollection | Remove-MdbcCollection | none
| Watch | Watch-MdbcChange -Database | cursor
| **Collection** | |
| InsertOne | Add-MdbcData | none
| InsertMany | Add-MdbcData -Many | none
| Find | Get-MdbcData | documents
| CountDocuments | Get-MdbcData -Count | count
| Distinct | Get-MdbcData -Distinct | values
| FindOneAndDelete | Get-MdbcData -Remove | old document
| FindOneAndReplace | Get-MdbcData -Set | old or new document
| FindOneAndUpdate | Get-MdbcData -Update | old or new document
| DeleteOne | Remove-MdbcData | none or info (-Result)
| DeleteMany | Remove-MdbcData -Many | none or info (-Result)
| ReplaceOne | Set-MdbcData | none or info (-Result)
| UpdateOne | Update-MdbcData | none or info (-Result)
| UpdateMany | Update-MdbcData -Many | none or info (-Result)
| Aggregate | Invoke-MdbcAggregate | documents
| Watch | Watch-MdbcChange -Collection | cursor

## See also

- [Mdbc Release Notes](https://github.com/nightroman/Mdbc/blob/main/Release-Notes.md)
- [about_Mdbc.help.txt](https://github.com/nightroman/Mdbc/blob/main/Module/en-US/about_Mdbc.help.txt)
- [Ldbc, similar project for LiteDB](https://github.com/nightroman/Ldbc)
