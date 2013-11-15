Mdbc module - MongoDB Cmdlets for PowerShell
============================================

Mdbc is the Windows PowerShell module based on the official
[MongoDB C# driver](https://github.com/mongodb/mongo-csharp-driver).
Mdbc makes MongoDB scripting in PowerShell easier and provides some extra
features like bson file collections which do not require MongoDB installed.

## Quick Start

**Step 1:** Get and install Mdbc.
Mdbc is distributed as the NuGet package [Mdbc](https://www.nuget.org/packages/Mdbc).
Download it to the current location as the directory *"Mdbc"* by this PowerShell command:

    Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.github.com/nightroman/Mdbc/master/Download.ps1')

Alternatively, download it by NuGet tools or [directly](http://nuget.org/api/v2/package/Mdbc).
In the latter case rename the package to *".zip"* and unzip. Use the package
subdirectory *"tools/Mdbc"*.

Copy the directory *Mdbc* to a PowerShell module directory, see
`$env:PSModulePath`, normally like this:

    C:/Users/<User>/Documents/WindowsPowerShell/Modules/Mdbc

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
