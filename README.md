Mdbc module - MongoDB Cmdlets for PowerShell
============================================

Mdbc is the Windows PowerShell module based on the official
[MongoDB C# driver](https://github.com/mongodb/mongo-csharp-driver).
Mdbc makes MongoDB scripting in PowerShell easier and provides some extra
features like bson file collections which do not require MongoDB installed.

## Quick Start

**Step 1:** Get and install Mdbc:

An easy way to get and install is the PowerShell tool
[PsGet](https://github.com/psget/psget):

    Import-Module PsGet
    Install-Module -NuGetPackageId Mdbc

Alternatively, to get the package without installation use
[NuGet.exe Command Line](http://nuget.codeplex.com/releases):

    NuGet install Mdbc

In the latter case copy the directory *tools\Mdbc* from the package to a
PowerShell module directory, see `$env:PSModulePath`. For example:

    C:/Users/.../Documents/WindowsPowerShell/Modules/Mdbc

**Step 2:** In a PowerShell command prompt import the module:

    Import-Module Mdbc

**Step 3:** Take a look at help:

    help about_Mdbc
    help Connect-Mdbc -full
    ...

**Step 4:** Invoke these operations line by line, reading the comments
(make sure that mongod is started, otherwise `Connect-Mdbc` fails):

    # Load the module
    Import-Module Mdbc

    # Connect the database 'test' and the new collection 'test'
    Connect-Mdbc . test test -NewCollection

    # Add some data (Id as _id, Name, and WorkingSet of current processes)
    Get-Process | Add-MdbcData -Id {$_.Id} -Property Name, WorkingSet

    # Query all data back as custom objects and print them formatted
    Get-MdbcData -As PS | Format-Table -AutoSize | Out-String

    # Get saved data of the process 'mongod' (expected at least one)
    $data = Get-MdbcData (New-MdbcQuery Name -EQ mongod)
    $data

    # Update these data (let's just set the WorkingSet to 12345)
    $data | Update-MdbcData (New-MdbcUpdate -Set @{WorkingSet = 12345})

    # Query again in order to take a look at the changed data
    Get-MdbcData (New-MdbcQuery Name -EQ mongod)

    # Remove these data
    $data | Remove-MdbcData

    # Query again, just get the count, 0 is expected
    Get-MdbcData (New-MdbcQuery Name -EQ mongod) -Count

If the code above works then the module is installed and ready to use.

Next Steps
----------

Read cmdlet help topics and take a look at their examples, they show some basic
use cases to start with.

Take a look at scripts in the directory *Scripts*, especially the interactive
profile *Mdbc.ps1*. Other scripts are rather toys but may be useful. Even more
examples can be found in the directory *Tests* of the project repository.

Mdbc cmdlets are designed for rather simple jobs. For advanced operations the
C# driver API should be used directly. Some API was specifically designed with
PowerShell in mind. See the C# driver manuals.
