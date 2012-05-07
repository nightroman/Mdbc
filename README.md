Mdbc module - MongoDB Cmdlets for PowerShell
============================================

![Powered by MongoDB](https://github.com/downloads/nightroman/Mdbc/PoweredMongoDBblue50.png)

*Mdbc* is the *Windows PowerShell* module built on top of the official
[MongoDB C# driver](https://github.com/mongodb/mongo-csharp-driver).
It provides a few cmdlets and PowerShell friendly features for basic
operations on MongoDB data.

The goal is not to replace the driver API with cmdlets for everything but to
make it easier to use the driver in PowerShell scripts and interactively (see
the helper script *Mdbc.ps1*).

## Quick Start

**Step 1:**
An easy way to get and update the package is
[NuGet.exe Command Line](http://nuget.codeplex.com/releases):

    NuGet install Mdbc

Alternatively, manually download and unzip the latest package from
[Downloads](https://github.com/nightroman/Mdbc/downloads).

Copy the directory *Mdbc* from the package to one of the PowerShell module
directories (see `$env:PSModulePath`). For example:

    C:/Users/.../Documents/WindowsPowerShell/Modules/Mdbc

**Step 2:** In a PowerShell command prompt import the module:

    Import-Module Mdbc

**Step 3:** Take a look at help:

    help about_Mdbc
    help Connect-Mdbc -full
    ...

**Step 4:** Invoke these operations line by line, reading the comments
(make sure that mongod is started, otherwise `Connect-Mdbc` fails):

```powershell

    # Import the module (if not yet):
    Import-Module Mdbc

    # Connect and get a new collection 'test' in the database 'test':
    $collection = Connect-Mdbc . test test -NewCollection

    # Add some data (Name and WorkingSet of currently running processes):
    Get-Process | New-MdbcData -DocumentId {$_.Id} -Select Name, WorkingSet | Add-MdbcData $collection

    # Query all saved data back and print them formatted:
    Get-MdbcData $collection | Convert-MdbcData | Format-Table -AutoSize | Out-String

    # Get saved data of the process 'mongod' (there should be at least one document):
    $data = Get-MdbcData $collection (New-MdbcQuery Name -EQ mongod)
    $data

    # Update these data (let's just set the WorkingSet to 12345):
    $data | Update-MdbcData $collection (New-MdbcUpdate WorkingSet -Set 12345)

    # Query again in order to take a look at the changed data:
    Get-MdbcData $collection (New-MdbcQuery Name -EQ mongod)

    # Remove these data:
    $data | Remove-MdbcData $collection

    # Query again, just get the count, it should be 0:
    Get-MdbcData $collection (New-MdbcQuery Name -EQ mongod) -Count
```

This is it. If the code above works then the module is installed and ready to use.

Next Steps
----------

Read cmdlet help topics and take a look at their examples, they show some basic
use cases to start with.

Take a look at the scripts in the *Scripts* directory. They are rather toys but
can be useful, too, at least for learning.

Even more examples can be found in the *Tests* directory. Download the sources.
These tests cover all the cmdlets and most of other helper features.

*Mdbc* cmdlets are designed for rather trivial routine operations. For advanced
operations the C# driver API should be used. This is easy but one has to know
how. The C# driver claims to be PowerShell friendly, some API was specifically
designed with PowerShell in mind. Read the C# driver manuals.
