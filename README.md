Mdbc module - MongoDB Cmdlets for PowerShell
============================================

![Powered by MongoDB](https://github.com/downloads/nightroman/Mdbc/PoweredMongoDBblue50.png)

*Mdbc* is the *Windows PowerShell* module based on the official
[MongoDB C# driver](https://github.com/mongodb/mongo-csharp-driver).
It makes MongoDB scripting easy and represents yet another MongoDB shell.

## Quick Start

**Step 1:** Get and install *Mdbc*:

An easy way to get and install is the PowerShell module
[psget](https://github.com/psget/psget):

    Import-Module PsGet
    Install-Module -NuGetPackageId Mdbc

Alternatively, to get the package without installation use
[NuGet.exe Command Line](http://nuget.codeplex.com/releases):

    NuGet install Mdbc

Alternatively, manually download and unzip the package from
[Downloads](https://github.com/nightroman/Mdbc/downloads).

In the last two cases copy the directory *Mdbc* from the package to a
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

    # Add some data (Name and WorkingSet of currently running processes)
    Get-Process | New-MdbcData -Id {$_.Id} -Property Name, WorkingSet | Add-MdbcData

    # Query all saved data back and print them formatted
    Get-MdbcData -AsCustomObject | Format-Table -AutoSize | Out-String

    # Get saved data of the process 'mongod' (there should be at least one)
    $data = Get-MdbcData (New-MdbcQuery Name -EQ mongod)
    $data

    # Update these data (let's just set the WorkingSet to 12345)
    $data | Update-MdbcData (New-MdbcUpdate WorkingSet -Set 12345)

    # Query again in order to take a look at the changed data
    Get-MdbcData (New-MdbcQuery Name -EQ mongod)

    # Remove these data
    $data | Remove-MdbcData

    # Query again, just get the count, 0 is expected
    Get-MdbcData (New-MdbcQuery Name -EQ mongod) -Count

This is it. If the code above works then the module is installed and ready to use.

Next Steps
----------

Read cmdlet help topics and take a look at their examples, they show some basic
use cases to start with.

Take a look at the scripts in the *Scripts* directory, the interactive profile
*Mdbc.ps1* in the first place. Other scripts are rather toys but may be useful.

Even more examples can be found in the *Tests* directory. Download the sources.
These tests cover all the cmdlets and most of other helper features.

*Mdbc* cmdlets are designed for rather trivial routine operations. For advanced
operations the C# driver API should be used. This is easy but one has to know
how. The C# driver claims to be PowerShell friendly, some API was specifically
designed with PowerShell in mind. Read the C# driver manuals.
