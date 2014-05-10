
<#
.Synopsis
	Build script (https://github.com/nightroman/Invoke-Build)

.Description
	HOW TO USE THIS SCRIPT AND BUILD THE MODULE

	Get and copy MongoDB.Bson.dll and MongoDB.Driver.dll to Module.

	Get the utility script Invoke-Build.ps1:
	https://github.com/nightroman/Invoke-Build

	Copy it to the path. Set location to here. Build:
	PS> Invoke-Build Build

	The task Help fails if Helps.ps1 is missing.
	Ignore this error or get Helps.ps1:
	https://github.com/nightroman/Helps

	In order to deal with the latest C# driver sources set the environment
	variable MongoDBCSharpDriverRepo to its repository path. Then all tasks
	*Driver should work as well.
#>

param(
	$Configuration = 'Release'
)

$ModuleName = 'Mdbc'

# Module directory.
$ModuleRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) WindowsPowerShell\Modules\$ModuleName

# Use MSBuild.
use 4.0 MSBuild

# Get version from release notes.
function Get-Version {
	switch -Regex -File Release-Notes.md {'##\s+v(\d+\.\d+\.\d+)' {return $Matches[1]} }
}

# Generate or update meta files.
task Meta -Inputs Release-Notes.md -Outputs Module\$ModuleName.psd1, Src\AssemblyInfo.cs {
	$Version = Get-Version
	$Project = 'https://github.com/nightroman/Mdbc'
	$Summary = 'Mdbc module - MongoDB Cmdlets for PowerShell'
	$Copyright = 'Copyright (c) 2011-2014 Roman Kuzmin'

	Set-Content Module\$ModuleName.psd1 @"
@{
	Author = 'Roman Kuzmin'
	ModuleVersion = '$Version'
	Description = '$Summary'
	CompanyName = '$Project'
	Copyright = '$Copyright'

	ModuleToProcess = '$ModuleName.dll'
	RequiredAssemblies = 'MongoDB.Driver.dll', 'MongoDB.Bson.dll'

	PowerShellVersion = '2.0'
	GUID = '12c81cd8-bde3-4c91-a292-e6c4f868106a'
}
"@

	Set-Content Src\AssemblyInfo.cs @"
using System;
using System.Reflection;
using System.Runtime.InteropServices;

[assembly: AssemblyProduct("$ModuleName")]
[assembly: AssemblyVersion("$Version")]
[assembly: AssemblyTitle("$Summary")]
[assembly: AssemblyCompany("$Project")]
[assembly: AssemblyCopyright("$Copyright")]

[assembly: ComVisible(false)]
[assembly: CLSCompliant(false)]
"@
}

# Build, on post-build event copy files and make help.
task Build Meta, {
	exec { MSBuild Src\$ModuleName.csproj /t:Build /p:Configuration=$Configuration /p:TargetFrameworkVersion=v3.5}
}

# Copy files to the module, then make help.
# It is called from the post-build event.
task PostBuild {
	exec { robocopy Module $ModuleRoot /s /np /r:0 /xf *-Help.ps1 } (0..3)
	Copy-Item Src\Bin\$Configuration\$ModuleName.dll $ModuleRoot
},
(job Help -Safe)

# Remove temp and info files.
task Clean {
	Remove-Item -Force -Recurse -ErrorAction 0 `
	Module\$ModuleName.psd1, "$ModuleName.*.nupkg",
	z, Src\bin, Src\obj, Src\AssemblyInfo.cs, README.htm, Release-Notes.htm
}

# Build help by Helps (https://github.com/nightroman/Helps).
task Help -Inputs (
	Get-Item Src\Commands\*, Module\en-US\$ModuleName.dll-Help.ps1
) -Outputs (
	"$ModuleRoot\en-US\$ModuleName.dll-Help.xml"
) {
	. Helps.ps1
	Convert-Helps Module\en-US\$ModuleName.dll-Help.ps1 $Outputs
}

# Build and test help.
task TestHelpExample {
	. Helps.ps1
	Test-Helps Module\en-US\$ModuleName.dll-Help.ps1
}

# Docs by https://www.nuget.org/packages/MarkdownToHtml
task ConvertMarkdown {
	exec { MarkdownToHtml from=README.md to=README.htm }
	exec { MarkdownToHtml from=Release-Notes.md to=Release-Notes.htm }
}

# Set $script:Version.
task Version {
	($script:Version = Get-Version)
	# module version
	assert ((Get-Module $ModuleName -ListAvailable).Version -eq ([Version]$script:Version))
	# assembly version
	assert ((Get-Item $ModuleRoot\$ModuleName.dll).VersionInfo.FileVersion -eq ([Version]"$script:Version.0"))
}

# Make the package in z\tools.
task Package ConvertMarkdown, (job UpdateScript -Safe), {
	Remove-Item [z] -Force -Recurse
	$null = mkdir z\tools\$ModuleName\en-US, z\tools\$ModuleName\Scripts

	Copy-Item -Destination z\tools\$ModuleName `
	LICENSE.txt,
	README.htm,
	Release-Notes.htm,
	$ModuleRoot\$ModuleName.dll,
	$ModuleRoot\$ModuleName.psd1,
	$ModuleRoot\MongoDB.Bson.dll,
	$ModuleRoot\MongoDB.Driver.dll

	Copy-Item -Destination z\tools\$ModuleName\en-US `
	$ModuleRoot\en-US\about_$ModuleName.help.txt,
	$ModuleRoot\en-US\$ModuleName.dll-Help.xml

	Copy-Item -Destination z\tools\$ModuleName\Scripts `
	.\Scripts\Mdbc.ps1,
	.\Scripts\Get-MongoFile.ps1,
	.\Scripts\Update-MongoFiles.ps1,
	.\Scripts\TabExpansionProfile.Mdbc.ps1
}

# Make NuGet package.
task NuGet Package, Version, {
	$text = @'
Mdbc is the Windows PowerShell module based on the official MongoDB C# driver.
It makes MongoDB scripting in PowerShell easier and provides some extra
features like bson/json file collections which do not require MongoDB.
'@
	# nuspec
	Set-Content z\Package.nuspec @"
<?xml version="1.0"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
	<metadata>
		<id>$ModuleName</id>
		<version>$Version</version>
		<authors>Roman Kuzmin</authors>
		<owners>Roman Kuzmin</owners>
		<projectUrl>https://github.com/nightroman/Mdbc</projectUrl>
		<licenseUrl>http://www.apache.org/licenses/LICENSE-2.0</licenseUrl>
		<requireLicenseAcceptance>false</requireLicenseAcceptance>
		<summary>$text</summary>
		<description>$text</description>
		<tags>Mongo MongoDB PowerShell Module Database</tags>
	</metadata>
</package>
"@
	# pack
	exec { NuGet pack z\Package.nuspec -NoPackageAnalysis }
}

# Push to the repository with a version tag.
task PushRelease Version, {
	$changes = exec { git status --short }
	assert (!$changes) "Please, commit changes."

	exec { git push }
	exec { git tag -a "v$Version" -m "v$Version" }
	exec { git push origin "v$Version" }
}

# Make and push the NuGet package.
task PushNuGet NuGet, {
	exec { NuGet push "$ModuleName.$Version.nupkg" }
},
Clean

# Remove test.test* collections
task CleanTest {
	Import-Module Mdbc
	foreach($Collection in Connect-Mdbc . test *) {
		if ($Collection.Name -like 'test*') {
			$null = $Collection.Drop()
		}
	}
}

# Test synopsis of each cmdlet and warn about unexpected.
task TestHelpSynopsis {
	Import-Module Mdbc
	Get-Command *-Mdbc* -CommandType cmdlet | Get-Help | .{process{
		if (!$_.Synopsis.EndsWith('.')) {
			Write-Warning "$($_.Name) : unexpected/missing synopsis"
		}
	}}
}

# Update help then run help tests.
task TestHelp Help, TestHelpExample, TestHelpSynopsis

$UpdateScriptInputs = @(
	'Get-MongoFile.ps1'
	'Mdbc.ps1'
	'TabExpansionProfile.Mdbc.ps1'
	'Update-MongoFiles.ps1'
)

# Copy external scripts to the project.
# It fails if a script is missing.
task UpdateScript -Partial `
-Inputs { Get-Command $UpdateScriptInputs | .{process{ $_.Definition }} } `
-Outputs {process{ "Scripts\$(Split-Path -Leaf $_)" }} `
{process{ Copy-Item $_ $2 }}

# Pull driver sources.
task PullDriver {
	assert $env:MongoDBCSharpDriverRepo
	Set-Location $env:MongoDBCSharpDriverRepo
	exec { git pull }
}

# Build driver and copy to Module.
task BuildDriver {
	assert $env:MongoDBCSharpDriverRepo
	exec { MSBuild $env:MongoDBCSharpDriverRepo\CSharpDriver-2010.sln /t:Build /p:Configuration=Release }
	Copy-Item $env:MongoDBCSharpDriverRepo\Driver\bin\Release\*.dll Module
}

# Clean driver sources.
task CleanDriver {
	assert $env:MongoDBCSharpDriverRepo
	exec { MSBuild $env:MongoDBCSharpDriverRepo\CSharpDriver-2010.sln /t:Clean /p:Configuration=Release }
}

# Pull the latest driver, build it, then build Mdbc, test and clean all.
task Driver PullDriver, BuildDriver, Build, Test, Clean, CleanDriver

# Check expected files.
task CheckFiles {
	$Pattern = '\.(cs|csproj|md|ps1|psd1|psm1|ps1xml|sln|txt|xml|gitignore)$'
	foreach ($file in git status -s) { if ($file -notmatch $Pattern) {
		Write-Warning "Illegal file: '$file'."
	}}
}

# Call tests.
task Test {
	Invoke-Build ** Tests -Result result
	$testCount = 155
	if ($testCount -ne $result.Tasks.Count) {Write-Warning "Unexpected test count:`n Sample : $testCount`n Result : $($result.Tasks.Count)"}
},
CleanTest

# Build, test and clean all.
task . Build, TestHelp, Test, Clean, CheckFiles
