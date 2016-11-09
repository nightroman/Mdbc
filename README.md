
MongoDB Cmdlets for PowerShell
==============================

Mdbc is the Windows PowerShell v2.0+ module based on the official
[MongoDB C# driver](https://github.com/mongodb/mongo-csharp-driver).
Mdbc makes MongoDB scripting in PowerShell easier and provides some extra
features like bson/json file collections which do not even require MongoDB.

## Quick Start

**Step 1:** Get and install.

Mdbc is distributed as the PowerShell Gallery module [Mdbc](https://www.powershellgallery.com/packages/Mdbc).
In PowerShell 5.0 or with PowerShellGet you can install it by this command:

    Install-Module Mdbc

Mdbc is also distributed as the NuGet package [Mdbc](https://www.nuget.org/packages/Mdbc).
Download it to the current location as the directory *"Mdbc"* by this PowerShell command:

    Invoke-Expression "& {$((New-Object Net.WebClient).DownloadString('https://github.com/nightroman/PowerShelf/raw/master/Save-NuGetTool.ps1'))} Mdbc"

Alternatively, download it by NuGet tools or [directly](http://nuget.org/api/v2/package/Mdbc).
In the latter case save it as *".zip"* and unzip. Use the package subdirectory *"tools/Mdbc"*.

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

    # Connect the new collection test.test
    Connect-Mdbc . test test -NewCollection

    # Add some test data
    @{_id=1; value=42}, @{_id=2; value=3.14} | Add-MdbcData

    # Get all data as custom objects and show them in a table
    Get-MdbcData -As PS | Format-Table -AutoSize | Out-String

    # Query a document by _id using a query expression
    $data = Get-MdbcData (New-MdbcQuery _id -EQ 1)
    $data

    # Update the document, set the 'value' to 100
    $data._id | Update-MdbcData (New-MdbcUpdate -Set @{value = 100})

    # Query the document using a simple _id query
    Get-MdbcData $data._id

    # Remove the document
    $data._id | Remove-MdbcData

    # Count remaining documents, 1 is expected
    Get-MdbcData -Count

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
